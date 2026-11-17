import Combine
import Foundation
import Network
final class MultiplayerService: ObservableObject, @unchecked Sendable {
  static let serviceType = "_cardarenaar._tcp"
  @Published private(set) var hostedRoom: HostedRoom?
  @Published private(set) var discoveredRooms: [DiscoveredRoom] = []
  @Published private(set) var discoveryIsSearching = false
  @Published private(set) var connectionState: MultiplayerConnectionState = .idle
  @Published private(set) var guestConnected = false
  @Published private(set) var statusMessage: String?
  @Published private(set) var localCardID: String?
  @Published private(set) var remoteCardID: String?
  @Published private(set) var localReady = false
  @Published private(set) var remoteReady = false
  @Published private(set) var localArenaReady = false
  @Published private(set) var remoteArenaReady = false
  @Published private(set) var battlePhase:
    MultiplayerBattlePhase = .waitingForArena
  @Published private(set) var battleCountdown: Int?
  @Published private(set) var turnSecondsRemaining =
    BattleRules.turnDurationSeconds
  @Published private(set) var battleRound = 1
  @Published private(set) var hostHP = 0
  @Published private(set) var guestHP = 0
  @Published private(set) var hostMove: BattleMove?
  @Published private(set) var guestMove: BattleMove?
  @Published private(set) var battleWinner:
    MultiplayerWinner?
  @Published private(set) var lastBattleMessage: String?
  var onBattleTurnResolved:
    (
      (
        BattleMove,
        BattleMove,
        BattleRoundResult,
        BattleWinner?,
        BattleDamage?,
        @escaping () -> Void
      ) -> Void
    )?
  /// Chamado quando o host confirma o vencedor da partida.
  /// O Bool ja esta convertido para a perspectiva deste iPhone.
  /// true = vitoria local; false = derrota local.
  var onBattleResultConfirmed: ((Bool) -> Void)?

  // NWConnection/NWBrowser callbacks and published game state share one queue.
  // Network I/O remains asynchronous.
  private let queue = DispatchQueue.main
  private var pendingIncomingConnections: [ObjectIdentifier: NWConnection] = [:]
  private static let protocolVersion = "6"
  // Restore proximity discovery in all configurations. For a deliberate
  // infrastructure-only experiment, set this to true on both phones.
  // Do not require a specific interface type during Bonjour discovery.
  private static let diagnosticLANOnly = false
  private var lastReceivedAt = ContinuousClock.now
  private var guestHandshakeStarted = false
  private var incomingHandshakes: Set<ObjectIdentifier> = []

  private static func tcpParameters() -> NWParameters {
    let tcp = NWProtocolTCP.Options()
    tcp.noDelay = true
    tcp.enableKeepalive = true
    tcp.keepaliveIdle = 5
    tcp.keepaliveInterval = 5
    tcp.keepaliveCount = 4
    let parameters = NWParameters(tls: nil, tcp: tcp)
    parameters.includePeerToPeer = !diagnosticLANOnly
    return parameters
  }
  private var listener: NWListener?
  private var browser: NWBrowser?
  private var hostConnection: NWConnection?
  private var guestConnection: NWConnection?
  private var battleHasStarted = false
  private var battleClockGeneration = 0
  private var roundGate: MultiplayerRoundGate?
  private var pendingNextRound: Int?
  // Keep the most recent preparation events available even when a phone is
  // not attached to Xcode. No network addresses or room codes are recorded.
  private(set) var preparationDiagnostics: [String] = []

  func recordPreparationDiagnostic(_ event: String) {
    #if DEBUG
    let role = (isHost || listener != nil || event.hasPrefix("BONJOUR create")) ? "host" : "guest"
    let time = String(format: "%.3f", Date().timeIntervalSince1970)
    let line = "[Multiplayer][\(role)] \(time) \(event) | local=\(localCardID ?? "-") ready=\(localReady) arena=\(localArenaReady) | remote=\(remoteCardID ?? "-") ready=\(remoteReady) arena=\(remoteArenaReady) | battle=\(battlePhase)"
    preparationDiagnostics.append(line)
    if preparationDiagnostics.count > 400 {
      preparationDiagnostics.removeFirst(preparationDiagnostics.count - 400)
    }
    print(line)
    #endif
  }

