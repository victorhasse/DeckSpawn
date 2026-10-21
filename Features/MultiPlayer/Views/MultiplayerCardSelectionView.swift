import SwiftUI

struct MultiplayerCardSelectionView: View {

    @ObservedObject

    var arState: GameARState

    @ObservedObject

    var gameFlow: GameFlowState

    @ObservedObject

    var service: MultiplayerService

    let onBack: () -> Void

    @State

    private var didRequestEnemySummon = false

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

                    MultiplayerBattleHUD(

                        service: service,

                        onExitBattle:

                            leaveSelection

                    )

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

            }

        }

        .onAppear {

            connectBattleAnimations()

            beginArenaSetupIfNeeded()

        }

        .onDisappear {

            service.onBattleTurnResolved = nil
            service.onBattleResultConfirmed = nil

        }

        .onChange(

            of: service.bothPlayersReady

        ) {

            _,

            ready in

            if ready {

                beginArenaSetupIfNeeded()

            }

        }

        .onChange(

            of: arState.activeCard?.id

        ) {

            _,

            newCardID in

            service.updateLocalCard(

                newCardID

            )

        }

        .onChange(

            of: arState.phase

        ) {

            _,

            newPhase in

            if newPhase == .battleReady,

               didRequestEnemySummon {

                service.setLocalArenaReady(

                    true

                )

            }

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

            Color.clear

                .frame(

                    width: 42,

                    height: 42

                )

        }

    }

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

                    service.setLocalReady(

                        true

                    )

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

                    didRequestEnemySummon =

                        false

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

    private func connectBattleAnimations() {

        // Recebe a decisao definitiva ja localizada pelo MultiplayerService.
        // Independente da animacao AR estar disponivel no instante do fim.
        service.onBattleResultConfirmed = { didWin in
            arState.announceLocalBattleResult(didWin: didWin)
        }

        service.onBattleTurnResolved = {

            playerMove,

            enemyMove,

            result,

            winner in

            arState.animateBattleTurn(

                playerMove:

                    playerMove,

                enemyMove:

                    enemyMove,

                result:

                    result,

                winner:

                    winner

            )

        }

    }

    private func beginArenaSetupIfNeeded() {

        guard

            service.bothPlayersReady,

            !didRequestEnemySummon,

            arState.phase == .active,

            let remoteCard =

                service.remoteCard

        else {

            return

        }

        didRequestEnemySummon =

            true

        arState.prepareBattle(

            against:

                remoteCard

        )

    }

    private func leaveSelection() {

        didRequestEnemySummon =

            false

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

private enum MultiplayerBattleTheme {
    static let cyan = Color(red: 0.16, green: 0.91, blue: 1.0)
    static let violet = Color(red: 0.64, green: 0.39, blue: 1.0)
    static let ink = Color(red: 0.035, green: 0.055, blue: 0.14)
    static let panel = Color(red: 0.045, green: 0.075, blue: 0.19)
}

private struct MultiplayerBattleHUD: View {
    @ObservedObject var service: MultiplayerService
    let onExitBattle: () -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 11) {
                HStack(spacing: 9) {
                    MultiplayerHPCard(
                        title: "VOCÊ",
                        card: service.localCard,
                        currentHP: service.localHP,
                        progress: service.localHPProgress,
                        isTrailing: false
                    )
                    MultiplayerHPCard(
                        title: "ADVERSÁRIO",
                        card: service.remoteCard,
                        currentHP: service.remoteHP,
                        progress: service.remoteHPProgress,
                        isTrailing: true
                    )
                }
                .padding(.horizontal, 14)
                .padding(.top, 68)

                battleStatus
                    .padding(.horizontal, 20)

                Spacer(minLength: 12)

                battleControls
            }

            // Keep the exit control in the same location as the existing HUD.
            VStack {
                HStack {
                    Button(action: onExitBattle) {
                        Image(systemName: "chevron.left")
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(Color.black.opacity(0.66), in: Circle())
                    }
                    .accessibilityLabel("Voltar")
                    Spacer()
                }
                Spacer()
            }
            .padding(.top, 8)
            .padding(.horizontal, 14)

            if service.battlePhase == .countdown,
               let countdown = service.battleCountdown {
                countdownPanel(countdown)
                    .transition(.scale(scale: 0.88).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(
            .easeInOut(duration: 0.22),
            value: service.battlePhase == .countdown
        )
    }

    private var battleStatus: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.horizontal.fill")
                        .foregroundStyle(MultiplayerBattleTheme.cyan)
                    Text("RODADA \(service.battleRound)")
                        .foregroundStyle(.white)
                }
                .font(.system(size: 11, weight: .black, design: .rounded))

                if let message = service.lastBattleMessage {
                    // MultiplayerService already provides a localized string.
                    Text(message)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.86))
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .id(message)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if service.battlePhase == .choosingMove {
                turnClock
            } else if service.battlePhase == .showingResult {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 25))
                    .foregroundStyle(MultiplayerBattleTheme.violet)
                    .frame(width: 45, height: 45)
            } else if service.battlePhase == .countdown {
                ProgressView()
                    .tint(MultiplayerBattleTheme.cyan)
                    .frame(width: 45, height: 45)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            MultiplayerBattleTheme.panel.opacity(0.90),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(MultiplayerBattleTheme.cyan.opacity(0.29), lineWidth: 1)
        }
    }

    private var turnClock: some View {
        let duration = max(1, BattleRules.turnDurationSeconds)
        let ratio = min(
            max(Double(service.turnSecondsRemaining) / Double(duration), 0),
            1
        )
        let color: Color = service.turnSecondsRemaining <= 5 ? .red :
            (service.turnSecondsRemaining <= 10 ? .orange : MultiplayerBattleTheme.cyan)

        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.11), lineWidth: 4)
            Circle()
                .trim(from: 0, to: ratio)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.3), value: service.turnSecondsRemaining)
            Text("\(service.turnSecondsRemaining)")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(width: 45, height: 45)
        .accessibilityLabel("\(service.turnSecondsRemaining)s")
    }

    private func countdownPanel(_ seconds: Int) -> some View {
        VStack(spacing: 12) {
            Text("PREPARE-SE")
                .font(.system(size: 13, weight: .black))
                .tracking(2)
                .foregroundStyle(MultiplayerBattleTheme.cyan)

            ZStack {
                Circle()
                    .stroke(MultiplayerBattleTheme.violet.opacity(0.30), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(
                        AngularGradient(
                            colors: [
                                MultiplayerBattleTheme.cyan,
                                MultiplayerBattleTheme.violet,
                                MultiplayerBattleTheme.cyan
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text("\(seconds)")
                    .font(.system(size: 76, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .id(seconds)
                    .transition(.opacity.combined(with: .scale))
            }
            .frame(width: 152, height: 152)
            .shadow(color: MultiplayerBattleTheme.cyan.opacity(0.40), radius: 18)
        }
        .padding(29)
        .background(
            MultiplayerBattleTheme.ink.opacity(0.94),
            in: RoundedRectangle(cornerRadius: 30)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 30)
                .stroke(
                    LinearGradient(
                        colors: [MultiplayerBattleTheme.cyan, MultiplayerBattleTheme.violet],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        }
        .shadow(color: .black.opacity(0.45), radius: 25)
    }

    @ViewBuilder
    private var battleControls: some View {
        switch service.battlePhase {
        case .countdown, .waitingForArena:
            EmptyView()

        case .choosingMove:
            if let move = service.localMove {
                SelectedMovePanel(
                    move: move,
                    secondsRemaining: service.turnSecondsRemaining
                )
            } else {
                MultiplayerActionPanel(
                    enabled: service.canSubmitLocalMove,
                    onMove: { move in
                        service.submitLocalMove(move)
                    }
                )
            }

        case .showingResult:
            RoundResultPanel(
                localMove: service.localMove,
                remoteMove: service.remoteMove
            )

        case .finished:
            MultiplayerBattleResultPanel(
                victory: service.winnerIsLocal ?? false,
                localName: service.localCard?.displayName ?? "Você",
                remoteName: service.remoteCard?.displayName ?? "Adversário",
                onExit: onExitBattle
            )
        }
    }
}

private struct MultiplayerHPCard: View {
    let title: String
    let card: CardDefinition?
    let currentHP: Int
    let progress: Double
    let isTrailing: Bool

    private var accent: Color {
        isTrailing ? MultiplayerBattleTheme.violet : MultiplayerBattleTheme.cyan
    }

    private var healthColor: Color {
        progress <= 0.25 ? .red : (progress <= 0.50 ? .orange : accent)
    }

    var body: some View {
        VStack(alignment: isTrailing ? .trailing : .leading, spacing: 7) {
            HStack(spacing: 5) {
                if !isTrailing {
                    Circle().fill(accent).frame(width: 6, height: 6)
                }
                Text(LocalizedStringKey(title))
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.3)
                if isTrailing {
                    Circle().fill(accent).frame(width: 6, height: 6)
                }
            }
            .foregroundStyle(accent)

            Text(LocalizedStringKey(card?.displayName ?? "—"))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            GeometryReader { geo in
                ZStack(alignment: isTrailing ? .trailing : .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [healthColor.opacity(0.65), healthColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * min(max(progress, 0), 1))
                        .animation(.easeOut(duration: 0.45), value: progress)
                }
            }
            .frame(height: 7)

            Text("\(currentHP) / \(card?.maxHP ?? 0) HP")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.80))
        }
        .frame(maxWidth: .infinity, alignment: isTrailing ? .trailing : .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            MultiplayerBattleTheme.panel.opacity(0.91),
            in: RoundedRectangle(cornerRadius: 17)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 17)
                .stroke(accent.opacity(0.46), lineWidth: 1)
        }
        .shadow(color: accent.opacity(0.10), radius: 9)
    }
}

private struct MultiplayerActionPanel: View {
    let enabled: Bool
    let onMove: (BattleMove) -> Void

    private func color(for move: BattleMove) -> Color {
        switch move {
        case .impact:
            return MultiplayerBattleTheme.cyan
        case .technique:
            return MultiplayerBattleTheme.violet
        case .defense:
            return Color(red: 0.28, green: 0.85, blue: 0.75)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "gamecontroller.fill")
                    .foregroundStyle(MultiplayerBattleTheme.cyan)
                Text("ESCOLHA SUA AÇÃO")
                    .foregroundStyle(.white)
                Spacer()
            }
            .font(.system(size: 12, weight: .black))
            .tracking(1)

            HStack(spacing: 9) {
                ForEach(BattleMove.allCases) { move in
                    let accent = color(for: move)
                    Button {
                        onMove(move)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: move.systemImage)
                                .font(.system(size: 25, weight: .semibold))
                                .frame(height: 30)
                                .shadow(color: accent.opacity(0.6), radius: 8)
                            Text(LocalizedStringKey(move.displayName))
                                .font(.system(size: 11, weight: .black))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(enabled ? accent : Color.white.opacity(0.45))
                        .frame(maxWidth: .infinity)
                        .frame(height: 88)
                        .background(
                            accent.opacity(enabled ? 0.12 : 0.04),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    accent.opacity(enabled ? 0.64 : 0.16),
                                    lineWidth: 1.3
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled)
                }
            }

            Text("Impacto vence Técnica • Técnica vence Guarda • Guarda vence Impacto")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.56))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(15)
        .background(
            MultiplayerBattleTheme.ink.opacity(0.92),
            in: RoundedRectangle(cornerRadius: 23)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 23)
                .stroke(MultiplayerBattleTheme.violet.opacity(0.45), lineWidth: 1)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 24)
    }
}

