import SwiftUI

struct DeckSpawnScannerOverlay: View {

    enum Mode: Equatable {
        case singlePlayer
        case multiplayer
    }

    @ObservedObject var state: GameARState

    let screenSize: CGSize
    var mode: Mode = .singlePlayer

    private var accentColor: Color {
        switch state.phase {
        case .searching:
            return .cyan
        case .aligning, .lost, .waitingForCardRemoval:
            return .orange
        case .holding, .scanning:
            return .cyan
        case .confirmed, .active:
            return .green
        case .summoning, .enemySummoning:
            return .purple
        case .failed:
            return .red
        case .removing, .battleReady:
            return .white
        }
    }

    var body: some View {
        let rect = ScanLayout.guideRect(in: screenSize)

        ZStack {
            holographicFrame
                .frame(
                    width: rect.width,
                    height: rect.height
                )
                .position(
                    x: rect.midX,
                    y: rect.midY
                )

            centerStatus
                .frame(width: rect.width - 28)
                .position(
                    x: rect.midX,
                    y: rect.midY
                )

            instructionPanel
                .frame(
                    width: min(
                        screenSize.width - 32,
                        340
                    )
                )
                .position(
                    x: screenSize.width / 2,
                    y: min(
                        rect.maxY + 58,
                        screenSize.height - 44
                    )
                )
        }
        .frame(
            width: screenSize.width,
            height: screenSize.height
        )
        .animation(
            .easeInOut(duration: 0.25),
            value: state.phase
        )
        .allowsHitTesting(false)
    }

    // MARK: - Holographic Frame

    private var holographicFrame: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    accentColor.opacity(0.035)
                )

            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    accentColor.opacity(0.50),
                    style: StrokeStyle(
                        lineWidth: 1.5,
                        dash: usesDashedBorder ? [8, 7] : []
                    )
                )

            ScannerCornerShape()
                .stroke(
                    accentColor,
                    style: StrokeStyle(
                        lineWidth: 4,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .padding(3)
                .shadow(
                    color: accentColor.opacity(0.75),
                    radius: 8
                )

            if state.phase == .scanning {
                DeckSpawnScannerBeam()
                    .clipShape(
                        RoundedRectangle(cornerRadius: 22)
                    )
            }

            if state.phase == .holding {
                RoundedRectangle(cornerRadius: 22)
                    .trim(
                        from: 0,
                        to: max(
                            CGFloat(0.001),
                            min(CGFloat(1), state.holdProgress)
                        )
                    )
                    .stroke(
                        .white,
                        style: StrokeStyle(
                            lineWidth: 4,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(
                        color: .cyan,
                        radius: 8
                    )
            }

            VStack {
                Spacer()
                progressIndicator
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Center Status

    private var centerStatus: some View {
        VStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(
                    .system(
                        size: 29,
                        weight: .semibold
                    )
                )
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(accentColor)
                .shadow(
                    color: accentColor.opacity(0.65),
                    radius: 8
                )

            Text(LocalizedStringKey(statusTitle))
                .font(.system(size: 11, weight: .black))
                .tracking(1.0)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

            
            if let assetName = state.recognizedCardName,
               let card = CardDatabase.card(named: assetName),
               showsCardName {

                Text(LocalizedStringKey(card.displayName))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

        }
        .padding(.horizontal, 11)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.36))
        )
    }

    // MARK: - Progress

    @ViewBuilder
    private var progressIndicator: some View {
        if state.phase == .holding {
            progressBar(
                progress: Double(state.holdProgress),
                color: .cyan
            )
        } else if state.phase == .scanning {
            progressBar(
                progress: Double(state.scanProgress),
                color: .cyan
            )
        } else if state.phase == .summoning {
            ProgressView()
                .tint(.purple)
                .controlSize(.small)
        }
    }

    private func progressBar(
        progress: Double,
        color: Color
    ) -> some View {
        let safeProgress = min(max(progress, 0), 1)

        return VStack(spacing: 5) {
            ProgressView(value: safeProgress, total: 1)
                .tint(color)

            Text("\(Int((safeProgress * 100).rounded()))%")
                .font(.system(size: 10, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.55))
        )
    }

    // MARK: - Instructions

    private var instructionPanel: some View {
        Text(LocalizedStringKey(instructionText))
            .font(.callout)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .fixedSize(
                horizontal: false,
                vertical: true
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.64))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        accentColor.opacity(0.45),
                        lineWidth: 1
                    )
            )
    }

    // MARK: - Phase Properties

    private var usesDashedBorder: Bool {
        switch state.phase {
        case .searching, .aligning, .lost:
            return true
        default:
            return false
        }
    }

    private var showsCardName: Bool {
        switch state.phase {
        case .aligning, .holding, .scanning, .confirmed:
            return true
        default:
            return false
        }
    }

    private var statusIcon: String {
        switch state.phase {
        case .searching:
            return "viewfinder"
        case .aligning:
            return "scope"
        case .holding:
            return "hand.raised.fill"
        case .scanning:
            return "waveform.path"
        case .confirmed:
            return "checkmark.circle.fill"
        case .summoning:
            return "sparkles"
        case .lost:
            return "exclamationmark.triangle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .waitingForCardRemoval:
            return "rectangle.portrait.and.arrow.forward"
        case .removing:
            return "arrow.triangle.2.circlepath"
        case .active, .enemySummoning, .battleReady:
            return "checkmark"
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
        case .removing:
            return "REMOVENDO..."
        case .active, .enemySummoning, .battleReady:
            return ""
        }
    }

    private var instructionText: String {
        switch state.phase {
        case .searching:
            return mode == .multiplayer
                ? "Mostre a carta que você quer usar nesta partida"
                : "Mostre uma carta cadastrada dentro do campo"

        case .aligning:
            return "Centralize a carta no campo de leitura"

        case .holding:
            return mode == .multiplayer
                ? "Mantenha a carta imóvel"
                : "Mantenha a carta imóvel por um instante"

        case .scanning:
            return "Não retire a carta até concluir a leitura"

        case .confirmed:
            return mode == .multiplayer
                ? "Carta reconhecida"
                : "Leitura concluída"

        case .summoning:
            return mode == .multiplayer
                ? "Preparando seu personagem..."
                : "Preparando invocação..."

        case .lost:
            return mode == .multiplayer
                ? "Reposicione a carta"
                : "Reposicione a carta dentro do campo"

        case .failed:
            return mode == .multiplayer
                ? "Tente novamente com uma carta cadastrada"
                : "Nenhuma carta cadastrada foi encontrada"

        case .waitingForCardRemoval:
            return mode == .multiplayer
                ? "Retire a carta para escolher outra"
                : "Retire a carta da câmera para iniciar uma nova leitura"

        case .removing:
            return "Preparando nova seleção..."

        case .active, .enemySummoning, .battleReady:
            return ""
        }
    }
}

