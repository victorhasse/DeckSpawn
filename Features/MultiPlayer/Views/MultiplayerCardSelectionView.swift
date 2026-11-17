import SwiftUI
import UIKit

struct MultiplayerCardSelectionView: View {

    @ObservedObject

    var arState: GameARState

    @ObservedObject

    var gameFlow: GameFlowState

    @ObservedObject

    var service: MultiplayerService

    let onBack: () -> Void

    @State private var requestedSelection: MultiplayerArenaSelection?
    @State private var preparationError: String?
    @State private var showingPreparationError = false
    @State private var lastDiagnosticState: String?
    @State private var readySince: ContinuousClock.Instant?
    @State private var bothReadySince: ContinuousClock.Instant?
    @State private var waitingNoticeLogged = false
    @State private var copiedDiagnostics = false
    @State private var showingExitConfirmation = false
    @State private var showingSettings = false

    private struct PreparationInput: Equatable {
        let phase: CardScanPhase
        let activeCardID: String?
        let selection: MultiplayerArenaSelection?
        let announcedReady: Bool
        let connected: Bool
    }

    private var preparationInput: PreparationInput {
        let selection: MultiplayerArenaSelection?
        if service.bothPlayersReady,
           let local = service.localCardID,
           let remote = service.remoteCardID {
            selection = MultiplayerArenaSelection(localCardID: local, remoteCardID: remote)
        } else {
            selection = nil
        }
        return PreparationInput(
            phase: arState.phase,
            activeCardID: arState.activeCard?.id,
            selection: selection,
            announcedReady: service.localArenaReady,
            connected: service.isHost
                ? service.guestConnected && service.connectionState == .hosting
                : service.connectionState == .connected
        )
    }