  // Idempotent: safe to reevaluate while the selection screen is visible.
  func reconcileBattleStart() {
    tryBeginBattleAsHost()
  }
  var isHost: Bool {
    hostedRoom != nil
  }
  var bothPlayersReady: Bool {
    localReady
      && remoteReady
      && localCardID != nil
      && remoteCardID != nil
  }
  var bothArenasReady: Bool {
    bothPlayersReady
      && localArenaReady
      && remoteArenaReady
  }
  var localHP: Int {
    isHost
      ? hostHP
      : guestHP
  }
  var remoteHP: Int {
    isHost
      ? guestHP
      : hostHP
  }
  var localMove: BattleMove? {
    isHost
      ? hostMove
      : guestMove
  }
  var remoteMove: BattleMove? {
    isHost
      ? guestMove
      : hostMove
  }
  var localCard: CardDefinition? {
    localCardID.flatMap {
      CardDatabase.card(
        named: $0
      )
    }
  }
  var remoteCard: CardDefinition? {
    remoteCardID.flatMap {
      CardDatabase.card(
        named: $0
      )
    }
  }
  var localHPProgress: Double {
    guard
      let maxHP = localCard?.maxHP,
      maxHP > 0
    else {
      return 0
    }
    return Double(localHP)
      / Double(maxHP)
  }
  var remoteHPProgress: Double {
    guard
      let maxHP = remoteCard?.maxHP,
      maxHP > 0
    else {
      return 0
    }
    return Double(remoteHP)
      / Double(maxHP)
  }
  var winnerIsLocal: Bool? {
    guard let battleWinner else {
      return nil
    }
    if isHost {
      return battleWinner == .host
    }
    return battleWinner == .guest
  }
  var canSubmitLocalMove: Bool {
    battlePhase == .choosingMove
      && localMove == nil
      && battleWinner == nil
      && turnSecondsRemaining > 0
  }
  func createRoom(
    name: String,
    privacy: RoomPrivacy
  ) {
    stopAll()
    preparationDiagnostics.removeAll()
    let cleanName =
      name.trimmingCharacters(
        in: .whitespacesAndNewlines
      )
    guard !cleanName.isEmpty else {
      publishFailure(
        DeckSpawnL10n.text("Digite um nome para a sala.")
      )
      return
    }
    let roomID = UUID().uuidString
    let joinCode: String? =
      privacy == .privateRoom
      ? Self.generateJoinCode()
      : nil
    let room = HostedRoom(
      id: roomID,
      name: cleanName,
      privacy: privacy,
      joinCode: joinCode
    )
    recordPreparationDiagnostic("BONJOUR create version=\(Self.protocolVersion) peer=\(!Self.diagnosticLANOnly)")
    statusMessage = DeckSpawnL10n.text("Criando sala...")
    do {
      let parameters = Self.tcpParameters()
      let listener =
        try NWListener(
          using: parameters
        )
      let txtRecord =
        NWTXTRecord([
          "roomID": roomID,
          "privacy": privacy.rawValue,
          "version": Self.protocolVersion,
        ])
      listener.service =
        NWListener.Service(
          name: cleanName,
          type: Self.serviceType,
          domain: nil,
          txtRecord: txtRecord
        )
      listener.stateUpdateHandler = {
        [weak self, weak listener] state in
        guard let self, let listener, self.listener === listener else {
          return
        }
        self.recordPreparationDiagnostic("BONJOUR listener state=\(state)")
        switch state {
        case .ready:
          guard self.listener != nil else { return }
          self.hostedRoom = room
          self.connectionState = .hosting
          self.statusMessage =
            DeckSpawnL10n.text("Sala criada. Aguardando jogador...")
        case .waiting(let error):
          self.statusMessage = self.bonjourWaitingMessage(error)
        case .failed(let error):
          self.publishFailure(
            DeckSpawnL10n.format("Não foi possível criar a sala: %@", error.localizedDescription)
          )
          self.stopHosting()
          self.hostedRoom = nil
          self.clearPlayerSyncState()
        default:
          break
        }
      }
      listener.serviceRegistrationUpdateHandler = { [weak self, weak listener] change in
        guard let self, let listener, self.listener === listener else { return }
        switch change {
        case .add: self.recordPreparationDiagnostic("BONJOUR service registered")
        case .remove: self.recordPreparationDiagnostic("BONJOUR service removed")
        @unknown default: self.recordPreparationDiagnostic("BONJOUR registration changed")
        }
      }
      listener.newConnectionHandler = {
        [weak self, weak listener] connection in
        guard let self, let listener, self.listener === listener else {
          connection.cancel()
          return
        }
        self.handleIncomingConnection(
          connection,
          room: room
        )
      }
      self.listener = listener
      listener.start(queue: queue)
      queue.asyncAfter(deadline: .now() + 15) { [weak self, weak listener] in
        guard let self, let listener, self.listener === listener,
              self.hostedRoom == nil else { return }
        self.recordPreparationDiagnostic("BONJOUR listener setup timed out")
        let message = self.statusMessage ?? DeckSpawnL10n.text("Tempo esgotado ao criar a sala.")
        self.stopHosting()
        self.publishFailure(message == DeckSpawnL10n.text("Criando sala...")
          ? DeckSpawnL10n.text("Tempo esgotado ao criar a sala.") : message)
      }
    } catch {
      publishFailure(
        DeckSpawnL10n.format("Não foi possível criar a sala: %@", error.localizedDescription)
      )
    }
  }
  func deleteRoom() {
    recordPreparationDiagnostic("LOCAL deleteRoom")
    stopHosting()
    resetCardSyncState()
    hostedRoom = nil
    guestConnected = false
    connectionState = .idle
    statusMessage = nil
  }
  func startBrowsing() {
    guard connectionState != .connecting, connectionState != .connected else { return }
    stopBrowsing()
    connectionState = .browsing
    discoveryIsSearching = true
    statusMessage = DeckSpawnL10n.text("Procurando salas disponíveis...")
    recordPreparationDiagnostic("BONJOUR browse version=\(Self.protocolVersion) peer=\(!Self.diagnosticLANOnly)")
    let parameters = NWParameters.tcp
    parameters.includePeerToPeer = !Self.diagnosticLANOnly
    let browser =
      NWBrowser(
        for:
          .bonjourWithTXTRecord(
            type: Self.serviceType,
            domain: nil
          ),
        using: parameters
      )
    browser.stateUpdateHandler = {
      [weak self, weak browser] state in
      guard let self, let browser, self.browser === browser else {
        return
      }
      self.recordPreparationDiagnostic("BONJOUR browser state=\(state)")
      switch state {
      case .ready:
        guard self.connectionState != .connecting, self.connectionState != .connected else { return }
        self.connectionState = .browsing
        if self.discoveredRooms.isEmpty {
          self.statusMessage = DeckSpawnL10n.text(self.discoveryIsSearching
            ? "Procurando salas disponíveis..." : "Nenhuma sala disponível. Tente atualizar a busca.")
        } else {
          self.statusMessage = nil
        }
      case .waiting(let error):
        self.discoveredRooms = []
        self.statusMessage = self.bonjourWaitingMessage(error)
      case .failed(let error):
        guard self.connectionState != .connecting, self.connectionState != .connected else { return }
        self.discoveryIsSearching = false
        self.discoveredRooms = []
        self.publishFailure(
          DeckSpawnL10n.format("Não foi possível procurar salas: %@", error.localizedDescription)
        )
      default:
        break
      }
    }
    browser.browseResultsChangedHandler = {
      [weak self, weak browser] results, _ in
      guard let self, let browser, self.browser === browser else {
        return
      }
      let rooms =
        results
        .compactMap {
          self.makeDiscoveredRoom(
            from: $0
          )
        }
        .sorted {
          $0.name
            .localizedCaseInsensitiveCompare(
              $1.name
            )
            == .orderedAscending
        }
      guard self.browser === browser else { return }
      self.discoveredRooms = rooms
      self.recordPreparationDiagnostic("BONJOUR results raw=\(results.count) compatible=\(rooms.count)")
      if !rooms.isEmpty {
        self.discoveryIsSearching = false
        self.statusMessage = nil
      } else if results.count > 0 {
        self.discoveryIsSearching = false
        self.statusMessage = DeckSpawnL10n.text("Salas encontradas sem dados compatíveis. Atualize o jogo nos dois iPhones.")
      } else if !self.discoveryIsSearching, case .ready = browser.state {
        self.statusMessage = DeckSpawnL10n.text("Nenhuma sala disponível. Tente atualizar a busca.")
      }
    }
    self.browser = browser
    browser.start(queue: queue)
    queue.asyncAfter(deadline: .now() + 15) { [weak self, weak browser] in
      guard let self, let browser, self.browser === browser,
            self.discoveryIsSearching else { return }
      self.discoveryIsSearching = false
      guard self.discoveredRooms.isEmpty else { return }
      self.recordPreparationDiagnostic("BONJOUR no compatible room after 15s; state=\(browser.state)")
      if case .waiting(let error) = browser.state {
        self.statusMessage = self.bonjourWaitingMessage(error)
      } else if self.connectionState == .browsing {
        self.statusMessage = DeckSpawnL10n.text("Nenhuma sala disponível. Tente atualizar a busca.")
      }
      // Keep listening for late advertisements; the UI no longer spins.
    }
  }
  private func bonjourWaitingMessage(_ error: NWError) -> String {
    // kDNSServiceErr_PolicyDenied: Apple's TN3179 local network privacy check.
    if case .dns(let code) = error, code == -65570 {
      return DeckSpawnL10n.text("Acesso à rede local negado. Permita o acesso nos Ajustes do iPhone.")
    }
    return DeckSpawnL10n.format("Aguardando rede local: %@", error.localizedDescription)
  }
  func stopBrowsing(clearRooms: Bool = true) {
    discoveryIsSearching = false
    let oldBrowser = browser
    browser = nil
    oldBrowser?.cancel()
    if clearRooms { discoveredRooms = [] }
  }
  func join(
    room: DiscoveredRoom,
    code: String?
  ) {
    guard connectionState != .connecting, connectionState != .connected else { return }
    stopBrowsing(clearRooms: false)
    guestConnection?.cancel()
    guestConnection = nil
    guestHandshakeStarted = false
    resetCardSyncState()
    connectionState = .connecting
    statusMessage = DeckSpawnL10n.format("Entrando em %@...", room.name)
    let parameters = Self.tcpParameters()
    let connection =
      NWConnection(
        to: room.endpoint,
        using: parameters
      )
    guestConnection = connection
    observeConnection(connection)
    queue.asyncAfter(deadline: .now() + 12) { [weak self, weak connection] in
      guard let self, let connection, self.guestConnection === connection,
            self.connectionState == .connecting else { return }
      self.guestConnection = nil
      connection.cancel()
      self.connectionState = .failed(DeckSpawnL10n.text("Tempo esgotado ao entrar na sala."))
      self.statusMessage = DeckSpawnL10n.text("Tempo esgotado ao entrar na sala.")
    }
    connection.stateUpdateHandler = {
      [weak self, weak connection] state in
      guard
        let self,
        let connection
      else {
        return
      }
      guard self.guestConnection === connection else { return }
      self.recordPreparationDiagnostic("TCP state=\(state)")
      switch state {
      case .ready:
        guard self.connectionState == .connecting, !self.guestHandshakeStarted else { return }
        self.guestHandshakeStarted = true
        self.sendJoinRequest(
          through: connection,
          room: room,
          code: code
        )
      case .failed(let error):
        self.recordPreparationDiagnostic("TCP failed: \(error)")
        self.handleRemoteDisconnect(connection)
        self.publishFailure(
          DeckSpawnL10n.format("Falha ao entrar na sala: %@", error.localizedDescription)
        )
        connection.cancel()
      case .cancelled:
        self.handleRemoteDisconnect(
          connection
        )
      default:
        break
      }
    }
    connection.start(
      queue: queue
    )
  }
  func leaveJoinedRoom() {
    recordPreparationDiagnostic("LOCAL leaveJoinedRoom")
    guestConnection?.cancel()
    guestConnection = nil
    resetCardSyncState()
    connectionState = .idle
    statusMessage = nil
  }
  func stopAll() {
    recordPreparationDiagnostic("LOCAL stopAll")
    stopBrowsing()
    stopHosting()
    guestConnection?.cancel()
    guestConnection = nil
    resetCardSyncState()
    hostedRoom = nil
    guestConnected = false
    connectionState = .idle
    statusMessage = nil
  }
  func updateLocalCard(_ cardID: String?) {
    guard localCardID != cardID else { return }
    localCardID = cardID
    localReady = false
    localArenaReady = false
    resetBattleStateOnly()
    sendCurrentPlayerState()
    logPreparation("local card changed")
  }