// MARK: - Scanner Corners

private struct ScannerCornerShape: Shape {

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let length: CGFloat = min(
            32,
            min(rect.width, rect.height) * 0.20
        )

        let x0 = rect.minX
        let x1 = rect.maxX
        let y0 = rect.minY
        let y1 = rect.maxY

        // Superior esquerdo
        path.move(to: CGPoint(x: x0, y: y0 + length))
        path.addLine(to: CGPoint(x: x0, y: y0))
        path.addLine(to: CGPoint(x: x0 + length, y: y0))

        // Superior direito
        path.move(to: CGPoint(x: x1 - length, y: y0))
        path.addLine(to: CGPoint(x: x1, y: y0))
        path.addLine(to: CGPoint(x: x1, y: y0 + length))

        // Inferior direito
        path.move(to: CGPoint(x: x1, y: y1 - length))
        path.addLine(to: CGPoint(x: x1, y: y1))
        path.addLine(to: CGPoint(x: x1 - length, y: y1))

        // Inferior esquerdo
        path.move(to: CGPoint(x: x0 + length, y: y1))
        path.addLine(to: CGPoint(x: x0, y: y1))
        path.addLine(to: CGPoint(x: x0, y: y1 - length))

        return path
    }
}

// MARK: - Animated Scanner Beam


private struct DeckSpawnScannerBeam: View {

    @State private var isMoving = false

    var body: some View {
        GeometryReader { geometry in
            let travelDistance = max(
                0,
                geometry.size.height - 56
            )

            ZStack(alignment: .top) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                .cyan.opacity(0.12),
                                .cyan.opacity(0.25),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 56)

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
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 3)
                    .shadow(color: .cyan, radius: 10)
            }
            .offset(y: isMoving ? travelDistance : 0)
            .animation(
                .linear(duration: 1.45)
                    .repeatForever(autoreverses: true),
                value: isMoving
            )
            .onAppear {
                isMoving = true
            }
            .onDisappear {
                isMoving = false
            }
        }
    }
}