    var body: some View {

        GeometryReader { geometry in

            ZStack {

                ARViewContainer(

                    state: arState

                )

                .ignoresSafeArea()

               
                if shouldShowScanner {
                    DeckSpawnScannerOverlay(
                        state: arState,
                        screenSize: geometry.size,
                        mode: .multiplayer
                    )
                }

                if service.battlePhase

                    != .waitingForArena {

                    MultiplayerBattleHUD(service: service, onExitBattle: requestBattleExit,
                                         onSettings: { showingSettings = true })

                    if service.battlePhase == .versus,
                       let local = service.localCard, let remote = service.remoteCard {
                        BattleVersusOverlay(player: local, opponent: remote, opponentTitle: "ADVERSÁRIO")
                            .transition(.opacity)
                            .zIndex(2)
                    }

                } else {

                    VStack(

                        spacing: 10

                    ) {

                        topBar

                        playerSyncStatus

                        Spacer()

                        bottomPanel

                    }

                    .padding(

                        .horizontal,

                        14

                    )

                    .padding(

                        .top,

                        8

                    )

                    .padding(

                        .bottom,

                        24

                    )

                }

                FloatingDamageOverlay(event: arState.floatingDamageEvent)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

        }

        .onAppear {
            service.recordPreparationDiagnostic("AR selection screen appeared")
            connectBattleAnimations()
            service.updateLocalCard(arState.activeCard?.id)
            synchronizeArena()
            syncStageRibbon()
        }
        .onDisappear {
            requestedSelection = nil
            service.onBattleTurnResolved = nil
            service.onBattleResultConfirmed = nil
            arState.setStageRibbonCue(.ambient)
        }
        .onChange(of: service.battlePhase) { _, _ in syncStageRibbon() }
        .onChange(of: service.battleCountdown) { _, _ in syncStageRibbon() }
        .onChange(of: arState.phase) { _, _ in syncStageRibbon() }
        .onChange(of: preparationInput) { _, _ in
            // Reevaluate on both AR and network changes, not just the Ready edge.
            if requestedSelection == nil, !showingPreparationError,
               arState.phase == .active || arState.activeCard == nil {
                service.updateLocalCard(arState.activeCard?.id)
            }
            synchronizeArena()
        }
        .onChange(of: arState.battlePreparationFailureEvent) { _, event in
            guard event != nil, requestedSelection != nil else { return }
            failPreparation("Não foi possível preparar a arena. Volte à sala e tente novamente.")
        }
        .task(id: service.battlePhase == .waitingForArena) { @MainActor in
            // onChange is useful for fast response, but it is a view-render
            // observer, not a reliable sole driver for a network handshake.
            // Reconcile the actual state while waiting, without re-summoning.
            guard service.battlePhase == .waitingForArena else {
                readySince = nil
                bothReadySince = nil
                waitingNoticeLogged = false
                return
            }
            while !Task.isCancelled, service.battlePhase == .waitingForArena,
                  !showingPreparationError {
                reconcilePreparation()
                do { try await Task.sleep(for: .milliseconds(250)) }
                catch { return }
            }
        }
        #if DEBUG
        .overlay(alignment: .topTrailing) {
            if service.battlePhase != .waitingForArena {
                diagnosticButton.padding(.top, 8).padding(.trailing, 64)
            }
        }
        #endif
        .alert(
            DeckSpawnL10n.text("Partida interrompida"),
            isPresented: $showingPreparationError
        ) {
            Button("OK") { leaveSelection() }
            #if DEBUG
            Button("Copiar diagnóstico e sair") {
                copyDiagnostics()
                leaveSelection()
            }
            #endif
        } message: {
            Text(preparationError ?? "")
        }
        .alert("Sair da batalha?", isPresented: $showingExitConfirmation) {
            Button("Continuar jogando", role: .cancel) {}
            Button("Sair da batalha", role: .destructive) { leaveSelection() }
        } message: {
            Text("A batalha será encerrada e você voltará à sala.")
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(state: arState)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var shouldShowScanner: Bool {

        switch arState.phase {

        case .searching,

             .aligning,

             .holding,

             .scanning,

             .confirmed,

             .summoning,

             .lost,

             .failed,

             .removing,

             .waitingForCardRemoval:

            return true

        case .active,

             .enemySummoning,

             .battleReady:

            return false

        }

    }

    @ViewBuilder

    private var bottomPanel: some View {

        if service.bothPlayersReady {

            BattlePreparationPanel(

                localArenaReady:

                    service.localArenaReady,

                remoteArenaReady:

                    service.remoteArenaReady

            )

        } else if arState.phase == .active {

            selectionControls

        }

    }

    private var topBar: some View {

        HStack {

            Button(

                action:

                    leaveSelection

            ) {

                Image(

                    systemName:

                        "chevron.left"

                )

                .fontWeight(.bold)

                .foregroundStyle(.white)

                .frame(

                    width: 42,

                    height: 42

                )

                .background(

                    Color.black.opacity(

                        0.66

                    )

                )

                .clipShape(

                    Circle()

                )

            }

            Spacer()

            VStack(

                spacing: 2

            ) {

                Text(

                    "ESCOLHA SEU PERSONAGEM"

                )

                .font(.caption)

                .fontWeight(.black)

                Text(

                    "Escaneie uma carta e confirme"

                )

                .font(.caption2)

                .opacity(0.65)

            }

            .foregroundStyle(.white)

            .padding(

                .horizontal,

                14

            )

            .padding(

                .vertical,

                8

            )

            .background(

                Color.black.opacity(

                    0.60

                )

            )

            .clipShape(

                Capsule()

            )

            Spacer()

            #if DEBUG
            diagnosticButton
            #else
            Color.clear.frame(width: 42, height: 42)
            #endif
        }
    }

    #if DEBUG
    private var diagnosticButton: some View {
        Button {
            copyDiagnostics()
        } label: {
            Image(systemName: copiedDiagnostics ? "checkmark" : "doc.on.doc")
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Color.black.opacity(0.66), in: Circle())
        }
        .accessibilityLabel("Copiar diagnóstico multiplayer")
    }
    #endif

    private var playerSyncStatus: some View {

        HStack(

            spacing: 8

        ) {

            syncCard(

                title: "VOCÊ",

                cardID:

                    service.localCardID,

                ready:

                    service.localReady

            )

            syncCard(

                title: "ADVERSÁRIO",

                cardID:

                    service.remoteCardID,

                ready:

                    service.remoteReady

            )

        }

    }

    private func syncCard(

        title: String,

        cardID: String?,

        ready: Bool

    ) -> some View {

        let card =

            cardID.flatMap {

                CardDatabase.card(

                    named: $0

                )

            }

        return VStack(

            alignment: .leading,

            spacing: 4

        ) {

            HStack(

                spacing: 5

            ) {

                Circle()

                    .fill(

                        ready

                        ? Color.green

                        : cardID != nil

                            ? Color.orange

                            : Color.gray

                    )

                    .frame(

                        width: 7,

                        height: 7

                    )

                Text(LocalizedStringKey(title))

                    .font(.caption2)

                    .fontWeight(.black)

                    .foregroundStyle(

                        .white.opacity(

                            0.60

                        )

                    )

            }

            Text(LocalizedStringKey(card?.displayName ?? "Escolhendo..."))

            .font(.caption)

            .fontWeight(.bold)

            .foregroundStyle(.white)

            .lineLimit(1)

            .minimumScaleFactor(0.70)

            Text(LocalizedStringKey(ready ? "PRONTO" : cardID != nil ? "Aguardando confirmação" : "Nenhuma carta"))

            .font(.caption2)

            .foregroundStyle(

                ready

                ? .green

                : .white.opacity(

                    0.50

                )

            )

        }

        .frame(

            maxWidth: .infinity,

            alignment: .leading

        )

        .padding(

            10

        )

        .background(

            Color.black.opacity(

                0.62

            )

        )

        .clipShape(

            RoundedRectangle(

                cornerRadius: 14

            )

        )

    }

    private var selectionControls: some View {

        VStack(

            spacing: 10

        ) {

            if let card =

                arState.activeCard {

                VStack(

                    spacing: 3

                ) {

                    Text(

                        "PERSONAGEM SELECIONADO"

                    )

                    .font(.caption2)

                    .fontWeight(.black)

                    .foregroundStyle(

                        .white.opacity(

                            0.55

                        )

                    )

                    Text(

                        card.displayName

                    )

                    .font(.headline)

                    .foregroundStyle(.white)

                }

            }

            if service.localReady {

                Label(

                    "VOCÊ ESTÁ PRONTO",

                    systemImage:

                        "checkmark.circle.fill"

                )

                .font(.headline)

                .fontWeight(.bold)

                .foregroundStyle(.green)

                .frame(

                    maxWidth: .infinity

                )

                .padding(

                    .vertical,

                    14

                )

                .background(

                    Color.black.opacity(

                        0.72

                    )

                )

                .clipShape(

                    RoundedRectangle(

                        cornerRadius: 16

                    )

                )

                Button {

                    service.setLocalReady(

                        false

                    )

                } label: {

                    Text(

                        "CANCELAR PRONTO"

                    )

                    .font(.subheadline)

                    .fontWeight(.semibold)

                    .foregroundStyle(.white)

                    .frame(

                        maxWidth: .infinity

                    )

                    .padding(

                        .vertical,

                        12

                    )

                    .background(

                        Color.white.opacity(

                            0.10

                        )

                    )

                    .clipShape(

                        RoundedRectangle(

                            cornerRadius: 14

                        )

                    )

                }

            } else {

                Button {

                    guard

                        arState.activeCard != nil

                    else {

                        return

                    }

                    service.recordPreparationDiagnostic("Ready button tapped | \(diagnosticState)")
                    service.updateLocalCard(arState.activeCard?.id)
                    service.setLocalReady(true)

                } label: {

                    Label(

                        "PRONTO",

                        systemImage:

                            "checkmark.circle.fill"

                    )

                    .font(.headline)

                    .fontWeight(.bold)

                    .foregroundStyle(.black)

                    .frame(

                        maxWidth: .infinity

                    )

                    .padding(

                        .vertical,

                        14

                    )

                    .background(

                        Color.green

                    )

                    .clipShape(

                        RoundedRectangle(

                            cornerRadius: 16

                        )

                    )

                }

                Button {

                    requestedSelection = nil

                    service.resetLocalSelection()

                    arState.removeCharacter()

                } label: {

                    Label(

                        "TROCAR CARTA",

                        systemImage:

                            "arrow.triangle.2.circlepath"

                    )

                    .font(.subheadline)

                    .fontWeight(.semibold)

                    .foregroundStyle(.white)

                    .frame(

                        maxWidth: .infinity

                    )

                    .padding(

                        .vertical,

                        12

                    )

                    .background(

                        Color.black.opacity(

                            0.72

                        )

                    )

                    .clipShape(

                        RoundedRectangle(

                            cornerRadius: 14

                        )

                    )

                }

            }

            if !service.remoteReady {

                Text(LocalizedStringKey(service.remoteCardID == nil ? "O adversário ainda está escolhendo uma carta." : "Aguardando o adversário confirmar."))

                .font(.caption2)

                .foregroundStyle(

                    .white.opacity(

                        0.60

                    )

                )

                .multilineTextAlignment(

                    .center

                )

            }

        }

        .padding(

            14

        )

        .background(

            Color.black.opacity(

                0.62

            )

        )

        .clipShape(

            RoundedRectangle(

                cornerRadius: 20

            )

        )

    }

    private func syncStageRibbon() {
        guard arState.phase == .battleReady else {
            arState.setStageRibbonCue(.ambient)
            return
        }
        switch service.battlePhase {
        case .waitingForArena: arState.setStageRibbonCue(.ambient)
        case .versus: arState.setStageRibbonCue(.versus)
        case .countdown:
            if let number = service.battleCountdown { arState.setStageRibbonCue(.countdown(number)) }
        case .choosingMove: arState.setStageRibbonCue(.battle)
        case .showingResult: arState.setStageRibbonCue(.action)
        case .finished: arState.setStageRibbonCue(.result)
        }
    }

    private func connectBattleAnimations() {
        service.onBattleResultConfirmed = { didWin in
            arState.announceLocalBattleResult(didWin: didWin)
        }
        service.onBattleTurnResolved = { playerMove, enemyMove, result, winner, damage, completed in
            arState.animateBattleTurn(
                playerMove: playerMove, enemyMove: enemyMove,
                result: result, winner: winner, damage: damage,
                animationsCompleted: completed
            )
        }
    }

    private var diagnosticState: String {
        "AR phase=\(arState.phase) active=\(arState.activeCard?.id ?? "-") requested=\(String(describing: requestedSelection)) bothPlayers=\(service.bothPlayersReady) bothArenas=\(service.bothArenasReady) connected=\(preparationInput.connected) failure=\(String(describing: arState.battlePreparationFailureEvent?.failure))"
    }

    private func copyDiagnostics() {
        #if DEBUG
        service.recordPreparationDiagnostic("SNAPSHOT \(diagnosticState)")
        UIPasteboard.general.string = service.preparationDiagnostics.joined(separator: "\n")
        copiedDiagnostics = true
        #endif
    }

    private func reconcilePreparation() {
        let snapshot = diagnosticState
        if snapshot != lastDiagnosticState {
            lastDiagnosticState = snapshot
            service.recordPreparationDiagnostic(snapshot)
        }
        let now = ContinuousClock.now
        if service.localReady {
            if readySince == nil { readySince = now }
        } else {
            readySince = nil
            waitingNoticeLogged = false
        }
        if !service.bothPlayersReady {
            bothReadySince = nil
            // The other player may simply be choosing a card. Do not abort.
            if let since = readySince, now - since >= .seconds(20), !waitingNoticeLogged {
                waitingNoticeLogged = true
                service.recordPreparationDiagnostic("WAIT >20s: remote Ready has not been confirmed")
            }
        } else if bothReadySince == nil {
            bothReadySince = now
        }
        synchronizeArena()
        guard !showingPreparationError else { return }
        service.reconcileBattleStart()
        // Arm the timeout as soon as both players are known ready, even if
        // the AR request itself never happens.
        if let since = bothReadySince, now - since >= .seconds(45),
           service.battlePhase == .waitingForArena {
            service.recordPreparationDiagnostic("TIMEOUT \(diagnosticState)")
            failPreparation("Tempo esgotado ao preparar a arena. Volte à sala e tente novamente.")
        }
    }

    private func synchronizeArena() {
        guard !showingPreparationError,
              service.battlePhase == .waitingForArena else { return }
        let input = preparationInput
        let matchingCard = input.activeCardID != nil
            && input.activeCardID == service.localCardID
        switch MultiplayerArenaGate.next(
            selection: input.selection,
            requested: requestedSelection,
            localCharacterActive: input.phase == .active,
            localCharacterMatches: matchingCard,
            arReady: input.phase == .battleReady,
            announcedReady: input.announcedReady,
            connected: input.connected
        ) {
        case .wait:
            break
        case .prepare(let selection):
            guard let remoteCard = service.remoteCard else {
                failPreparation("Não foi possível preparar a arena. Volte à sala e tente novamente.")
                return
            }
            requestedSelection = selection
            service.recordPreparationDiagnostic("AR prepare requested opponent=\(selection.remoteCardID)")
            arState.prepareBattle(against: remoteCard)
            if arState.battlePreparationFailureEvent != nil {
                failPreparation("Não foi possível preparar a arena. Volte à sala e tente novamente.")
            }
        case .announceReady:
            service.recordPreparationDiagnostic("AR phase battleReady: announcing arena")
            service.setLocalArenaReady(true)
        case .abort:
            failPreparation("O adversário saiu ou cancelou a seleção. Volte à sala e tente novamente.")
        }
    }

    private func failPreparation(_ key: String) {
        guard !showingPreparationError else { return }
        service.recordPreparationDiagnostic("AR interrupted: \(key) | \(diagnosticState)")
        preparationError = DeckSpawnL10n.text(key)
        showingPreparationError = true
        requestedSelection = nil
        // Clear Ready locally and inform the other phone before leaving.
        service.resetLocalSelection()
    }

    private func requestBattleExit() {
        if service.battlePhase == .finished {
            leaveSelection()
        } else {
            showingExitConfirmation = true
        }
    }

    private func leaveSelection() {

        requestedSelection = nil

        service.resetLocalSelection()

        arState.resetForNewSession()

        onBack()

    }

}

private struct BattlePreparationPanel: View {

    let localArenaReady: Bool

    let remoteArenaReady: Bool

    var body: some View {

        VStack(

            spacing: 10

        ) {

            ProgressView()

                .tint(.white)

            Text(LocalizedStringKey(localArenaReady ? "ARENA PRONTA" : "PREPARANDO ARENA..."))

            .font(.headline)

            .fontWeight(.black)

            .foregroundStyle(.white)

            Text(LocalizedStringKey(remoteArenaReady ? "O adversário também está pronto." : "Aguardando a arena do adversário..."))

            .font(.caption)

            .foregroundStyle(

                .white.opacity(

                    0.62

                )

            )

        }

        .frame(

            maxWidth: .infinity

        )

        .padding(

            16

        )

        .background(

            Color.black.opacity(

                0.70

            )

        )

        .clipShape(

            RoundedRectangle(

                cornerRadius: 20

            )

        )

    }

}

// MARK: - DeckSpawn Multiplayer Battle HUD V2

private struct MultiplayerBattleHUD: View {
    @ObservedObject var service: MultiplayerService
    let onExitBattle: () -> Void
    let onSettings: () -> Void

    var body: some View {
        ZStack {
            if let local = service.localCard, let remote = service.remoteCard {
                VStack(spacing: 11) {
                    HStack(spacing: 9) {
                        FighterHPCard(title: "VOCÊ", card: local, currentHP: service.localHP,
                                      maxHP: local.maxHP, progress: service.localHPProgress, isTrailing: false)
                        FighterHPCard(title: "ADVERSÁRIO", card: remote, currentHP: service.remoteHP,
                                      maxHP: remote.maxHP, progress: service.remoteHPProgress, isTrailing: true)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 68)

                    BattleRoundBanner(
                        round: service.battleRound,
                        message: service.battlePhase == .countdown ? nil : service.lastBattleMessage,
                        isResolving: service.battlePhase == .showingResult,
                        showsClock: service.battlePhase == .choosingMove,
                        secondsRemaining: service.turnSecondsRemaining
                    )
                    .padding(.horizontal, 20)
                    Spacer(minLength: 12)
                    battleControls(local: local, remote: remote)
                }
            }
            VStack {
                HStack {
                    Button(action: onExitBattle) {
                        HStack(spacing: 7) {
                            Image(systemName: service.battlePhase == .finished ? "chevron.left" : "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 18, weight: .bold))
                            if service.battlePhase != .finished {
                                Text("SAIR").font(.system(size: 12, weight: .bold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(height: 44)
                        .padding(.horizontal, service.battlePhase == .finished ? 0 : 14)
                        .frame(minWidth: 44)
                        .background(Color.black.opacity(0.62), in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(service.battlePhase == .finished ? Color.white.opacity(0.14) : Color.red.opacity(0.65), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(service.battlePhase == .finished ? Text("VOLTAR À SALA") : Text("Sair da batalha"))
                    Spacer()
                    Button(action: onSettings) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 19))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.62), in: Circle())
                    }
                    .accessibilityLabel("Configurações")
                }
                Spacer()
            }
            .padding(.top, 8)
            .padding(.horizontal, 14)
        }
    }

    @ViewBuilder
    private func battleControls(local: CardDefinition, remote: CardDefinition) -> some View {
        switch service.battlePhase {
        case .finished:
            BattleResultPanel(winner: service.winnerIsLocal == true ? .player : .enemy,
                              playerName: local.displayName, enemyName: remote.displayName,
                              rounds: service.battleRound, remainingHP: service.localHP,
                              onExit: onExitBattle, onRematch: nil,
                              exitTitle: "VOLTAR À SALA", exitIcon: "arrow.uturn.backward.circle.fill")
        case .choosingMove:
            if let move = service.localMove {
                SelectedMovePanel(move: move, secondsRemaining: service.turnSecondsRemaining)
            } else {
                BattleActionPanel(isDisabled: !service.canSubmitLocalMove, onMove: service.submitLocalMove)
            }
        case .versus, .countdown, .waitingForArena, .showingResult:
            BattleActionPanel(isDisabled: true, onMove: service.submitLocalMove)
        }
    }
}

private struct SelectedMovePanel: View {
    let move: BattleMove
    let secondsRemaining: Int

    private var accent: Color { BattleTheme.cyan }

    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 31))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.55), radius: 10)

            Text("AÇÃO CONFIRMADA")
                .font(.system(size: 13, weight: .black))
                .tracking(1.1)
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                Image(systemName: move.systemImage)
                    .foregroundStyle(BattleTheme.violet)
                Text(LocalizedStringKey(move.displayName))
                    .foregroundStyle(.white)
            }
            .font(.system(size: 17, weight: .black, design: .rounded))

