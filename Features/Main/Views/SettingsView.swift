import SwiftUI

struct SettingsView: View {

    @ObservedObject var state: GameARState

    @Environment(\.dismiss)
    private var dismiss

    // O valor escolhido fica salvo entre as execuções do aplicativo.
    // "system" usa o idioma preferido do iPhone; as outras opções forçam um idioma.
    // Esta mesma chave será lida na view principal para aplicar a localização global.
    @AppStorage("deckspawn.language")
    private var selectedLanguage = "system"

    var body: some View {
        NavigationStack {
            Form {
                Section("Idioma") {
                    Picker("Idioma do jogo", selection: $selectedLanguage) {
                        Text("Automático (Sistema)").tag("system")
                        Text("Português (Brasil)").tag("pt-BR")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.menu)
                }

                Section("Áudio e feedback") {
                    Toggle(isOn: $state.soundEnabled) {
                        Label(
                            "Som",
                            systemImage: state.soundEnabled
                                ? "speaker.wave.2.fill"
                                : "speaker.slash.fill"
                        )
                    }

                    Toggle(isOn: $state.hapticsEnabled) {
                        Label(
                            "Vibração",
                            systemImage: state.hapticsEnabled
                                ? "iphone.radiowaves.left.and.right"
                                : "iphone"
                        )
                    }
                }

                Section {
                    Text("Essas preferências ficam salvas para as próximas vezes que o app for aberto.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Configurações")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        dismiss()
                    }
                }
            }
        }
    }
}