  func setLocalReady(_ ready: Bool) {
    guard localCard != nil, localReady != ready else { return }
    localReady = ready
    if !ready {
      localArenaReady = false
      resetBattleStateOnly()
    }
    sendCurrentPlayerState()
    logPreparation("local ready changed")
    tryBeginBattleAsHost()
  }

  func setLocalArenaReady(_ ready: Bool) {
    guard localReady, localCard != nil, localArenaReady != ready else { return }
    localArenaReady = ready
    sendCurrentPlayerState()
    logPreparation("local arena ready changed")
    tryBeginBattleAsHost()
  }

  func resetLocalSelection() {
    recordPreparationDiagnostic("resetLocalSelection")
    localCardID = nil
    localReady = false
    localArenaReady = false
    resetBattleStateOnly()
    sendCurrentPlayerState()
  }

  private func logPreparation(_ event: String) {
    recordPreparationDiagnostic(event)
  }

  func submitLocalMove(
    _ move: BattleMove
  ) {
    DispatchQueue.main.async {
      guard
        self.canSubmitLocalMove
      else {
        return
      }
      GameHaptics.selectedMove(move)
      if self.isHost {
        self.hostMove =
          move
        self.lastBattleMessage =
          DeckSpawnL10n.text("Ação confirmada. Aguardando o adversário...")
        self.resolveRoundIfPossibleAsHost()
      } else {
        self.guestMove =
          move
        self.lastBattleMessage =
          DeckSpawnL10n.text("Ação confirmada. Aguardando o adversário...")
        let payload =
          MultiplayerMoveMessage(
            round:
              self.battleRound,
            moveRawValue:
              move.rawValue
          )
        let wire =
          MultiplayerWireMessage(
            kind:
              MultiplayerWireKind.submitMove,
            playerState: nil,
            battleStart: nil,
            move: payload,
            roundStart: nil,
            roundResult: nil
          )
        self.sendWire(
          wire
        )
      }
    }
  }
  private func stopHosting() {
    guestConnected = false
    for connection in pendingIncomingConnections.values { connection.cancel() }
    pendingIncomingConnections.removeAll()
    incomingHandshakes.removeAll()
    hostConnection?.cancel()
    hostConnection = nil
    listener?.cancel()
    listener = nil
  }
  private func makeDiscoveredRoom(
    from result: NWBrowser.Result
  ) -> DiscoveredRoom? {
    guard
      case .service(
        let
          name,
        _,
        _,
        _
      ) = result.endpoint
    else {
      return nil
    }
    var roomID =
      result.endpoint
      .debugDescription
    var privacy:
      RoomPrivacy = .open
    if case .bonjour(let txtRecord) =
      result.metadata
    {
      let values =
        txtRecord.dictionary
      guard values["version"] == Self.protocolVersion else {
        recordPreparationDiagnostic("BONJOUR ignored version=\(values["version"] ?? "missing") expected=\(Self.protocolVersion)")
        return nil
      }
      guard let advertisedID = values["roomID"], !advertisedID.isEmpty else {
        recordPreparationDiagnostic("BONJOUR ignored missing roomID")
        return nil
      }
      roomID = advertisedID
      if let rawPrivacy =
        values["privacy"],
        let advertisedPrivacy =
          RoomPrivacy(
            rawValue:
              rawPrivacy
          )
      {
        privacy =
          advertisedPrivacy
      }
    }
    else {
      recordPreparationDiagnostic("BONJOUR ignored missing TXT record")
      return nil
    }
    return DiscoveredRoom(
      id: roomID,
      name: name,
      privacy: privacy,
      endpoint: result.endpoint
    )
  }
  private func handleIncomingConnection(
    _ connection: NWConnection,
    room: HostedRoom
  ) {
    let identifier = ObjectIdentifier(connection)
    pendingIncomingConnections[identifier] = connection
    observeConnection(connection)
    queue.asyncAfter(deadline: .now() + 10) { [weak self, weak connection] in
      guard let self, let connection,
            self.pendingIncomingConnections.removeValue(forKey: identifier) != nil else { return }
      self.incomingHandshakes.remove(identifier)
      connection.cancel()
    }
    connection.stateUpdateHandler = {
      [weak self, weak connection] state in
      guard
        let self,
        let connection
      else {
        return
      }
      guard self.pendingIncomingConnections[identifier] === connection || self.hostConnection === connection else { return }
      self.recordPreparationDiagnostic("TCP state=\(state)")
      switch state {
      case .ready:
        guard self.pendingIncomingConnections[identifier] === connection,
              self.incomingHandshakes.insert(identifier).inserted else { return }
        self.receiveJoinRequest(
          from: connection,
          room: room
        )
      case .failed(let error):
        self.recordPreparationDiagnostic("TCP failed: \(error)")
        self.handleRemoteDisconnect(connection)
        connection.cancel()
      case .cancelled:
        self.handleRemoteDisconnect(connection)
      default:
        break
      }
    }
    connection.start(
      queue: queue
    )
  }
  private func receiveJoinRequest(
    from connection: NWConnection,
    room: HostedRoom
  ) {
    receiveFrame(from: connection) { [weak self, weak connection] data in
      guard let self, let connection,
            self.pendingIncomingConnections.removeValue(forKey: ObjectIdentifier(connection)) != nil else { return }
      self.incomingHandshakes.remove(ObjectIdentifier(connection))
      guard data != nil else {
        connection.cancel()
        return
      }
      guard self.hostConnection == nil, self.hostedRoom?.id == room.id else {
        self.sendResponse(
          JoinResponse(accepted: false, message: "A sala já possui dois jogadores."),
          through: connection,
          cancelAfterSend: true
        )
        return
      }
      guard
        let data,
        let request =
          try? JSONDecoder()
          .decode(
            JoinRequest.self,
            from: data
          )
      else {
        self.sendResponse(
          JoinResponse(
            accepted: false,
            message:
              "Pedido de entrada inválido."
          ),
          through:
            connection,
          cancelAfterSend:
            true
        )
        return
      }
      guard
        request.roomID == room.id
      else {
        self.sendResponse(
          JoinResponse(
            accepted: false,
            message:
              "A sala não está mais disponível."
          ),
          through:
            connection,
          cancelAfterSend:
            true
        )
        return
      }
      if room.privacy
        == .privateRoom,
        request.code
          != room.joinCode
      {
        self.sendResponse(
          JoinResponse(
            accepted: false,
            message:
              "Código da sala incorreto."
          ),
          through:
            connection,
          cancelAfterSend:
            true
        )
        return
      }
      self.hostConnection =
        connection
      self.sendResponse(
        JoinResponse(
          accepted: true,
          message:
            "Conectado à sala %@."
        ),
        through:
          connection,
        cancelAfterSend:
          false
      )
      guard self.hostConnection === connection else { return }
      self.guestConnected = true
      self.statusMessage = DeckSpawnL10n.text("Jogador 2 conectado.")
      self.beginReceivingWireMessages(on: connection)
      self.startHeartbeat(on: connection)
      self.sendCurrentPlayerState()
    }
  }
  private func sendJoinRequest(
    through connection: NWConnection,
    room: DiscoveredRoom,
    code: String?
  ) {
    let request =
      JoinRequest(
        roomID:
          room.id,
        code:
          code?
          .trimmingCharacters(
            in:
              .whitespacesAndNewlines
          )
      )
    guard
      let data =
        try? MultiplayerFrame.encode(request)
    else {
      publishFailure(
        DeckSpawnL10n.text("Não foi possível preparar o pedido de entrada.")
      )
      return
    }
    connection.send(
      content: data,
      completion:
        .contentProcessed {
          [weak self, weak connection]
          error in
          guard
            let self,
            let connection
          else {
            return
          }
          guard self.guestConnection === connection else { return }
          if let error {
            self.guestConnection = nil
            connection.cancel()
            self.publishFailure(
              DeckSpawnL10n.format("Erro enviando pedido de entrada: %@", error.localizedDescription)
            )
            return
          }
          self.receiveJoinResponse(
            from: connection,
            roomName: room.name
          )
        }
    )
  }
  private func receiveJoinResponse(
    from connection: NWConnection,
    roomName: String
  ) {
    receiveFrame(from: connection) { [weak self, weak connection] data in
      guard let self, let connection, self.guestConnection === connection else { return }
      guard
        let data,
        let response =
          try? JSONDecoder()
          .decode(
            JoinResponse.self,
            from: data
          )
      else {
        self.guestConnection = nil
        self.publishFailure(
          DeckSpawnL10n.text("A sala enviou uma resposta inválida.")
        )
        connection.cancel()
        return
      }
      DispatchQueue.main.async {
        guard self.guestConnection === connection else { return }
        if response.accepted {
          self.connectionState =
            .connected
          self.statusMessage = response.message == "Conectado à sala %@."
            ? DeckSpawnL10n.format(response.message, roomName)
            : DeckSpawnL10n.text(response.message)
          self.stopBrowsing()
          self.beginReceivingWireMessages(
            on: connection
          )
          self.startHeartbeat(on: connection)
          self.sendCurrentPlayerState()
        } else {
          self.connectionState =
            .failed(DeckSpawnL10n.text(response.message))
          self.statusMessage = DeckSpawnL10n.text(response.message)
          self.guestConnection = nil
          connection.cancel()
        }
      }
    }
  }
  private func sendResponse(
    _ response: JoinResponse,
    through connection: NWConnection,
    cancelAfterSend: Bool
  ) {
    guard
      let data =
        try? MultiplayerFrame.encode(response)
    else {
      connection.cancel()
      return
    }
    connection.send(
      content: data,
      completion:
        .contentProcessed {
          error in
          if error != nil
            || cancelAfterSend
          {
            connection.cancel()
          }
        }
    )
  }
  private func sendCurrentPlayerState() {
    let state =
      MultiplayerPlayerStateMessage(
        cardID:
          localCardID,
        ready:
          localReady,
        arenaReady:
          localArenaReady
      )
    let wire =
      MultiplayerWireMessage(
        kind:
          MultiplayerWireKind.playerState,
        playerState:
          state,
        battleStart:
          nil,
        move:
          nil,
        roundStart:
          nil,
        roundResult:
          nil
      )
    sendWire(
      wire
    )
  }
  private func sendWire(
    _ wire: MultiplayerWireMessage
  ) {
    let isPreparation = wire.kind == MultiplayerWireKind.playerState
      || wire.kind == MultiplayerWireKind.battleStart
      || wire.kind == MultiplayerWireKind.heartbeat
    guard
      let connection =
        activeConnection
    else {
      if isPreparation { recordPreparationDiagnostic("TX dropped \(wire.kind): no active connection") }
      return
    }
    guard
      let payload =
        try? MultiplayerFrame.encode(wire)
    else {
      if isPreparation { recordPreparationDiagnostic("TX dropped \(wire.kind): encode failed") }
      return
    }
    if isPreparation { recordPreparationDiagnostic("TX \(wire.kind)") }
    connection.send(
      content:
        payload,
      completion:
        .contentProcessed {
          [weak self, weak connection] error in
          guard let self, let connection,
                self.activeConnection === connection else { return }
          if let error {
            self.recordPreparationDiagnostic("TX failed \(wire.kind): \(error.localizedDescription)")
            self.handleRemoteDisconnect(connection)
            connection.cancel()
          } else if isPreparation {
            self.recordPreparationDiagnostic("TX processed \(wire.kind)")
          }
        }
    )
  }
  private func observeConnection(_ connection: NWConnection) {
    recordPreparationDiagnostic("TCP mode=\(Self.diagnosticLANOnly ? "LAN_ONLY" : "PEER_ENABLED")")
    connection.pathUpdateHandler = { [weak self, weak connection] path in
      guard let self, let connection,
            self.activeConnection === connection || self.pendingIncomingConnections[ObjectIdentifier(connection)] === connection else { return }
      let interfaces = path.availableInterfaces.map { $0.name }.joined(separator: ",")
      self.recordPreparationDiagnostic("TCP path=\(path.status) wifi=\(path.usesInterfaceType(.wifi)) interfaces=\(interfaces)")
    }
    connection.viabilityUpdateHandler = { [weak self, weak connection] viable in
      guard let self, let connection,
            self.activeConnection === connection || self.pendingIncomingConnections[ObjectIdentifier(connection)] === connection else { return }
      self.recordPreparationDiagnostic("TCP viable=\(viable)")
    }
  }