            Text("Aguardando o adversário • \(secondsRemaining)s")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity)
        .padding(19)
        .background(
            BattleTheme.ink.opacity(0.94),
            in: RoundedRectangle(cornerRadius: 23)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 23)
                .stroke(accent.opacity(0.55), lineWidth: 1)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 24)
    }
}

private struct MultiplayerScannerOverlay: View {

    @ObservedObject

    var state: GameARState

    let screenSize: CGSize

    var body: some View {

        let guideRect =

            ScanLayout.guideRect(

                in: screenSize

            )

        ZStack {

            RoundedRectangle(

                cornerRadius: 22

            )

            .stroke(

                borderColor,

                style:

                    StrokeStyle(

                        lineWidth: 3,

                        dash:

                            state.phase

                                == .scanning

                            ? []

                            : [10, 8]

                    )

            )

            .frame(

                width:

                    guideRect.width,

                height:

                    guideRect.height

            )

            .position(

                x: guideRect.midX,

                y: guideRect.midY

            )

            VStack(

                spacing: 5

            ) {

                Image(

                    systemName:

                        iconName

                )

                .font(

                    .system(size: 28)

                )

                Text(LocalizedStringKey(title))

                    .font(.caption)

                    .fontWeight(.bold)

            }

            .foregroundStyle(

                borderColor

            )

            .position(

                x: guideRect.midX,

                y: guideRect.midY

            )

            Text(LocalizedStringKey(instruction))

                .font(.callout)

                .foregroundStyle(.white)

                .multilineTextAlignment(

                    .center

                )

                .frame(

                    width: 300

                )

                .position(

                    x:

                        screenSize.width / 2,

                    y:

                        min(

                            guideRect.maxY + 55,

                            screenSize.height - 40

                        )

                )

        }

        .allowsHitTesting(false)

    }

