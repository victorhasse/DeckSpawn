import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            DeckSpawnLocalizedRoot()
        }
    }
}

// Le a mesma preferencia salva no seletor de idioma da SettingsView.
// Aplicamos o locale a toda a arvore de views, sem modificar o ContentView
// nem recriar as telas do jogo desnecessariamente ao trocar de idioma.
private struct DeckSpawnLocalizedRoot: View {
    @AppStorage("deckspawn.language")
    private var selectedLanguage = "system"

    // Locale recebido do iOS. Usado quando o jogador escolhe Automatico.
    @Environment(\.locale)
    private var systemLocale

    private var activeLocale: Locale {
        switch selectedLanguage {
        case "pt-BR":
            return Locale(identifier: "pt-BR")
        case "en":
            return Locale(identifier: "en")
        default:
            return systemLocale
        }
    }

    var body: some View {
        ContentView()
            .environment(\.locale, activeLocale)
    }
}