  private func startHeartbeat(on connection: NWConnection) {
    lastReceivedAt = .now
    scheduleHeartbeat(on: connection)
  }

  private func scheduleHeartbeat(on connection: NWConnection) {
    queue.asyncAfter(deadline: .now() + 2) { [weak self, weak connection] in
      guard let self, let connection, self.activeConnection === connection else { return }
      if ContinuousClock.now - self.lastReceivedAt >= .seconds(30) {
        self.recordPreparationDiagnostic("TCP heartbeat timeout: no inbound message for 30s")
        self.handleRemoteDisconnect(connection)
        connection.cancel()
        return
      }
      if self.battlePhase == .waitingForArena {
        // Reaffirm current state while scanning or waiting, even when
        // nothing changes. This also acts as an application heartbeat.
        self.sendCurrentPlayerState()
      } else {
        self.sendWire(MultiplayerWireMessage(
          kind: MultiplayerWireKind.heartbeat, playerState: nil, battleStart: nil,
          move: nil, roundStart: nil, roundResult: nil
        ))
      }
      self.scheduleHeartbeat(on: connection)
    }
  }

  private var activeConnection:
    NWConnection?
  {
    hostConnection
      ?? guestConnection
  }
  private func receiveFrame(
    from connection: NWConnection,
    completion: @escaping (Data?) -> Void
  ) {
    receiveExactly(count: 4, from: connection) { [weak self, weak connection] header in
      guard let self, let connection else { completion(nil); return }
      guard let header else {
        self.recordPreparationDiagnostic("RX header missing")
        completion(nil)
        return
      }
      guard let length = MultiplayerFrame.payloadLength(from: header) else {
        self.recordPreparationDiagnostic("RX invalid header: \(header.map { String(format: "%02x", $0) }.joined())")
        completion(nil)
        return
      }
      self.receiveExactly(count: length, from: connection) { [weak self] payload in
        if payload == nil { self?.recordPreparationDiagnostic("RX incomplete payload: expected \(length) bytes") }
        completion(payload)
      }
    }
  }

