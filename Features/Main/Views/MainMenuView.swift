import SwiftUI

struct MainMenuView: View {

    @ObservedObject var arState: GameARState

    let onSinglePlayer: () -> Void

    let onMultiplayer: () -> Void

    @State private var showingSettings = false

    @State private var showingCollection = false

    private let cyan = Color(red: 0.20, green: 0.84, blue: 1.00)

    private let violet = Color(red: 0.56, green: 0.39, blue: 1.00)

    var body: some View {

        GeometryReader { geometry in

            ZStack {

                DeckSpawnMenuBackground()

                ScrollView(.vertical, showsIndicators: false) {

                    VStack(spacing: 0) {

                        Spacer(minLength: 24)

                        brandHeader

                        Spacer(minLength: 36)

                        gameModes

                        Spacer(minLength: 32)

                    }

                    .padding(.horizontal, 28)

                    .frame(maxWidth: 520)

                    .frame(maxWidth: .infinity)

                    .frame(minHeight: geometry.size.height)

                }

            }

        }

        .fullScreenCover(isPresented: $showingCollection) {

            CharacterCollectionView()

        }

        .sheet(isPresented: $showingSettings) {

            SettingsView(state: arState)

                .presentationDetents([.medium])

                .presentationDragIndicator(.visible)

        }

    }

    private var gameModes: some View {

        VStack(alignment: .leading, spacing: 13) {

            HStack(spacing: 10) {

                Capsule()

                    .fill(cyan)

                    .frame(width: 18, height: 3)

                Text("ESCOLHA UM MODO DE JOGO!")

                    .font(.system(size: 11, weight: .bold, design: .rounded))

                    .tracking(2.4)

                    .foregroundStyle(.white.opacity(0.65))

            }

            .padding(.leading, 4)

            .padding(.bottom, 2)

            menuButton(

                title: "SINGLEPLAYER",

                subtitle: "Invoque suas cartas e jogue contra a IA",

                icon: "person.fill",

                accent: cyan,

                isPrimary: true,

                action: onSinglePlayer

            )

            menuButton(

                title: "MULTIPLAYER",

                subtitle: "Entre na batalha e enfrente seus amigos",

                icon: "person.2.fill",

                accent: violet,

                action: onMultiplayer

            )

            menuButton(

                title: "COLEÇÃO",

                subtitle: "Conheça os personagens disponíveis",

                icon: "square.grid.2x2.fill",

                accent: cyan,

                action: { showingCollection = true }

            )

            menuButton(

                title: "CONFIGURAÇÕES",

                subtitle: "Ajustes da experiência AR",

                icon: "gearshape.fill",

                accent: Color.white.opacity(0.70),

                action: { showingSettings = true }

            )

        }

    }

    private var brandHeader: some View {

        VStack(spacing: 10) {

            HStack(spacing: 9) {

                Capsule()

                    .fill(cyan.opacity(0.65))

                    .frame(width: 24, height: 1)

                Text("JOGO DE CARTAS COM REALIDADE AUMENTADA")

                    .font(.system(size: 9, weight: .bold, design: .rounded))

                    .tracking(1.8)

                    .lineLimit(1)

                    .minimumScaleFactor(0.7)

                    .foregroundStyle(.white.opacity(0.58))

                Capsule()

                    .fill(violet.opacity(0.65))

                    .frame(width: 24, height: 1)

            }

            Image("DeckSpawnLogo")

                .resizable()

                .scaledToFit()

                .frame(maxWidth: 410)

                .blendMode(.screen)

                .accessibilityLabel("DeckSpawn")

            Text("SUAS CARTAS GANHAM VIDA")

                .font(.system(size: 12, weight: .medium, design: .rounded))

                .tracking(2.0)

                .foregroundStyle(.white.opacity(0.70))

        }

        .frame(maxWidth: .infinity)

    }

    // LocalizedStringKey permite traduzir título e subtítulo via Localizable.xcstrings.

    // Usar String aqui faria Text exibir o conteúdo literalmente, sem buscar tradução.