private struct SelectedMovePanel: View {
    let move: BattleMove
    let secondsRemaining: Int

    private var accent: Color { MultiplayerBattleTheme.cyan }

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
                    .foregroundStyle(MultiplayerBattleTheme.violet)
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
            MultiplayerBattleTheme.ink.opacity(0.94),
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

private struct RoundResultPanel: View {
    let localMove: BattleMove?
    let remoteMove: BattleMove?

    var body: some View {
        HStack(spacing: 12) {
            moveCard(title: "VOCÊ", move: localMove, accent: MultiplayerBattleTheme.cyan)

            Text("VS")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.50))

            moveCard(title: "ADVERSÁRIO", move: remoteMove, accent: MultiplayerBattleTheme.violet)
        }
        .padding(15)
        .background(
            MultiplayerBattleTheme.ink.opacity(0.94),
            in: RoundedRectangle(cornerRadius: 23)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 23)
                .stroke(MultiplayerBattleTheme.violet.opacity(0.52), lineWidth: 1)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 24)
    }

    private func moveCard(
        title: String,
        move: BattleMove?,
        accent: Color
    ) -> some View {
        VStack(spacing: 7) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 10, weight: .black))
                .tracking(0.8)
                .foregroundStyle(accent)

            Image(systemName: move?.systemImage ?? "questionmark")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.45), radius: 8)

            Text(LocalizedStringKey(move?.displayName ?? "—"))
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            accent.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(accent.opacity(0.38), lineWidth: 1)
        }
    }
}