  private func beginReceivingWireMessages(on connection: NWConnection) {
    receiveFrame(from: connection) { [weak self, weak connection] payload in
      guard let self, let connection, self.activeConnection === connection else { return }
      guard let payload else {
        self.recordPreparationDiagnostic("RX interrupted: see TCP/header/payload error above")
        self.handleRemoteDisconnect(connection)
        connection.cancel()
        return
      }
      do {
        let wire = try JSONDecoder().decode(MultiplayerWireMessage.self, from: payload)
        self.lastReceivedAt = .now
        self.recordPreparationDiagnostic("RX \(wire.kind) bytes=\(payload.count)")
        self.handleWireMessage(wire)
      } catch {
        self.recordPreparationDiagnostic("RX JSON decode failed: \(error)")
        self.handleRemoteDisconnect(connection)
        connection.cancel()
        return
      }
      if self.activeConnection === connection {
        self.beginReceivingWireMessages(on: connection)
      }
    }
  }

  private func handleWireMessage(
    _ wire: MultiplayerWireMessage
  ) {
    switch wire.kind {
    case MultiplayerWireKind.playerState:
      guard
        let state =
          wire.playerState
      else {
        return
      }
      let cardID = state.cardID.flatMap { CardDatabase.card(named: $0)?.id }
      let ready = state.ready && cardID != nil
      let arenaReady = state.arenaReady && ready
      if remoteCardID != cardID { remoteCardID = cardID }
      if remoteReady != ready { remoteReady = ready }
      if remoteArenaReady != arenaReady { remoteArenaReady = arenaReady }
      logPreparation("remote state received: wireCard=\(state.cardID ?? "-"), wireReady=\(state.ready), wireArena=\(state.arenaReady)")
      if battleHasStarted,
        !remoteReady
      {
        resetBattleStateOnly()
        lastBattleMessage =
          DeckSpawnL10n.text("O adversário cancelou a seleção.")
      }
      if isHost { tryBeginBattleAsHost() }
    case MultiplayerWireKind.heartbeat:
      break
    case MultiplayerWireKind.battleStart:
      recordPreparationDiagnostic("RX battleStart")
      guard
        !isHost,
        !battleHasStarted,
        bothArenasReady,
        let message =
          wire.battleStart,
        message.hostCardID == remoteCardID,
        message.guestCardID == localCardID
      else {
        recordPreparationDiagnostic("RX battleStart rejected: host=\(isHost), started=\(battleHasStarted), bothArenas=\(bothArenasReady), packetHost=\(wire.battleStart?.hostCardID ?? "-"), packetGuest=\(wire.battleStart?.guestCardID ?? "-")")
        return
      }
      applyBattleStart(
        message
      )
    case MultiplayerWireKind.submitMove:
      guard
        isHost,
        let message =
          wire.move,
        message.round
          == battleRound,
        (battlePhase == .choosingMove ||
          (battlePhase == .countdown && battleCountdown == 1) ||
          (battlePhase == .showingResult && pendingNextRound == nil)),
        guestMove == nil,
        let move =
          BattleMove(
            rawValue:
              message.moveRawValue
          )
      else {
        return
      }
      guestMove =
        move
      resolveRoundIfPossibleAsHost()
    case MultiplayerWireKind.animationsFinished:
      guard isHost, let round = wire.animationsFinishedRound else { return }
      markRoundGate(.guestFinished, round: round, generation: battleClockGeneration)
    case MultiplayerWireKind.roundStart:
      guard
        !isHost,
        battleHasStarted,
        let message =
          wire.roundStart
      else {
        return
      }
      applyRoundStart(
        message
      )
    case MultiplayerWireKind.roundResult:
      guard
        !isHost,
        battleHasStarted,
        let message =
          wire.roundResult
      else {
        return
      }
      applyRoundResult(
        message
      )
    default:
      break
    }
  }
  private func tryBeginBattleAsHost() {
    guard
      isHost,
      guestConnected,
      !battleHasStarted,
      bothArenasReady,
      let hostCardID =
        localCardID,
      let guestCardID =
        remoteCardID,
      let hostCard =
        CardDatabase.card(
          named:
            hostCardID
        ),
      let guestCard =
        CardDatabase.card(
          named:
            guestCardID
        )
    else {
      return
    }
    logPreparation("host starting battle")
    battleHasStarted =
      true
    let startAt =
      Date()
      .addingTimeInterval(
        0.75
      )
      .timeIntervalSince1970
    let message =
      MultiplayerBattleStartMessage(
        hostCardID:
          hostCardID,
        guestCardID:
          guestCardID,
        hostHP:
          hostCard.maxHP,
        guestHP:
          guestCard.maxHP,
        countdownStartsAt:
          startAt,
        countdownSeconds:
          BattleRules.startCountdownSeconds,
        turnDurationSeconds:
          BattleRules.turnDurationSeconds
      )
    let wire =
      MultiplayerWireMessage(
        kind:
          MultiplayerWireKind.battleStart,
        playerState:
          nil,
        battleStart:
          message,
        move:
          nil,
        roundStart:
          nil,
        roundResult:
          nil
      )
    sendWire(
      wire
    )
    applyBattleStart(
      message
    )
  }
  private func applyBattleStart(
    _ message: MultiplayerBattleStartMessage
  ) {
    battleHasStarted =
      true
    hostHP =
      message.hostHP
    guestHP =
      message.guestHP
    battleRound =
      1
    hostMove =
      nil
    guestMove =
      nil
    battleWinner =
      nil
    battlePhase = .versus
    battleCountdown = nil
    turnSecondsRemaining =
      message.turnDurationSeconds
    lastBattleMessage =
      DeckSpawnL10n.text("Prepare-se!")
    recordPreparationDiagnostic("versus applied")
    battleClockGeneration += 1
    let generation =
      battleClockGeneration
    // The sender schedules at most 0.75 s ahead. A different device clock
    // must not cause a countdown to wait for minutes.
    let delay = max(0, min(0.75, message.countdownStartsAt - Date().timeIntervalSince1970))
    DispatchQueue.main.asyncAfter(
      deadline:
        .now()
        + delay
    ) { [weak self] in
      guard let self, self.battleClockGeneration == generation,
            self.battlePhase == .versus else { return }
      DispatchQueue.main.asyncAfter(deadline: .now() + BattleRules.versusDuration) { [weak self] in
        guard let self, self.battleClockGeneration == generation,
              self.battlePhase == .versus else { return }
        self.battleCountdown = message.countdownSeconds
        self.battlePhase = .countdown
        self.runBattleCountdown(remaining: message.countdownSeconds,
                                turnDuration: message.turnDurationSeconds,
                                generation: generation)
      }
    }
  }
  private func runBattleCountdown(
    remaining: Int,
    turnDuration: Int,
    generation: Int
  ) {
    guard
      generation
        == battleClockGeneration,
      battleWinner == nil
    else {
      return
    }
    guard remaining > 0 else {
      battleCountdown =
        nil
      battlePhase =
        .choosingMove
      lastBattleMessage =
        DeckSpawnL10n.text("Escolha sua ação.")
      recordPreparationDiagnostic("countdown finished: choosing move")
      startTurnTimer(
        duration:
          turnDuration
      )
      return
    }
    battleCountdown =
      remaining
    DispatchQueue.main.asyncAfter(
      deadline: .now() + 1
    ) { [weak self] in
      self?.runBattleCountdown(
        remaining:
          remaining - 1,
        turnDuration:
          turnDuration,
        generation:
          generation
      )
    }
  }
  private func startTurnTimer(
    duration: Int
  ) {
    battleClockGeneration += 1
    let generation =
      battleClockGeneration
    turnSecondsRemaining =
      duration
    runTurnTimer(
      remaining:
        duration,
      generation:
        generation
    )
  }
  private func runTurnTimer(
    remaining: Int,
    generation: Int
  ) {
    guard
      generation
        == battleClockGeneration,
      battlePhase
        == .choosingMove,
      battleWinner == nil
    else {
      return
    }
    turnSecondsRemaining =
      max(
        remaining,
        0
      )
    if localMove == nil && (remaining == 3 || remaining == 1) {
      DispatchQueue.main.async {
        GameHaptics.timeWarning(secondsRemaining: remaining)
      }
    }
    guard remaining > 0 else {
      if localMove == nil {
        DispatchQueue.main.async {
          GameHaptics.timeExpired()
        }
      }
      if isHost {
        resolveRoundAsHost(
          forceMissingMoves:
            true
        )
      } else {
        lastBattleMessage =
          DeckSpawnL10n.text("Tempo esgotado. Aguardando o resultado do host...")
      }
      return
    }
    DispatchQueue.main.asyncAfter(
      deadline: .now() + 1
    ) { [weak self] in
      self?.runTurnTimer(
        remaining:
          remaining - 1,
        generation:
          generation
      )
    }
  }
  private func resolveRoundIfPossibleAsHost() {
    guard
      isHost,
      hostMove != nil,
      guestMove != nil
    else {
      return
    }
    resolveRoundAsHost(
      forceMissingMoves:
        false
    )
  }
  private func resolveRoundAsHost(
    forceMissingMoves: Bool
  ) {
    guard
      isHost,
      battlePhase
        == .choosingMove,
      let hostCardID =
        localCardID,
      let guestCardID =
        remoteCardID,
      let hostCard =
        CardDatabase.card(
          named:
            hostCardID
        ),
      let guestCard =
        CardDatabase.card(
          named:
            guestCardID
        )
    else {
      return
    }
    var hostWasAutomatic =
      false
    var guestWasAutomatic =
      false
    if hostMove == nil,
      forceMissingMoves
    {
      hostMove =
        BattleMove
        .allCases
        .randomElement()
      hostWasAutomatic =
        true
    }
    if guestMove == nil,
      forceMissingMoves
    {
      guestMove =
        BattleMove
        .allCases
        .randomElement()
      guestWasAutomatic =
        true
    }
    guard
      let hostMove,
      let guestMove
    else {
      return
    }
    battleClockGeneration += 1
    let state =
      BattleState(
        playerCard:
          hostCard,
        enemyCard:
          guestCard,
        playerHP:
          hostHP,
        enemyHP:
          guestHP,
        round:
          battleRound
      )
    let resolution =
      BattleEngine.resolveTurn(
        state:
          state,
        playerMove:
          hostMove,
        enemyMove:
          guestMove
      )
    let winnerRaw:
      String?
    switch resolution
      .state
      .winner
    {
    case .player:
      winnerRaw = "host"
    case .enemy:
      winnerRaw = "guest"
    case nil:
      winnerRaw = nil
    }
    var message =
      resolution.message
    if hostWasAutomatic || guestWasAutomatic {
      let timeoutNote: String
      if hostWasAutomatic && guestWasAutomatic {
        timeoutNote = DeckSpawnL10n.text(
          "Ambos os jogadores ficaram sem tempo. Ação automática."
        )
      } else {
        timeoutNote = DeckSpawnL10n.format(
          "%@ ficou sem tempo. Ação automática.",
          hostWasAutomatic ? "Player 1" : "Player 2"
        )
      }
      message = timeoutNote + "\n" + message
    }
    let result =
      MultiplayerRoundResultMessage(
        round:
          battleRound,
        hostMoveRawValue:
          hostMove.rawValue,
        guestMoveRawValue:
          guestMove.rawValue,
        hostHP:
          resolution.state.playerHP,
        guestHP:
          resolution.state.enemyHP,
        nextRound:
          resolution.state.round,
        winner:
          winnerRaw,
        message:
          message,
        hostWasAutomatic: hostWasAutomatic,
        guestWasAutomatic: guestWasAutomatic
      )
    let wire =
      MultiplayerWireMessage(
        kind:
          MultiplayerWireKind.roundResult,
        playerState:
          nil,
        battleStart:
          nil,
        move:
          nil,
        roundStart:
          nil,
        roundResult:
          result
      )
    sendWire(
      wire
    )
    applyRoundResult(
      result
    )
  }
  private func applyRoundResult(
    _ result: MultiplayerRoundResultMessage
  ) {
    guard battleHasStarted, battleWinner == nil, result.round == battleRound,
          // Guest can receive a timeout result while still locally choosing.
          battlePhase == .choosingMove else { return }
    let damage = BattleDamage.between(
      playerBefore: localHP, enemyBefore: remoteHP,
      playerAfter: isHost ? result.hostHP : result.guestHP,
      enemyAfter: isHost ? result.guestHP : result.hostHP
    )
    let localizedResult = localizedRoundSummary(result)
    battleClockGeneration += 1
    hostHP =
      result.hostHP
    guestHP =
      result.guestHP
    hostMove =
      BattleMove(
        rawValue:
          result.hostMoveRawValue
      )
    guestMove =
      BattleMove(
        rawValue:
          result.guestMoveRawValue
      )
    lastBattleMessage = localizedResult
    if result.winner == "host" {
      battleWinner =
        .host
    } else if result.winner
      == "guest"
    {
      battleWinner =
        .guest
    } else {
      battleWinner =
        nil
    }
    // Nao envia "host venceu" diretamente ao SoundManager.
    // O host e o convidado convertem a mesma identidade vencedora
    // em vitoria/derrota LOCAL antes de reproduzir o audio.
    if let localWon = winnerIsLocal {
      onBattleResultConfirmed?(localWon)
    }
    let localMove = isHost ? hostMove : guestMove
    let remoteMove = isHost ? guestMove : hostMove
    if let localMove, let remoteMove {
      let roundResult: BattleRoundResult
      if localMove == remoteMove {
        roundResult = .draw
      } else if localMove.beats(remoteMove) {
        roundResult = .playerWin
      } else {
        roundResult = .enemyWin
      }
      let localWinner: BattleWinner?
      if let battleWinner {
        let localWon = (isHost && battleWinner == .host)
          || (!isHost && battleWinner == .guest)
        localWinner = localWon ? .player : .enemy
      } else {
        localWinner = nil
      }
      DispatchQueue.main.async {
        GameHaptics.roundResult(roundResult, winner: localWinner)
      }
    }
    let generation = battleClockGeneration
    if battleWinner != nil {
      battlePhase = .finished
      turnSecondsRemaining = 0
      roundGate = nil
      pendingNextRound = nil
      publishBattleTurnAnimation(damage: damage, completed: {})
      return
    }
    battlePhase = .showingResult
    pendingNextRound = result.nextRound
    if isHost {
      roundGate = MultiplayerRoundGate(round: result.round)
      DispatchQueue.main.asyncAfter(deadline: .now() + BattleRules.roundResultDisplaySeconds) { [weak self] in
        self?.markRoundGate(.resultDisplayed, round: result.round, generation: generation)
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + BattleRules.maxRoundAnimationWaitSeconds) { [weak self] in
        guard let self, self.battleClockGeneration == generation,
              self.roundGate?.didScheduleRecovery == false else { return }
        self.recordPreparationDiagnostic("round animation watchdog round=\(result.round)")
        self.markRoundGate(.watchdog, round: result.round, generation: generation)
      }
    }
    publishBattleTurnAnimation(damage: damage) { [weak self] in
      guard let self, self.battleClockGeneration == generation,
            self.battlePhase == .showingResult, self.battleRound == result.round else { return }
      if self.isHost {
        self.markRoundGate(.hostFinished, round: result.round, generation: generation)
      } else {
        self.sendWire(MultiplayerWireMessage(
          kind: MultiplayerWireKind.animationsFinished, playerState: nil, battleStart: nil,
          move: nil, roundStart: nil, roundResult: nil, animationsFinishedRound: result.round
        ))
      }
    }
  }

