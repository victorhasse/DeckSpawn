import SwiftUI

/// Mirrors the multiplayer lobby's dark gradient, back button and rounded cards.
struct SinglePlayerDifficultyView: View {
    let selectedDifficulty: AIDifficulty
    let onBack: () -> Void
    let onContinue: (AIDifficulty) -> Void

    @State private var selection: AIDifficulty = .normal

    private let cyan = Color(red: 0.20, green: 0.84, blue: 1.00)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color.indigo.opacity(0.72), Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        header
                        Spacer(minLength: 28)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("ESCOLHA A DIFICULDADE")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .tracking(2)
                                .foregroundStyle(.white.opacity(0.65))
                                .padding(.horizontal, 4)

                            difficultyCard(
                                .easy,
                                title: "FÁCIL",
                                subtitle: "Uma CPU mais previsível para aprender a jogar.",
                                icon: "leaf.fill"
                            )
                            difficultyCard(
                                .normal,
                                title: "NORMAL",
                                subtitle: "Escolhas aleatórias, como no jogo original.",
                                icon: "shield.fill"
                            )
                            difficultyCard(
                                .hard,
                                title: "DIFÍCIL",
                                subtitle: "A CPU observa seus movimentos anteriores.",
                                icon: "brain.head.profile"
                            )
                        }

                        Button {
                            onContinue(selection)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "camera.viewfinder")
                                Text("CONTINUAR PARA O SCANNER")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                Image(systemName: "chevron.right")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .foregroundStyle(.black)
                            .background(cyan, in: RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("singleplayer.startScanner")
                        Spacer(minLength: 28)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height)
                }
            }
        }
        .onAppear { selection = selectedDifficulty }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.10), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Voltar ao menu")

            VStack(alignment: .leading, spacing: 2) {
                Text("SINGLEPLAYER")
                    .font(.headline)
                    .fontWeight(.black)
                    .foregroundStyle(.white)
                Text("Configure a dificuldade da CPU")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    private func difficultyCard(
        _ difficulty: AIDifficulty,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        icon: String
    ) -> some View {
        let isSelected = selection == difficulty
        return Button {
            selection = difficulty
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? cyan : .white.opacity(0.85))
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.bold)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.60))
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? cyan : .white.opacity(0.35))
            }
            .foregroundStyle(.white)
            .padding(18)
            .background(
                isSelected ? cyan.opacity(0.12) : Color.white.opacity(0.10),
                in: RoundedRectangle(cornerRadius: 18)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(isSelected ? cyan.opacity(0.85) : .clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("singleplayer.difficulty.\(difficulty.rawValue)")
    }
}
