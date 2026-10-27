import SwiftUI

struct SinglePlayerView: View {

    @ObservedObject

    var arState: GameARState

    @ObservedObject

    var gameFlow: GameFlowState

    let onExit: () -> Void

    @State

    private var showingSettings = false

    @State private var showingExitConfirmation = false

    @State private var showingEnemyPreparationError = false
    @State private var enemyPreparationErrorMessage = ""

    var body: some View {

        GeometryReader { geometry in

            ZStack {

                ARViewContainer(

                    state: arState

                )

                .ignoresSafeArea()

                mainOverlay(

                    screenSize:

                        geometry.size

                )

                topControls

            }

        }

        .onAppear {

            connectBattleAnimations()

        }

        .onDisappear {

            gameFlow.onBattleTurnResolved = nil

        }

        .onChange(

            of: arState.phase

        ) {

            _,

            newPhase in

            if newPhase == .battleReady,

               gameFlow.singlePlayerPhase

                    == .summoningEnemy {

                gameFlow.enemySummonDidFinish()

            }

        }

        .onChange(of: arState.battlePreparationFailureEvent) { _, event in
            guard let event,
                  gameFlow.singlePlayerPhase == .summoningEnemy else { return }

            gameFlow.enemySummonDidFail()
            switch event.failure {
            case .enemyModelUnavailable:
                enemyPreparationErrorMessage = DeckSpawnL10n.text(
                    "Não foi possível carregar o adversário. Toque em Pronto para tentar novamente ou em Trocar Personagem."
                )
            case .arenaUnavailable:
                enemyPreparationErrorMessage = DeckSpawnL10n.text(
                    "A arena foi perdida. Escaneie sua carta novamente."
                )
            }
            showingEnemyPreparationError = true
        }
        .alert(
            DeckSpawnL10n.text("Falha ao preparar adversário"),
            isPresented: $showingEnemyPreparationError
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(enemyPreparationErrorMessage)
        }
        .sheet(

            isPresented:

                $showingSettings

        ) {

            SettingsView(

                state: arState

            )

            .presentationDetents(

                [.medium]

            )

            .presentationDragIndicator(

                .visible

            )

        }

    }

    @ViewBuilder

    private func mainOverlay(

        screenSize: CGSize

    ) -> some View {

        switch arState.phase {

        case .active:

            if gameFlow.singlePlayerPhase == .choosingCard {

                SelectedCharacterControls(

                    state: arState,

                    onReady: confirmPlayerCard

                )

            }

        case .removing:

            RemovingOverlay()

        case .enemySummoning:

            EnemySummoningOverlay(

                enemy:

                    gameFlow.enemyCard

            )

        case .battleReady:

            ZStack {
                BattleHUDOverlay(
                    gameFlow: gameFlow,
                    onExit: onExit
                )

                if gameFlow.isShowingVersus,
                   let player = gameFlow.playerCard,
                   let opponent = gameFlow.enemyCard {
                    BattleVersusOverlay(player: player, opponent: opponent)
                        .transition(.opacity)
                        .zIndex(2)
                }
            }

        
        default:
            DeckSpawnScannerOverlay(
                state: arState,
                screenSize: screenSize,
                mode: .singlePlayer
            )

        }

    }

    // A partida só exige confirmação após o jogador confirmar sua carta.
    // Terminada a batalha, o retorno ao menu continua direto.
    private var isBattleInProgress: Bool {
        switch gameFlow.singlePlayerPhase {
        case .choosingCard:
            return false
        case .summoningEnemy:
            return true
        case .battleReady:
            return gameFlow.battleState?.winner == nil
        }
    }

    private func requestExit() {
        if isBattleInProgress {
            showingExitConfirmation = true
        } else {
            onExit()
        }
    }

