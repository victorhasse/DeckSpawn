import SwiftUI

struct ContentView: View {

    @StateObject
    private var arState = GameARState()

    @StateObject
    private var gameFlow = GameFlowState()

    @StateObject
    private var multiplayerService =
        MultiplayerService()

    var body: some View {

        switch gameFlow.screen {

        case .mainMenu:

            MainMenuView(
                arState: arState,
                onSinglePlayer: {
                    gameFlow.openSinglePlayerSetup()
                },
                onMultiplayer: {
                    arState.resetForNewSession()
                    multiplayerService.stopAll()
                    gameFlow.startMultiplayer()
                }
            )

        case .singlePlayerSetup:

            SinglePlayerDifficultyView(
                selectedDifficulty: gameFlow.selectedDifficulty,
                onBack: { gameFlow.returnToMainMenu() },
                onContinue: { difficulty in
                    arState.resetForNewSession()
                    gameFlow.startSinglePlayer(difficulty: difficulty)
                }
            )

        case .singlePlayer:

            SinglePlayerView(
                arState: arState,
                gameFlow: gameFlow,
                onExit: {
                    arState.resetForNewSession()
                    gameFlow.returnToMainMenu()
                }
            )

        case .multiplayer:

            MultiplayerView(
                service:
                    multiplayerService,
                arState:
                    arState,
                gameFlow:
                    gameFlow,
                onExit: {
                    arState.resetForNewSession()
                    multiplayerService.stopAll()
                    gameFlow.returnToMainMenu()
                }
            )
        }
    }
}