  private func markRoundGate(_ event: MultiplayerRoundGate.Event, round: Int, generation: Int) {
    guard isHost, battleHasStarted, battleWinner == nil, battlePhase == .showingResult,
          battleClockGeneration == generation, var gate = roundGate,
          let nextRound = pendingNextRound else { return }
    let shouldRecover = gate.mark(event, round: round)
    roundGate = gate
    if shouldRecover { scheduleNextRoundAsHost(round: nextRound) }
  }

  /// Both players build their own result message using their own language.
  /// The wire-transmitted `result.message` remains for old client fallback.
  private func localizedRoundSummary(_ result: MultiplayerRoundResultMessage) -> String {
    let hostCardID = isHost ? localCardID : remoteCardID
    let guestCardID = isHost ? remoteCardID : localCardID
    guard let hostCardID,
          let guestCardID,
          let hostCard = CardDatabase.card(named: hostCardID),
          let guestCard = CardDatabase.card(named: guestCardID),
          let hostMove = BattleMove(rawValue: result.hostMoveRawValue),
          let guestMove = BattleMove(rawValue: result.guestMoveRawValue)
    else {
      return DeckSpawnL10n.text(result.message)
    }

    let previousState = BattleState(
      playerCard: hostCard,
      enemyCard: guestCard,
      playerHP: hostHP,
      enemyHP: guestHP,
      round: result.round
    )
    let localMessage = BattleEngine.resolveTurn(
      state: previousState,
      playerMove: hostMove,
      enemyMove: guestMove
    ).message

    let hostTimedOut = result.hostWasAutomatic == true
    let guestTimedOut = result.guestWasAutomatic == true
    let note: String
    if hostTimedOut && guestTimedOut {
      note = DeckSpawnL10n.text("Ambos os jogadores ficaram sem tempo. Ação automática.")
    } else if hostTimedOut || guestTimedOut {
      note = DeckSpawnL10n.format(
        "%@ ficou sem tempo. Ação automática.",
        hostTimedOut ? "Player 1" : "Player 2"
      )
    } else if result.hostWasAutomatic == nil && result.guestWasAutomatic == nil
              && (result.message.contains("Ação automática.")
                  || result.message.contains("Automatic move.")) {
      // Old clients may send only a translated sentence, with no flags.
      note = DeckSpawnL10n.text("Tempo esgotado. Ação automática.")
    } else {
      note = ""
    }
    return note.isEmpty ? localMessage : note + "\n" + localMessage
  }

