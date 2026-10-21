import Combine
import Foundation
import Network
final class MultiplayerService: ObservableObject, @unchecked Sendable {
  static let serviceType = "_cardarenaar._tcp"
  @Published private(set) var hostedRoom: HostedRoom?
  @Published private(set) var discoveredRooms: [DiscoveredRoom] = []
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
        BattleWinner?
      ) -> Void
    )?
  /// Chamado quando o host confirma o vencedor da partida.
  /// O Bool ja esta convertido para a perspectiva deste iPhone.
  /// true = vitoria local; false = derrota local.
  var onBattleResultConfirmed: ((Bool) -> Void)?

  private let queue = DispatchQueue(
    label: "CardArenaAR.Multiplayer",
    qos: .userInitiated
  )
  private var listener: NWListener?
  private var browser: NWBrowser?
  private var hostConnection: NWConnection?
  private var guestConnection: NWConnection?
  private var battleHasStarted = false
  private var battleClockGeneration = 0
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
    do {
      let parameters = NWParameters.tcp
      parameters.includePeerToPeer = true
      let listener =
        try NWListener(
          using: parameters
        )
      let txtRecord =
        NWTXTRecord([
          "roomID": roomID,
          "privacy": privacy.rawValue,
          "version": "3",
        ])
      listener.service =
        NWListener.Service(
          name: cleanName,
          type: Self.serviceType,
          domain: nil,
          txtRecord: txtRecord
        )
      listener.stateUpdateHandler = {
        [weak self] state in
        guard let self else {
          return
        }
        switch state {
        case .ready:
          DispatchQueue.main.async {
            self.hostedRoom = room
            self.connectionState = .hosting
            self.statusMessage =
              DeckSpawnL10n.text("Sala criada. Aguardando jogador...")
          }
        case .failed(let error):
          self.publishFailure(
            DeckSpawnL10n.format("Não foi possível criar a sala: %@", error.localizedDescription)
          )
          self.stopHosting()
        default:
          break
        }
      }
      listener.newConnectionHandler = {
        [weak self] connection in
        self?.handleIncomingConnection(
          connection,
          room: room
        )
      }
      self.listener = listener
      listener.start(
        queue: queue
      )
    } catch {
      publishFailure(
        DeckSpawnL10n.format("Não foi possível criar a sala: %@", error.localizedDescription)
      )
    }
  }
  func deleteRoom() {
    stopHosting()
    resetCardSyncState()
    DispatchQueue.main.async {
      self.hostedRoom = nil
      self.guestConnected = false
      self.connectionState = .idle
      self.statusMessage = nil
    }
  }
  func startBrowsing() {
    stopBrowsing()
    let parameters = NWParameters.tcp
    parameters.includePeerToPeer = true
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
      [weak self] state in
      guard let self else {
        return
      }
      switch state {
      case .ready:
        DispatchQueue.main.async {
          self.connectionState =
            .browsing
          self.statusMessage =
            DeckSpawnL10n.text("Procurando salas disponíveis...")
        }
      case .failed(let error):
        self.publishFailure(
          DeckSpawnL10n.format("Não foi possível procurar salas: %@", error.localizedDescription)
        )
      default:
        break
      }
    }
    browser.browseResultsChangedHandler = {
      [weak self] results, _ in
      guard let self else {
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
      DispatchQueue.main.async {
        self.discoveredRooms =
          rooms
      }
    }
    self.browser = browser
    browser.start(
      queue: queue
    )
  }
  func stopBrowsing() {
    browser?.cancel()
    browser = nil
    DispatchQueue.main.async {
      self.discoveredRooms = []
    }
  }
  func join(
    room: DiscoveredRoom,
    code: String?
  ) {
    guestConnection?.cancel()
    guestConnection = nil
    resetCardSyncState()
    DispatchQueue.main.async {
      self.connectionState =
        .connecting
      self.statusMessage =
        DeckSpawnL10n.format("Entrando em %@...", room.name)
    }
    let parameters =
      NWParameters.tcp
    parameters.includePeerToPeer =
      true
    let connection =
      NWConnection(
        to: room.endpoint,
        using: parameters
      )
    guestConnection =
      connection
    connection.stateUpdateHandler = {
      [weak self, weak connection] state in
      guard
        let self,
        let connection
      else {
        return
      }
      switch state {
      case .ready:
        self.sendJoinRequest(
          through: connection,
          room: room,
          code: code
        )
      case .failed(let error):
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
    guestConnection?.cancel()
    guestConnection = nil
    resetCardSyncState()
    DispatchQueue.main.async {
      self.connectionState =
        .idle
      self.statusMessage = nil
    }
  }
  func stopAll() {
    stopBrowsing()
    stopHosting()
    guestConnection?.cancel()
    guestConnection = nil
    resetCardSyncState()
    DispatchQueue.main.async {
      self.hostedRoom = nil
      self.guestConnected = false
      self.connectionState = .idle
      self.statusMessage = nil
    }
  }
  func updateLocalCard(
    _ cardID: String?
  ) {
    DispatchQueue.main.async {
      self.localCardID =
        cardID
      self.localReady =
        false
      self.localArenaReady =
        false
      self.resetBattleStateOnly()
      self.sendCurrentPlayerState()
    }
  }
  func setLocalReady(
    _ ready: Bool
  ) {
    DispatchQueue.main.async {
      guard
        self.localCardID != nil
      else {
        return
      }
      self.localReady =
        ready
      if !ready {
        self.localArenaReady =
          false
        self.resetBattleStateOnly()
      }
      self.sendCurrentPlayerState()
      self.tryBeginBattleAsHost()
    }
  }
  func setLocalArenaReady(
    _ ready: Bool
  ) {
    DispatchQueue.main.async {
      guard
        self.localReady,
        self.localCardID != nil
      else {
        return
      }
      self.localArenaReady =
        ready
      self.sendCurrentPlayerState()
      self.tryBeginBattleAsHost()
    }
  }
  func resetLocalSelection() {
    DispatchQueue.main.async {
      self.localCardID = nil
      self.localReady = false
      self.localArenaReady = false
      self.resetBattleStateOnly()
      self.sendCurrentPlayerState()
    }
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
      if let advertisedID =
        values["roomID"]
      {
        roomID =
          advertisedID
      }
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
    if hostConnection != nil {
      sendResponse(
        JoinResponse(
          accepted: false,
          message:
            "A sala já possui dois jogadores."
        ),
        through:
          connection,
        cancelAfterSend:
          true
      )
      return
    }
    connection.stateUpdateHandler = {
      [weak self, weak connection] state in
      guard
        let self,
        let connection
      else {
        return
      }
      switch state {
      case .ready:
        self.receiveJoinRequest(
          from: connection,
          room: room
        )
      case .failed,
        .cancelled:
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
  private func receiveJoinRequest(
    from connection: NWConnection,
    room: HostedRoom
  ) {
    connection.receive(
      minimumIncompleteLength: 1,
      maximumLength: 4096
    ) {
      [weak self, weak connection]
      data,
      _,
      _,
      error in
      guard
        let self,
        let connection
      else {
        return
      }
      if let error {
        self.publishFailure(
          DeckSpawnL10n.format("Erro recebendo pedido de entrada: %@", error.localizedDescription)
        )
        connection.cancel()
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
      DispatchQueue.main.async {
        self.guestConnected =
          true
        self.statusMessage =
          DeckSpawnL10n.text("Jogador 2 conectado.")
        self.beginReceivingWireMessages(
          on: connection
        )
      }
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
        try? JSONEncoder()
        .encode(
          request
        )
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
          if let error {
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
    connection.receive(
      minimumIncompleteLength: 1,
      maximumLength: 4096
    ) {
      [weak self, weak connection]
      data,
      _,
      _,
      error in
      guard
        let self,
        let connection
      else {
        return
      }
      if let error {
        self.publishFailure(
          DeckSpawnL10n.format("Erro recebendo resposta da sala: %@", error.localizedDescription)
        )
        return
      }
      guard
        let data,
        let response =
          try? JSONDecoder()
          .decode(
            JoinResponse.self,
            from: data
          )
      else {
        self.publishFailure(
          DeckSpawnL10n.text("A sala enviou uma resposta inválida.")
        )
        return
      }
      DispatchQueue.main.async {
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
          self.sendCurrentPlayerState()
        } else {
          self.connectionState =
            .failed(DeckSpawnL10n.text(response.message))
          self.statusMessage = DeckSpawnL10n.text(response.message)
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
        try? JSONEncoder()
        .encode(
          response
        )
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
    guard
      let connection =
        activeConnection
    else {
      return
    }
    guard
      let payload =
        try? JSONEncoder()
        .encode(
          wire
        )
    else {
      return
    }
    let count =
      UInt32(
        payload.count
      )
    var packet = Data()
    packet.append(
      UInt8(
        (count >> 24)
          & 0xFF
      )
    )
    packet.append(
      UInt8(
        (count >> 16)
          & 0xFF
      )
    )
    packet.append(
      UInt8(
        (count >> 8)
          & 0xFF
      )
    )
    packet.append(
      UInt8(
        count
          & 0xFF
      )
    )
    packet.append(
      payload
    )
    connection.send(
      content:
        packet,
      completion:
        .contentProcessed {
          [weak self] error in
          if let error {
            self?.publishFailure(
              DeckSpawnL10n.format("Erro sincronizando a partida: %@", error.localizedDescription)
            )
          }
        }
    )
  }
  private var activeConnection:
    NWConnection?
  {
    hostConnection
      ?? guestConnection
  }
  private func beginReceivingWireMessages(
    on connection: NWConnection
  ) {
    receiveExactly(
      count: 4,
      from: connection
    ) {
      [weak self, weak connection]
      header in
      guard
        let self,
        let connection,
        let header,
        header.count == 4
      else {
        return
      }
      let bytes =
        [UInt8](
          header
        )
      let length =
        (UInt32(bytes[0]) << 24)
        | (UInt32(bytes[1]) << 16)
        | (UInt32(bytes[2]) << 8)
        | UInt32(bytes[3])
      guard
        length > 0,
        length <= 65_536
      else {
        connection.cancel()
        return
      }
      self.receiveExactly(
        count:
          Int(length),
        from:
          connection
      ) {
        [weak self, weak connection]
        payload in
        guard
          let self,
          let connection,
          let payload,
          let wire =
            try? JSONDecoder()
            .decode(
              MultiplayerWireMessage.self,
              from: payload
            )
        else {
          return
        }
        DispatchQueue.main.async {
          self.handleWireMessage(
            wire
          )
        }
        self.beginReceivingWireMessages(
          on: connection
        )
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
      remoteCardID =
        state.cardID
      remoteReady =
        state.ready
      remoteArenaReady =
        state.arenaReady
      if battleHasStarted,
        !state.ready
          || state.cardID == nil
      {
        resetBattleStateOnly()
        lastBattleMessage =
          DeckSpawnL10n.text("O adversário cancelou a seleção.")
      }
      if isHost {
        sendCurrentPlayerState()
        tryBeginBattleAsHost()
      }
    case MultiplayerWireKind.battleStart:
      guard
        let message =
          wire.battleStart
      else {
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
        battlePhase
          == .choosingMove,
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
    case MultiplayerWireKind.roundStart:
      guard
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
    battlePhase =
      .countdown
    battleCountdown =
      message.countdownSeconds
    turnSecondsRemaining =
      message.turnDurationSeconds
    lastBattleMessage =
      DeckSpawnL10n.text("Prepare-se!")
    battleClockGeneration += 1
    let generation =
      battleClockGeneration
    let delay =
      max(
        0,
        message.countdownStartsAt
          - Date()
          .timeIntervalSince1970
      )
    DispatchQueue.main.asyncAfter(
      deadline:
        .now()
        + delay
    ) { [weak self] in
      self?.runBattleCountdown(
        remaining:
          message.countdownSeconds,
        turnDuration:
          message.turnDurationSeconds,
        generation:
          generation
      )
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
    // O resultado final so deve ser anunciado uma vez por batalha,
    // mesmo que a rede repita o pacote de uma rodada.
    let previouslyFinished = battleWinner != nil
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
    if !previouslyFinished, let localWon = winnerIsLocal {
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
    publishBattleTurnAnimation()
    if battleWinner != nil {
      battlePhase =
        .finished
      turnSecondsRemaining =
        0
      return
    }
    battlePhase =
      .showingResult
    if isHost {
      scheduleNextRoundAsHost(
        round:
          result.nextRound
      )
    }
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

  private func publishBattleTurnAnimation() {
    guard
      let hostMove,
      let guestMove
    else {
      return
    }
    let playerMove =
      isHost
      ? hostMove
      : guestMove
    let enemyMove =
      isHost
      ? guestMove
      : hostMove
    let roundResult:
      BattleRoundResult
    if playerMove ==
      enemyMove
    {
      roundResult =
        .draw
    } else if playerMove
      .beats(
        enemyMove
      )
    {
      roundResult =
        .playerWin
    } else {
      roundResult =
        .enemyWin
    }
    let winner:
      BattleWinner?
    guard let battleWinner else {
      winner =
        nil
      onBattleTurnResolved?(
        playerMove,
        enemyMove,
        roundResult,
        winner
      )
      return
    }
    let localWon =
      (isHost
        && battleWinner == .host)
      || (!isHost
        && battleWinner == .guest)
    winner =
      localWon
      ? .player
      : .enemy
    onBattleTurnResolved?(
      playerMove,
      enemyMove,
      roundResult,
      winner
    )
  }
  private func scheduleNextRoundAsHost(
    round: Int
  ) {
    DispatchQueue.main.asyncAfter(
      deadline:
        .now()
        + BattleRules
        .roundResultDisplaySeconds
    ) { [weak self] in
      guard
        let self,
        self.isHost,
        self.battleWinner == nil
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
    let delay =
      max(
        0,
        message.startsAt
          - Date()
          .timeIntervalSince1970
      )
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
      if error != nil {
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
  private func handleRemoteDisconnect(
    _ connection: NWConnection
  ) {
    if hostConnection
      === connection
    {
      hostConnection =
        nil
      DispatchQueue.main.async {
        self.guestConnected =
          false
        self.remoteCardID =
          nil
        self.remoteReady =
          false
        self.remoteArenaReady =
          false
        self.resetBattleStateOnly()
        self.statusMessage =
          DeckSpawnL10n.text("Jogador desconectado. Aguardando outro jogador...")
      }
    }
    if guestConnection
      === connection
    {
      guestConnection =
        nil
      DispatchQueue.main.async {
        self.remoteCardID =
          nil
        self.remoteReady =
          false
        self.remoteArenaReady =
          false
        self.resetBattleStateOnly()
        self.connectionState =
          .failed(
            DeckSpawnL10n.text("O host encerrou a conexão.")
          )
        self.statusMessage =
          DeckSpawnL10n.text("O host encerrou a conexão.")
      }
    }
  }
  private func resetCardSyncState() {
    DispatchQueue.main.async {
      self.localCardID =
        nil
      self.remoteCardID =
        nil
      self.localReady =
        false
      self.remoteReady =
        false
      self.localArenaReady =
        false
      self.remoteArenaReady =
        false
      self.resetBattleStateOnly()
    }
  }
  private func resetBattleStateOnly() {
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
  private func publishFailure(
    _ message: String
  ) {
    DispatchQueue.main.async {
      self.connectionState =
        .failed(
          message
        )
      self.statusMessage =
        message
    }
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
