import SwiftUI

/// Tela de ajuda do DeckSpawn. Não inicia nem altera uma sessão de AR.
/// Respeita o idioma aplicado por DeckSpawnLocalizedRoot (pt-BR / en / sistema).
struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    private let cyan = Color(red: 0.20, green: 0.84, blue: 1.00)
    private let violet = Color(red: 0.56, green: 0.39, blue: 1.00)
    private let navy = Color(red: 0.015, green: 0.025, blue: 0.075)

    private var isPortuguese: Bool {
        locale.identifier.lowercased().hasPrefix("pt")
    }

    private func tr(_ portuguese: String, _ english: String) -> String {
        isPortuguese ? portuguese : english
    }

    var body: some View {
        NavigationStack {
            ZStack {
                navy.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        introduction

                        helpCard(
                            title: tr("PREPARE SUA CARTA", "PREPARE YOUR CARD"),
                            icon: "camera.viewfinder",
                            accent: cyan
                        ) {
                            step(1, tr(
                                "Escolha Singleplayer ou Multiplayer no menu principal.",
                                "Choose Singleplayer or Multiplayer from the main menu."
                            ))
                            step(2, tr(
                                "Aponte a câmera para uma carta física compatível, em um local bem iluminado.",
                                "Point the camera at a supported physical card in a well-lit area."
                            ))
                            step(3, tr(
                                "Aguarde o reconhecimento: o personagem correspondente será invocado em realidade aumentada.",
                                "Wait for recognition: the corresponding character will be summoned in augmented reality."
                            ))
                            step(4, tr(
                                "Toque em Pronto para confirmar ou em Trocar Personagem para escanear outra carta.",
                                "Tap Ready to confirm or Change Character to scan a different card."
                            ))
                        }

                        helpCard(
                            title: tr("SINGLEPLAYER", "SINGLEPLAYER"),
                            icon: "person.fill",
                            accent: cyan
                        ) {
                            bodyText(tr(
                                "Você enfrenta um adversário controlado pelo jogo. Depois de confirmar sua carta, um oponente é escolhido aleatoriamente e a batalha começa após a contagem regressiva.",
                                "You face a game-controlled opponent. After confirming your card, an opponent is selected at random and the battle begins after a countdown."
                            ))
                        }

                        helpCard(
                            title: tr("MULTIPLAYER LOCAL", "LOCAL MULTIPLAYER"),
                            icon: "person.2.fill",
                            accent: violet
                        ) {
                            step(1, tr(
                                "Abra o DeckSpawn em dois iPhones próximos, ambos com o jogo instalado.",
                                "Open DeckSpawn on two nearby iPhones, both with the game installed."
                            ))
                            step(2, tr(
                                "Um jogador cria uma sala e o outro entra nela. Autorize o acesso à rede local quando solicitado.",
                                "One player creates a room and the other joins it. Allow local network access when prompted."
                            ))
                            step(3, tr(
                                "Cada jogador escaneia sua carta e confirma o personagem para começar a partida.",
                                "Each player scans a card and confirms their character to start the match."
                            ))
                            note(tr(
                                "Não é necessária conexão com a internet. Os iPhones se comunicam diretamente por uma conexão local de proximidade.",
                                "No internet connection is required. The iPhones communicate directly over a nearby local connection."
                            ), icon: "wifi", tint: violet)
                        }

                        helpCard(
                            title: tr("REGRAS DO COMBATE", "COMBAT RULES"),
                            icon: "bolt.shield.fill",
                            accent: cyan
                        ) {
                            bodyText(tr(
                                "A cada rodada, escolha uma das três ações. Cada ação vence uma e perde para outra:",
                                "Each round, choose one of three moves. Each move beats one option and loses to another:"
                            ))
                            ruleRow(
                                winner: tr("IMPACTO", "IMPACT"),
                                loser: tr("TÉCNICA", "TECHNIQUE"),
                                color: Color.orange
                            )
                            ruleRow(
                                winner: tr("TÉCNICA", "TECHNIQUE"),
                                loser: tr("GUARDA", "GUARD"),
                                color: cyan
                            )
                            ruleRow(
                                winner: tr("GUARDA", "GUARD"),
                                loser: tr("IMPACTO", "IMPACT"),
                                color: violet
                            )
                            bodyText(tr(
                                "Quem escolhe a ação vencedora causa dano ao rival. Se as ações empatarem, ninguém perde HP naquela rodada.",
                                "The winning move deals damage to the opponent. If both moves tie, neither fighter loses HP that round."
                            ))
                            note(tr(
                                "Escolha antes que o tempo acabe. Se o prazo terminar, o jogo seleciona uma ação automaticamente.",
                                "Choose before time runs out. If the timer expires, the game selects a move automatically."
                            ), icon: "clock", tint: cyan)
                        }

                        helpCard(
                            title: tr("COMO VENCER", "HOW TO WIN"),
                            icon: "trophy.fill",
                            accent: Color.orange
                        ) {
                            bodyText(tr(
                                "Observe os pontos de vida (HP) durante a luta. Vença as rodadas para diminuir o HP do adversário. A batalha termina quando um dos personagens é derrotado.",
                                "Watch the health points (HP) during combat. Win rounds to reduce your opponent's HP. The battle ends when a fighter is defeated."
                            ))
                            bodyText(tr(
                                "Ao final, cada jogador vê o resultado correspondente à sua própria partida.",
                                "At the end, each player sees the result from their own perspective."
                            ))
                        }

                        Text(tr(
                            "Dica: se a carta não for reconhecida, melhore a iluminação e mantenha a imagem inteira dentro do enquadramento.",
                            "Tip: if a card is not recognized, improve the lighting and keep the whole card within the camera frame."
                        ))
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.56))
                        .padding(.horizontal, 6)
                        .padding(.bottom, 18)
                    }
                    .frame(maxWidth: 560)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(tr("Como Jogar", "How to Play"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Fechar", "Close")) { dismiss() }
                        .foregroundStyle(cyan)
                }
            }
            .toolbarBackground(navy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(cyan)

                Text(tr("PRONTO PARA BATALHAR?", "READY TO BATTLE?"))
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(tr(
                "Dê vida às suas cartas, escolha um personagem e vença usando a ação certa em cada rodada.",
                "Bring your cards to life, choose a fighter, and win by picking the right move each round."
            ))
            .font(.system(size: 14))
            .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(19)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [cyan.opacity(0.19), violet.opacity(0.13), navy],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(cyan.opacity(0.35), lineWidth: 1)
        )
    }

    private func helpCard<Content: View>(
        title: String,
        icon: String,
        accent: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(accent)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(.white)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.05, green: 0.07, blue: 0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(accent.opacity(0.24), lineWidth: 1)
        )
    }

    private func step(_ number: Int, _ description: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Text("\(number)")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(navy)
                .frame(width: 23, height: 23)
                .background(Circle().fill(cyan))

            bodyText(description)
                .padding(.top, 2)
        }
    }

    private func ruleRow(winner: String, loser: String, color: Color) -> some View {
        HStack(spacing: 9) {
            Text(winner)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(tr("vence", "beats"))
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.56))

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.56))

            Text(loser)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 9).fill(color.opacity(0.09)))
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(.white.opacity(0.78))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func note(_ text: String, icon: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 11).fill(tint.opacity(0.10)))
    }
}