    private func menuButton(

        title: LocalizedStringKey,

        subtitle: LocalizedStringKey,

        icon: String,

        accent: Color,

        isPrimary: Bool = false,

        action: @escaping () -> Void

    ) -> some View {

        Button(action: action) {

            HStack(spacing: 14) {

                Image(systemName: icon)

                    .font(.system(size: 19, weight: .semibold))

                    .foregroundStyle(accent)

                    .frame(width: 44, height: 44)

                    .background(accent.opacity(isPrimary ? 0.16 : 0.11))

                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {

                    Text(title)

                        .font(.system(size: 15, weight: .heavy, design: .rounded))

                        .tracking(1.0)

                        .foregroundStyle(.white)

                    Text(subtitle)

                        .font(.system(size: 11, weight: .medium))

                        .foregroundStyle(.white.opacity(0.53))

                        .fixedSize(horizontal: false, vertical: true)

                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.right")

                    .font(.system(size: 12, weight: .bold))

                    .foregroundStyle(accent.opacity(0.85))

            }

            .padding(.horizontal, 15)

            .frame(height: 74)

            .background {

                RoundedRectangle(cornerRadius: 19, style: .continuous)

                    .fill(

                        LinearGradient(

                            colors: [

                                accent.opacity(isPrimary ? 0.23 : 0.12),

                                Color(red: 0.04, green: 0.06, blue: 0.16).opacity(0.95)

                            ],

                            startPoint: .topLeading,

                            endPoint: .bottomTrailing

                        )

                    )

            }

            .overlay {

                RoundedRectangle(cornerRadius: 19, style: .continuous)

                    .strokeBorder(

                        LinearGradient(

                            colors: [

                                accent.opacity(isPrimary ? 0.75 : 0.32),

                                .white.opacity(0.08),

                                violet.opacity(isPrimary ? 0.22 : 0.10)

                            ],

                            startPoint: .topLeading,

                            endPoint: .bottomTrailing

                        ),

                        lineWidth: 1

                    )

            }

            .shadow(

                color: accent.opacity(isPrimary ? 0.13 : 0.04),

                radius: isPrimary ? 16 : 8,

                y: 5

            )

        }

        .buttonStyle(.plain)

    }

}

private struct DeckSpawnMenuBackground: View {

    private let darkNavy = Color(red: 0.015, green: 0.025, blue: 0.075)

    private let cyan = Color(red: 0.20, green: 0.84, blue: 1.00)

    private let violet = Color(red: 0.56, green: 0.39, blue: 1.00)

    var body: some View {

        GeometryReader { geometry in

            ZStack {

                darkNavy

                LinearGradient(

                    colors: [

                        Color(red: 0.025, green: 0.055, blue: 0.16),

                        darkNavy,

                        Color(red: 0.07, green: 0.035, blue: 0.14),

                        darkNavy

                    ],

                    startPoint: .topLeading,

                    endPoint: .bottomTrailing

                )

                // Clarões difusos, sem competir com o logotipo.

                Circle()

                    .fill(cyan.opacity(0.18))

                    .frame(width: 280, height: 280)

                    .blur(radius: 95)

                    .position(x: geometry.size.width * 0.12, y: geometry.size.height * 0.23)

                Circle()

                    .fill(violet.opacity(0.20))

                    .frame(width: 300, height: 300)

                    .blur(radius: 108)

                    .position(x: geometry.size.width * 0.90, y: geometry.size.height * 0.43)

                // Círculos sutis de invocação atrás da marca.

                Circle()

                    .stroke(

                        LinearGradient(

                            colors: [

                                cyan.opacity(0.36),

                                violet.opacity(0.18),

                                cyan.opacity(0.10)

                            ],

                            startPoint: .topLeading,

                            endPoint: .bottomTrailing

                        ),

                        lineWidth: 1

                    )

                    .frame(width: 380, height: 380)

                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.27)

                    .opacity(0.52)

                Circle()

                    .stroke(violet.opacity(0.12), lineWidth: 1)

                    .frame(width: 295, height: 295)

                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.27)

                // Pequenos pontos de luz discretos para dar profundidade.

                Canvas { context, size in

                    let stars: [(CGFloat, CGFloat, CGFloat)] = [

                        (0.13, 0.12, 1.4), (0.82, 0.08, 1.0),

                        (0.92, 0.23, 1.5), (0.09, 0.43, 1.0),

                        (0.77, 0.49, 0.9), (0.18, 0.67, 1.4),

                        (0.85, 0.78, 1.1), (0.26, 0.90, 1.0)

                    ]

                    for (x, y, diameter) in stars {

                        let rect = CGRect(

                            x: size.width * x,

                            y: size.height * y,

                            width: diameter,

                            height: diameter

                        )

                        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.28)))

                    }

                }

            }

            .frame(width: geometry.size.width, height: geometry.size.height)

            .ignoresSafeArea()

        }

        .ignoresSafeArea()

        .allowsHitTesting(false)

    }

}