  private func publishBattleTurnAnimation(damage: BattleDamage?, completed: @escaping () -> Void) {
    guard let playerMove = localMove, let enemyMove = remoteMove else {
      completed()
      return
    }
    let roundResult: BattleRoundResult = playerMove == enemyMove ? .draw :
      (playerMove.beats(enemyMove) ? .playerWin : .enemyWin)
    let winner: BattleWinner? = winnerIsLocal.map { $0 ? .player : .enemy }
    if let callback = onBattleTurnResolved {
      callback(playerMove, enemyMove, roundResult, winner, damage, completed)
    } else {
      completed()
    }
  }
  private func scheduleNextRoundAsHost(
    round: Int
  ) {
    let generation = battleClockGeneration
    DispatchQueue.main.asyncAfter(
      deadline:
        .now()
        + BattleRules.roundRecoverySeconds
    ) { [weak self] in
      guard
        let self,
        self.isHost,
        self.battleHasStarted,
        self.battleClockGeneration == generation,
        self.battleWinner == nil,
        self.battlePhase == .showingResult,
        self.roundGate?.didScheduleRecovery == true
      else {
        return
      }
      let startsAt =
        Date()
        .addingTimeInterval(
          0.40
        )
        .timeIntervalSince1970
      let message =
        MultiplayerRoundStartMessage(
          round:
            round,
          startsAt:
            startsAt,
          turnDurationSeconds:
            BattleRules
            .turnDurationSeconds
        )
      let wire =
        MultiplayerWireMessage(
          kind:
            MultiplayerWireKind.roundStart,
          playerState:
            nil,
          battleStart:
            nil,
          move:
            nil,
          roundStart:
            message,
          roundResult:
            nil
        )
      self.sendWire(
        wire
      )
      self.applyRoundStart(
        message
      )
    }
  }
  private func applyRoundStart(
    _ message: MultiplayerRoundStartMessage
  ) {
    guard battlePhase == .showingResult, battleWinner == nil,
          message.round == pendingNextRound else { return }
    roundGate = nil
    pendingNextRound = nil
    battleClockGeneration += 1
    let generation =
      battleClockGeneration
    battleRound =
      message.round
    hostMove =
      nil
    guestMove =
      nil
    turnSecondsRemaining =
      message.turnDurationSeconds
    lastBattleMessage =
      DeckSpawnL10n.text("Prepare sua próxima ação.")
    battlePhase =
      .showingResult
    let delay = max(0, min(0.40, message.startsAt - Date().timeIntervalSince1970))
    DispatchQueue.main.asyncAfter(
      deadline:
        .now()
        + delay
    ) { [weak self] in
      guard
        let self,
        generation
          == self.battleClockGeneration,
        self.battleWinner == nil
      else {
        return
      }
      self.battlePhase =
        .choosingMove
      self.lastBattleMessage =
        DeckSpawnL10n.text("Escolha sua ação.")
      self.startTurnTimer(
        duration:
          message.turnDurationSeconds
      )
    }
  }
  private func receiveExactly(
    count: Int,
    from connection: NWConnection,
    accumulated: Data = Data(),
    completion:
      @escaping (Data?) -> Void
  ) {
    if accumulated.count
      >= count
    {
      completion(
        accumulated
      )
      return
    }
    let remaining =
      count
      - accumulated.count
    connection.receive(
      minimumIncompleteLength: 1,
      maximumLength:
        remaining
    ) {
      [weak self, weak connection]
      data,
      _,
      isComplete,
      error in
      guard
        let self,
        let connection
      else {
        completion(nil)
        return
      }
      if let error {
        self.recordPreparationDiagnostic("TCP read error: \(error), accumulated=\(accumulated.count)/\(count)")
        completion(nil)
        return
      }
      var next =
        accumulated
      if let data {
        next.append(
          data
        )
      }
      if next.count
        >= count
      {
        completion(
          next
        )
        return
      }
      if isComplete {
        self.recordPreparationDiagnostic("TCP EOF: received=\(next.count)/\(count)")
        completion(nil)
        return
      }
      self.receiveExactly(
        count:
          count,
        from:
          connection,
        accumulated:
          next,
        completion:
          completion
      )
    }
  }
  private func handleRemoteDisconnect(_ connection: NWConnection) {
    pendingIncomingConnections.removeValue(forKey: ObjectIdentifier(connection))
    incomingHandshakes.remove(ObjectIdentifier(connection))
    if hostConnection === connection {
      hostConnection = nil
      guestConnected = false
      clearPlayerSyncState()
      statusMessage = DeckSpawnL10n.text("Jogador desconectado. Aguardando outro jogador...")
    } else if guestConnection === connection {
      guestConnection = nil
      clearPlayerSyncState()
      let message = DeckSpawnL10n.text("O host encerrou a conexão.")
      connectionState = .failed(message)
      statusMessage = message
    }
  }

  private func clearPlayerSyncState() {
    localCardID = nil
    remoteCardID = nil
    localReady = false
    remoteReady = false
    localArenaReady = false
    remoteArenaReady = false
    resetBattleStateOnly()
  }

  private func resetCardSyncState() {
    clearPlayerSyncState()
  }
  private func resetBattleStateOnly() {
    roundGate = nil
    pendingNextRound = nil
    battleClockGeneration += 1
    battleHasStarted = false
    battlePhase =
      .waitingForArena
    battleCountdown =
      nil
    turnSecondsRemaining =
      BattleRules
      .turnDurationSeconds
    battleRound =
      1
    hostHP =
      0
    guestHP =
      0
    hostMove =
      nil
    guestMove =
      nil
    battleWinner =
      nil
    lastBattleMessage =
      nil
  }
  private func publishFailure(_ message: String) {
    connectionState = .failed(message)
    statusMessage = message
  }
  private static func generateJoinCode()
    -> String
  {
    String(
      format:
        "%06d",
      Int.random(
        in:
          0...999_999
      )
    )
  }
}