private struct MultiplayerBattleResultPanel: View {
    let victory: Bool
    let localName: String
    let remoteName: String
    let onExit: () -> Void

    private var accent: Color {
        victory ? MultiplayerBattleTheme.cyan : MultiplayerBattleTheme.violet
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: victory ? "trophy.fill" : "shield.slash.fill")
                .font(.system(size: 39, weight: .semibold))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.70), radius: 16)
                .padding(.top, 5)

            Text(LocalizedStringKey(victory ? "VITÓRIA" : "DERROTA"))
                .font(.system(size: 27, weight: .black, design: .rounded))
                .tracking(2)
                .foregroundStyle(.white)

            Text(DeckSpawnL10n.format(
                "%@ venceu %@.",
                victory ? localName : remoteName,
                victory ? remoteName : localName
            ))
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.78))
            .multilineTextAlignment(.center)

            Button(action: onExit) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                    Text("VOLTAR À SALA")
                }
                .font(.system(size: 13, weight: .black))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundStyle(MultiplayerBattleTheme.ink)
                .background(
                    LinearGradient(
                        colors: [MultiplayerBattleTheme.cyan, MultiplayerBattleTheme.violet],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 15)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(21)
        .background(
            MultiplayerBattleTheme.ink.opacity(0.95),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(accent.opacity(0.65), lineWidth: 1.3)
        }
        .shadow(color: accent.opacity(0.17), radius: 22)
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
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
