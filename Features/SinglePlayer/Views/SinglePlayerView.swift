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
    @State private var showingRematchUnavailable = false

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

                // Projected from the RealityKit fighter, above the AR scene
                // and HUD. No interaction or tap interception.
                FloatingDamageOverlay(event: arState.floatingDamageEvent)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                topControls

            }

        }

        .onAppear {

            connectBattleAnimations()
            syncStageRibbon()

        }

        .onDisappear {

            gameFlow.onBattleTurnResolved = nil
            arState.setStageRibbonCue(.ambient)

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
            syncStageRibbon()

        }

        .onChange(of: gameFlow.isShowingVersus) { _, _ in
            syncStageRibbon()
        }
        .onChange(of: gameFlow.battleCountdown) { _, value in
            // The countdown ends immediately before isBattleStarted becomes true.
            // Ignore this intermediate nil to keep 1 -> FIGHT continuous.
            if value != nil { syncStageRibbon() }
        }
        .onChange(of: gameFlow.isBattleStarted) { _, _ in
            syncStageRibbon()
        }
        .onChange(of: gameFlow.isResolvingTurn) { _, _ in
            syncStageRibbon()
        }
        .onChange(of: gameFlow.battleState?.winner != nil) { _, _ in
            syncStageRibbon()
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

    // The battle clock belongs to GameFlowState; the stage simply displays it.
    private func syncStageRibbon() {
        guard gameFlow.screen == .singlePlayer,
              gameFlow.singlePlayerPhase == .battleReady,
              arState.phase == .battleReady else {
            arState.setStageRibbonCue(.ambient)
            return
        }
        if gameFlow.battleState?.winner != nil {
            arState.setStageRibbonCue(.result)
        } else if gameFlow.isShowingVersus {
            arState.setStageRibbonCue(.versus)
        } else if let number = gameFlow.battleCountdown {
            arState.setStageRibbonCue(.countdown(number))
        } else if gameFlow.isBattleStarted {
            arState.setStageRibbonCue(gameFlow.isResolvingTurn ? .action : .battle)
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
                    onExit: onExit,
                    onRematch: beginRematch
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
        .alert("Realidade aumentada indisponível", isPresented: $showingRematchUnavailable) {
            Button("Tentar novamente", role: .cancel) { }
            Button("Voltar ao menu") { onExit() }
        } message: {
            Text("A câmera perdeu o rastreamento ou a arena não está disponível. Aponte para a área da batalha e tente novamente, ou volte ao menu para escanear a carta.")
        }

    }

    private func connectBattleAnimations() {

        gameFlow.onBattleTurnResolved = {

            playerMove,

            enemyMove,

            result,

            winner,

            damage,

            animationsFinished in

            arState.animateBattleTurn(

                playerMove: playerMove,

                enemyMove: enemyMove,

                result: result,

                winner: winner,

                damage: damage,

                animationsCompleted: animationsFinished

            )

        }

    }

    private func beginRematch() {
        guard gameFlow.battleState?.winner != nil else { return }
        guard arState.prepareRematch() else {
            // Let the player retry once tracking recovers, or return to menu.
            showingRematchUnavailable = true
            return
        }
        _ = gameFlow.restartBattleWithSameCharacters()
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

private struct BattleHUDOverlay: View {
    @ObservedObject var gameFlow: GameFlowState
    let onExit: () -> Void
    let onRematch: () -> Void

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

                    BattleRoundBanner(
                        round: battle.round,
                        message: gameFlow.battleCountdown == nil ? gameFlow.lastTurnMessage : nil,
                        isResolving: gameFlow.isResolvingTurn,
                        showsClock: gameFlow.isBattleStarted && battle.winner == nil,
                        secondsRemaining: gameFlow.turnSecondsRemaining
                    )
                        .padding(.horizontal, 20)

                    Spacer(minLength: 12)

                    if let winner = battle.winner {
                        BattleResultPanel(
                            winner: winner,
                            playerName: battle.playerCard.displayName,
                            enemyName: battle.enemyCard.displayName,
                            rounds: battle.round,
                            remainingHP: battle.playerHP,
                            onExit: onExit,
                            onRematch: onRematch
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

        }
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