    private var title: String {

        switch state.phase {

        case .searching:

            return "PROCURANDO CARTA"

        case .aligning:

            return "CARTA DETECTADA"

        case .holding:

            return "MANTENHA PARADA"

        case .scanning:

            return "LENDO CARTA..."

        case .confirmed:

            return "CARTA RECONHECIDA"

        case .summoning:

            return "INVOCANDO..."

        case .lost:

            return "PERDI A CARTA"

        case .failed:

            return "CARTA NÃO RECONHECIDA"

        case .removing:

            return "REMOVENDO..."

        case .waitingForCardRemoval:

            return "RETIRE A CARTA"

        default:

            return ""

        }

    }

    private var instruction: String {

        switch state.phase {

        case .searching:

            return "Mostre a carta que você quer usar nesta partida"

        case .aligning:

            return "Centralize a carta no campo de leitura"

        case .holding:

            return "Mantenha a carta imóvel"

        case .scanning:

            return "Não retire a carta até concluir a leitura"

        case .confirmed:

            return "Carta reconhecida"

        case .summoning:

            return "Preparando seu personagem..."

        case .lost:

            return "Reposicione a carta"

        case .failed:

            return "Tente novamente com uma carta cadastrada"

        case .removing:

            return "Preparando nova seleção..."

        case .waitingForCardRemoval:

            return "Retire a carta para escolher outra"

        default:

            return ""

        }

    }

    private var iconName: String {

        switch state.phase {

        case .confirmed:

            return "checkmark.circle.fill"

        case .failed:

            return "xmark.circle.fill"

        case .summoning:

            return "sparkles"

        case .waitingForCardRemoval:

            return "rectangle.portrait.and.arrow.forward"

        default:

            return "viewfinder"

        }

    }

    private var borderColor: Color {

        switch state.phase {

        case .aligning:

            return .orange

        case .holding:

            return .yellow

        case .scanning:

            return .cyan

        case .confirmed:

            return .green

        case .summoning:

            return .purple

        case .failed:

            return .red

        case .waitingForCardRemoval:

            return .orange

        default:

            return .white

        }

    }

}
