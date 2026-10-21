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
                    arState.resetForNewSession()
                    gameFlow.startSinglePlayer()
                },
                onMultiplayer: {
                    arState.resetForNewSession()
                    multiplayerService.stopAll()
                    gameFlow.startMultiplayer()
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