    private var topControls: some View {

        VStack {

            HStack {

                Button(action: requestExit) {
                    HStack(spacing: 7) {
                        Image(systemName: isBattleInProgress
                            ? "rectangle.portrait.and.arrow.right"
                            : "chevron.left"
                        )
                        .font(.system(size: 18, weight: .bold))

                        if isBattleInProgress {
                            Text("SAIR")
                                .font(.system(size: 12, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(height: 44)
                    .padding(.horizontal, isBattleInProgress ? 14 : 0)
                    .frame(minWidth: 44)
                    .background(Color.black.opacity(0.62), in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                isBattleInProgress
                                    ? Color.red.opacity(0.65)
                                    : Color.white.opacity(0.14),
                                lineWidth: 1
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    isBattleInProgress ? Text("Sair da batalha") : Text("Voltar ao menu")
                )
                .alert("Sair da batalha?", isPresented: $showingExitConfirmation) {
                    Button("Continuar jogando", role: .cancel) { }
                    Button("Sair da batalha", role: .destructive) {
                        onExit()
                    }
                } message: {
                    Text("A batalha será encerrada e você voltará ao menu principal.")
                }

                Spacer()

                Button {

                    showingSettings = true

                } label: {

                    Image(

                        systemName:

                            "gearshape.fill"

                    )

                    .font(

                        .system(

                            size: 19

                        )

                    )

                    .foregroundStyle(

                        .white

                    )

                    .frame(

                        width: 44,

                        height: 44

                    )

                    .background(

                        Color.black.opacity(

                            0.62

                        )

                    )

                    .clipShape(

                        Circle()

                    )

                }

                .accessibilityLabel(

                    "Configurações"

                )

            }

            Spacer()

        }

        .padding(

            .top,

            8

        )

        .padding(

            .horizontal,

            16

        )

    }

    private func connectBattleAnimations() {

        gameFlow.onBattleTurnResolved = {

            playerMove,

            enemyMove,

            result,

            winner in

            arState.animateBattleTurn(

                playerMove: playerMove,

                enemyMove: enemyMove,

                result: result,

                winner: winner

            )

        }

    }

    private func confirmPlayerCard() {

        guard

            let playerCard =

                arState.activeCard,

            let enemy =

                gameFlow.confirmPlayerCard(

                    playerCard

                )

        else {

            return

        }

        arState.prepareBattle(

            against: enemy

        )

    }

}

private struct SelectedCharacterControls: View {

    @ObservedObject

    var state: GameARState

    let onReady: () -> Void

    var body: some View {

        VStack {

            Spacer()

            VStack(

                spacing: 12

            ) {

                if let card =

                    state.activeCard {

                    VStack(

                        spacing: 3

                    ) {

                        Text(

                            "PERSONAGEM SELECIONADO"

                        )

                        .font(

                            .caption2

                        )

                        .fontWeight(

                            .bold

                        )

                        .foregroundStyle(

                            .white.opacity(

                                0.65

                            )

                        )

                        Text(

                            card.displayName

                        )

                        .font(

                            .headline

                        )

                        .foregroundStyle(

                            .white

                        )

                    }

                }

                Button(

                    action: onReady

                ) {

                    Label(

                        "PRONTO",

                        systemImage:

                            "checkmark.circle.fill"

                    )

                    .font(

                        .headline

                    )

                    .fontWeight(

                        .bold

                    )

                    .foregroundStyle(

                        .black

                    )

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

                    state.removeCharacter()

                } label: {

                    Label(

                        "TROCAR CARTA",

                        systemImage:

                            "arrow.triangle.2.circlepath"

                    )

                    .font(

                        .subheadline

                    )

                    .fontWeight(

                        .semibold

                    )

                    .foregroundStyle(

                        .white

                    )

                    .frame(

                        maxWidth: .infinity

                    )

                    .padding(

                        .vertical,

                        13

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

                }

            }

            .padding(

                16

            )

            .background(

                Color.black.opacity(

                    0.58

                )

            )

            .clipShape(

                RoundedRectangle(

                    cornerRadius: 22

                )

            )

            .padding(

                .horizontal,

                22

            )

            .padding(

                .bottom,

                28

            )

        }

    }

}

private struct EnemySummoningOverlay: View {

    let enemy: CardDefinition?

    var body: some View {

        VStack {

            Spacer()

            HStack(

                spacing: 10

            ) {

                ProgressView()

                    .tint(

                        .white

                    )

                VStack(

                    alignment: .leading,

                    spacing: 2

                ) {

                    Text(

                        "ADVERSÁRIO ENCONTRADO"

                    )

                    .font(

                        .caption2

                    )

                    .fontWeight(

                        .bold

                    )

                    .foregroundStyle(

                        .white.opacity(

                            0.65

                        )

                    )

                    Text(

                        enemy?.displayName

                        ?? "CPU"

                    )

                    .font(

                        .headline

                    )

                    .foregroundStyle(

                        .white

                    )

                }

            }

            .padding(

                .horizontal,

                18

            )

            .padding(

                .vertical,

                13

            )

            .background(

                Color.black.opacity(

                    0.70

                )

            )

            .clipShape(

                Capsule()

            )

            .padding(

                .bottom,

                38

            )

        }

        .allowsHitTesting(

            false

        )

    }

}

// MARK: - DeckSpawn Battle HUD V2

private enum BattleTheme {
    static let cyan = Color(red: 0.16, green: 0.91, blue: 1.0)
    static let violet = Color(red: 0.64, green: 0.39, blue: 1.0)
    static let ink = Color(red: 0.035, green: 0.055, blue: 0.14)
    static let panel = Color(red: 0.045, green: 0.075, blue: 0.19)
}

private struct BattleHUDOverlay: View {
    @ObservedObject var gameFlow: GameFlowState
    let onExit: () -> Void

    var body: some View {
        ZStack {
            if let battle = gameFlow.battleState {
                VStack(spacing: 11) {
                    HStack(spacing: 9) {
                        FighterHPCard(
                            title: "VOCÊ",
                            card: battle.playerCard,
                            currentHP: battle.playerHP,
                            maxHP: battle.playerCard.maxHP,
                            progress: battle.playerHPProgress,
                            isTrailing: false
                        )
                        FighterHPCard(
                            title: "CPU",
                            card: battle.enemyCard,
                            currentHP: battle.enemyHP,
                            maxHP: battle.enemyCard.maxHP,
                            progress: battle.enemyHPProgress,
                            isTrailing: true
                        )
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 68)

                    roundBanner(round: battle.round, finished: battle.winner != nil)
                        .padding(.horizontal, 20)

                    Spacer(minLength: 12)

                    if let winner = battle.winner {
                        BattleResultPanel(
                            winner: winner,
                            playerName: battle.playerCard.displayName,
                            enemyName: battle.enemyCard.displayName,
                            onExit: onExit
                        )
                    } else {
                        BattleActionPanel(
                            isDisabled: gameFlow.isResolvingTurn || !gameFlow.isBattleStarted,
                            onMove: { move in
                                gameFlow.playTurn(playerMove: move)
                            }
                        )
                    }
                }
            }

            if let countdown = gameFlow.battleCountdown {
                countdownPanel(countdown)
                    .transition(.scale(scale: 0.88).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: gameFlow.battleCountdown == nil)
    }

    private func roundBanner(round: Int, finished: Bool) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.horizontal.fill")
                        .foregroundStyle(BattleTheme.cyan)
                    Text("RODADA \(round)")
                        .foregroundStyle(.white)
                }
                .font(.system(size: 11, weight: .black, design: .rounded))

                if let message = gameFlow.lastTurnMessage {
                    // The battle engine has already localized this dynamic message.
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

            if gameFlow.isResolvingTurn {
                ProgressView()
                    .tint(BattleTheme.cyan)
                    .frame(width: 44, height: 44)
            } else if gameFlow.isBattleStarted && !finished {
                turnClock
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(BattleTheme.panel.opacity(0.90), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(BattleTheme.cyan.opacity(0.29), lineWidth: 1)
        }
    }

    private var turnClock: some View {
        let duration = max(1, BattleRules.turnDurationSeconds)
        let ratio = min(max(Double(gameFlow.turnSecondsRemaining) / Double(duration), 0), 1)
        let color = gameFlow.turnSecondsRemaining <= 5 ? Color.red :
                    gameFlow.turnSecondsRemaining <= 10 ? Color.orange : BattleTheme.cyan

        return ZStack {
            Circle().stroke(Color.white.opacity(0.11), lineWidth: 4)
            Circle()
                .trim(from: 0, to: ratio)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.3), value: gameFlow.turnSecondsRemaining)
            Text("\(gameFlow.turnSecondsRemaining)")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(width: 45, height: 45)
        .accessibilityLabel("\(gameFlow.turnSecondsRemaining)s")
    }

    private func countdownPanel(_ seconds: Int) -> some View {
        VStack(spacing: 12) {
            Text("PREPARE-SE")
                .font(.system(size: 13, weight: .black))
                .tracking(2)
                .foregroundStyle(BattleTheme.cyan)
            ZStack {
                Circle()
                    .stroke(BattleTheme.violet.opacity(0.30), lineWidth: 3)
                BattleCountdownProgressRing()
                Text("\(seconds)")
                    .font(.system(size: 76, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .id(seconds)
                    .transition(.opacity.combined(with: .scale))
            }
            .frame(width: 152, height: 152)
            .shadow(color: BattleTheme.cyan.opacity(0.40), radius: 18)
        }
        .padding(29)
        .background(BattleTheme.ink.opacity(0.94), in: RoundedRectangle(cornerRadius: 30))
        .overlay {
            RoundedRectangle(cornerRadius: 30)
                .stroke(
                    LinearGradient(colors: [BattleTheme.cyan, BattleTheme.violet], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.5
                )
        }
        .shadow(color: .black.opacity(0.45), radius: 25)
    }
}


// Barra circular independente dos números: avança continuamente pelos 3 segundos
// sem reiniciar sua animação quando o texto muda de 3 para 2 e depois para 1.
private struct BattleCountdownProgressRing: View {
    @State private var progress: CGFloat = 1.0

    var body: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(
                AngularGradient(
                    colors: [BattleTheme.cyan, BattleTheme.violet, BattleTheme.cyan],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: 5, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .onAppear {
                // O anel comeca cheio e esvazia ate a batalha iniciar.
                // O @State pertence ao anel (nao ao texto, que usa .id(seconds)).
                progress = 1.0
                withAnimation(.linear(duration: Double(BattleRules.startCountdownSeconds))) {
                    progress = 0.0
                }
            }
    }
}

private struct FighterHPCard: View {
    let title: String
    let card: CardDefinition
    let currentHP: Int
    let maxHP: Int
    let progress: Double
    let isTrailing: Bool

    private var accent: Color { isTrailing ? BattleTheme.violet : BattleTheme.cyan }
    private var healthColor: Color {
        progress <= 0.25 ? .red : (progress <= 0.50 ? .orange : accent)
    }

    var body: some View {
        VStack(alignment: isTrailing ? .trailing : .leading, spacing: 7) {
            HStack(spacing: 5) {
                if !isTrailing { Circle().fill(accent).frame(width: 6, height: 6) }
                Text(LocalizedStringKey(title))
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.3)
                if isTrailing { Circle().fill(accent).frame(width: 6, height: 6) }
            }
            .foregroundStyle(accent)

            Text(LocalizedStringKey(card.displayName))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            GeometryReader { geo in
                ZStack(alignment: isTrailing ? .trailing : .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(LinearGradient(colors: [healthColor.opacity(0.65), healthColor], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * min(max(progress, 0), 1))
                        .animation(.easeOut(duration: 0.45), value: progress)
                }
            }
            .frame(height: 7)

            Text("\(currentHP) / \(maxHP) HP")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.80))
        }
        .frame(maxWidth: .infinity, alignment: isTrailing ? .trailing : .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(BattleTheme.panel.opacity(0.91), in: RoundedRectangle(cornerRadius: 17))
        .overlay {
            RoundedRectangle(cornerRadius: 17)
                .stroke(accent.opacity(0.46), lineWidth: 1)
        }
        .shadow(color: accent.opacity(0.10), radius: 9)
    }
}

private struct BattleActionPanel: View {
    let isDisabled: Bool
    let onMove: (BattleMove) -> Void

    private func color(for move: BattleMove) -> Color {
        switch move {
        case .impact: return BattleTheme.cyan
        case .technique: return BattleTheme.violet
        case .defense: return Color(red: 0.28, green: 0.85, blue: 0.75)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "gamecontroller.fill")
                    .foregroundStyle(BattleTheme.cyan)
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
                        .foregroundStyle(isDisabled ? Color.white.opacity(0.45) : accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 88)
                        .background(accent.opacity(isDisabled ? 0.04 : 0.12), in: RoundedRectangle(cornerRadius: 16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(accent.opacity(isDisabled ? 0.16 : 0.64), lineWidth: 1.3)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled)
                    .accessibilityAddTraits(.isButton)
                }
            }

            Text("Impacto vence Técnica • Técnica vence Guarda • Guarda vence Impacto")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.56))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(15)
        .background(BattleTheme.ink.opacity(0.92), in: RoundedRectangle(cornerRadius: 23))
        .overlay {
            RoundedRectangle(cornerRadius: 23)
                .stroke(BattleTheme.violet.opacity(0.45), lineWidth: 1)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 24)
    }
}

private struct BattleResultPanel: View {
    let winner: BattleWinner
    let playerName: String
    let enemyName: String
    let onExit: () -> Void

    private var victory: Bool { winner == .player }
    private var accent: Color { victory ? BattleTheme.cyan : BattleTheme.violet }

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
                victory ? playerName : enemyName,
                victory ? enemyName : playerName
            ))
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.78))
            .multilineTextAlignment(.center)

            Button(action: onExit) {
                HStack(spacing: 8) {
                    Image(systemName: "house.fill")
                    Text("VOLTAR AO MENU")
                }
                .font(.system(size: 13, weight: .black))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundStyle(BattleTheme.ink)
                .background(
                    LinearGradient(colors: [BattleTheme.cyan, BattleTheme.violet], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 15)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(21)
        .background(BattleTheme.ink.opacity(0.95), in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(accent.opacity(0.65), lineWidth: 1.3)
        }
        .shadow(color: accent.opacity(0.17), radius: 22)
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
    }
}

private struct RemovingOverlay: View {

    var body: some View {

        VStack {

            Spacer()

            HStack(

                spacing: 10

            ) {

                ProgressView()

                    .tint(.white)

                Text(

                    "REMOVENDO PERSONAGEM..."

                )

                .font(.caption)

                .fontWeight(.bold)

            }

            .foregroundStyle(.white)

            .padding(

                .horizontal,

                18

            )

            .padding(

                .vertical,

                12

            )

            .background(

                Color.black.opacity(

                    0.68

                )

            )

            .clipShape(

                Capsule()

            )

            .padding(

                .bottom,

                40

            )

        }

        .allowsHitTesting(

            false

        )

    }

}

private struct CardScannerOverlay: View {

    @ObservedObject

    var state: GameARState

    let screenSize: CGSize

    var body: some View {

        let guideRect =

            ScanLayout.guideRect(

                in: screenSize

            )

        ZStack {

            scannerBox

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

            Text(LocalizedStringKey(instructionText))

            .font(.callout)

            .foregroundStyle(.white)

            .multilineTextAlignment(

                .center

            )

            .frame(

                width: 310

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

        .animation(

            .easeInOut(

                duration: 0.25

            ),

            value: state.phase

        )

        .allowsHitTesting(

            false

        )

    }

    private var scannerBox: some View {

        ZStack {

            RoundedRectangle(

                cornerRadius: 22

            )

            .stroke(

                statusColor,

                style:

                    StrokeStyle(

                        lineWidth: 3,

                        dash:

                            usesSolidBorder

                            ? []

                            : [10, 8]

                    )

            )

            if state.phase == .holding {

                RoundedRectangle(

                    cornerRadius: 22

                )

                .trim(

                    from: 0,

                    to:

                        max(

                            0.01,

                            state.holdProgress

                        )

                )

                .stroke(

                    Color.yellow,

                    style:

                        StrokeStyle(

                            lineWidth: 6,

                            lineCap: .round

                        )

                )

                .rotationEffect(

                    .degrees(-90)

                )

            }

            if state.phase == .scanning {

                ScannerBeam()

                    .clipShape(

                        RoundedRectangle(

                            cornerRadius: 22

                        )

                    )

            }

            VStack(

                spacing: 12

            ) {

                statusIcon

                Text(LocalizedStringKey(statusTitle))

                .font(.caption)

                .fontWeight(.bold)

                .multilineTextAlignment(

                    .center

                )

                if state.phase == .scanning {

                    ProgressView(

                        value:

                            state.scanProgress

                    )

                    .tint(.cyan)

                    .frame(

                        width: 125

                    )

                    Text(

                        String(

                            format: "%.1f s",

                            state.scanSecondsRemaining

                        )

                    )

                    .font(

                        .caption2

                    )

                    .monospacedDigit()

                }

                if

                    let cardName =

                        state.recognizedCardName,

                    shouldShowCardName

                {

                    Text(cardName)

                        .font(

                            .caption2

                        )

                        .opacity(

                            0.8

                        )

                }

            }

            .foregroundStyle(

                statusColor

            )

            .padding()

        }

    }

    @ViewBuilder

    private var statusIcon: some View {

        switch state.phase {

        case .searching:

            Image(systemName: "viewfinder")

                .font(.system(size: 32))

        case .aligning:

            Image(

                systemName:

                    "arrow.up.and.down.and.arrow.left.and.right"

            )

            .font(.system(size: 29))

        case .holding:

            Image(systemName: "hand.raised.fill")

                .font(.system(size: 29))

        case .scanning:

            Image(systemName: "wave.3.right")

                .font(.system(size: 31))

        case .confirmed:

            Image(systemName: "checkmark.circle.fill")

                .font(.system(size: 34))

        case .summoning:

            Image(systemName: "sparkles")

                .font(.system(size: 32))

        case .lost:

            Image(systemName: "exclamationmark.triangle.fill")

                .font(.system(size: 31))

        case .failed:

            Image(systemName: "xmark.circle.fill")

                .font(.system(size: 34))

        case .waitingForCardRemoval:

            Image(

                systemName:

                    "rectangle.portrait.and.arrow.forward"

            )

            .font(.system(size: 31))

        case .active,

             .removing,

             .enemySummoning,

             .battleReady:

            EmptyView()

        }

    }

    private var statusTitle: String {

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

        case .waitingForCardRemoval:

            return "RETIRE A CARTA"

        case .active,

             .removing,

             .enemySummoning,

             .battleReady:

            return ""

        }

    }

    private var instructionText: String {

        switch state.phase {

        case .searching:

            return "Mostre uma carta cadastrada dentro do campo"

        case .aligning:

            return "Centralize a carta no campo de leitura"

        case .holding:

            return "Mantenha a carta imóvel por um instante"

        case .scanning:

            return "Não retire a carta até concluir a leitura"

        case .confirmed:

            return "Leitura concluída"

        case .summoning:

            return "Preparando invocação..."

        case .lost:

            return "Reposicione a carta dentro do campo"

        case .failed:

            return "Nenhuma carta cadastrada foi encontrada"

        case .waitingForCardRemoval:

            return "Retire a carta da câmera para iniciar uma nova leitura"

        case .active,

             .removing,

             .enemySummoning,

             .battleReady:

            return ""

        }

    }

    private var statusColor: Color {

        switch state.phase {

        case .searching:

            return .white

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

        case .lost:

            return .orange

        case .failed:

            return .red

        case .waitingForCardRemoval:

            return .orange

        case .active,

             .removing,

             .enemySummoning,

             .battleReady:

            return .clear

        }

    }

    private var usesSolidBorder: Bool {

        switch state.phase {

        case .scanning,

             .confirmed,

             .summoning,

             .failed,

             .waitingForCardRemoval:

            return true

        default:

            return false

        }

    }

    private var shouldShowCardName: Bool {

        switch state.phase {

        case .aligning,

             .holding,

             .scanning,

             .confirmed:

            return true

        default:

            return false

        }

    }

}

private struct ScannerBeam: View {

    @State

    private var movingDown = false

    var body: some View {

        GeometryReader { geometry in

            Rectangle()

                .fill(

                    LinearGradient(

                        colors: [

                            .clear,

                            .cyan,

                            .white,

                            .cyan,

                            .clear

                        ],

                        startPoint:

                            .leading,

                        endPoint:

                            .trailing

                    )

                )

                .frame(

                    height: 4

                )

                .shadow(

                    color: .cyan,

                    radius: 12

                )

                .offset(

                    y:

                        movingDown

                        ? geometry.size.height - 4

                        : 0

                )

                .onAppear {

                    movingDown = true

                }

                .animation(

                    .linear(

                        duration: 0.65

                    )

                    .repeatForever(

                        autoreverses: true

                    ),

                    value:

                        movingDown

                )

        }

    }

}
