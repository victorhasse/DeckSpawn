import SwiftUI

enum BattleTheme {
    static let cyan = Color(red: 0.16, green: 0.91, blue: 1.0)
    static let violet = Color(red: 0.64, green: 0.39, blue: 1.0)
    static let ink = Color(red: 0.035, green: 0.055, blue: 0.14)
    static let panel = Color(red: 0.045, green: 0.075, blue: 0.19)
}

struct BattleRoundBanner: View {
    let round: Int
    let message: String?
    let isResolving: Bool
    let showsClock: Bool
    let secondsRemaining: Int

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.horizontal.fill")
                        .foregroundStyle(BattleTheme.cyan)
                    Text("RODADA \(round)")
                        .foregroundStyle(.white)
                }
                .font(.system(size: 11, weight: .black, design: .rounded))

                if let message {
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

            if isResolving {
                ProgressView()
                    .tint(BattleTheme.cyan)
                    .frame(width: 44, height: 44)
            } else if showsClock {
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
        let ratio = min(max(Double(secondsRemaining) / Double(duration), 0), 1)
        let color = secondsRemaining <= 5 ? Color.red :
                    secondsRemaining <= 10 ? Color.orange : BattleTheme.cyan

        return ZStack {
            Circle().stroke(Color.white.opacity(0.11), lineWidth: 4)
            Circle()
                .trim(from: 0, to: ratio)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.3), value: secondsRemaining)
            Text("\(secondsRemaining)")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(width: 45, height: 45)
        .accessibilityLabel("\(secondsRemaining)s")
    }

}

struct FighterHPCard: View {
    let title: String
    let card: CardDefinition
    let currentHP: Int
    let maxHP: Int
    let progress: Double
    let isTrailing: Bool

    init(title: String, card: CardDefinition, currentHP: Int, maxHP: Int,
         progress: Double, isTrailing: Bool) {
        self.title = title
        self.card = card
        self.currentHP = currentHP
        self.maxHP = maxHP
        self.progress = progress
        self.isTrailing = isTrailing
    }

    // These are presentation values only. BattleState remains the source of truth.
    // The trailing (amber) bar briefly shows the amount of HP just lost.
    @State private var visibleProgress = 1.0
    @State private var trailingProgress = 1.0
    @State private var previousHP: Int?

    private var accent: Color { isTrailing ? BattleTheme.violet : BattleTheme.cyan }
    private var healthColor: Color {
        progress <= 0.25 ? .red : (progress <= 0.50 ? .orange : accent)
    }
    private var normalizedProgress: Double {
        guard progress.isFinite else { return 0 }
        return min(max(progress, 0), 1)
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

                    // Briefly retain the previous HP in amber to emphasize damage.
                    Capsule()
                        .fill(Color(red: 1.0, green: 0.67, blue: 0.31).opacity(0.85))
                        .frame(width: geo.size.width * trailingProgress)

                    Capsule()
                        .fill(LinearGradient(
                            colors: [healthColor.opacity(0.65), healthColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * visibleProgress)
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
        .task(id: currentHP) {
            // SwiftUI cancels an older task when HP changes again or this card
            // disappears, preventing delayed animations from a prior battle.
            let target = normalizedProgress
            guard let oldHP = previousHP else {
                previousHP = currentHP
                snapHPBar(to: target)
                return
            }
            previousHP = currentHP

            // Recovery/rematch: refill instantly, with no stale amber segment.
            guard currentHP < oldHP else {
                snapHPBar(to: target)
                return
            }

            withAnimation(.easeOut(duration: 0.40)) {
                visibleProgress = target
            }
            do {
                try await Task.sleep(nanoseconds: 240_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.52)) {
                trailingProgress = target
            }
        }
    }

    private func snapHPBar(to value: Double) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            visibleProgress = value
            trailingProgress = value
        }
    }
}

struct BattleActionPanel: View {
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

struct BattleResultPanel: View {
    let winner: BattleWinner
    let playerName: String
    let enemyName: String
    let rounds: Int
    let remainingHP: Int
    let onExit: () -> Void
    let onRematch: (() -> Void)?
    var exitTitle: LocalizedStringKey = "VOLTAR AO MENU"
    var exitIcon: String = "house.fill"

    private var victory: Bool { winner == .player }
    private var accent: Color { victory ? BattleTheme.cyan : BattleTheme.violet }

    var body: some View {
        VStack(spacing: 11) {
            HStack(spacing: 11) {
                Image(systemName: victory ? "trophy.fill" : "shield.slash.fill")
                    .font(.system(size: 29, weight: .semibold))
                    .foregroundStyle(accent)
                    .shadow(color: accent.opacity(0.55), radius: 10)

                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringKey(victory ? "VITÓRIA" : "DERROTA"))
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(.white)
                    Text(DeckSpawnL10n.format(
                        "%@ venceu %@.",
                        victory ? playerName : enemyName,
                        victory ? enemyName : playerName
                    ))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                resultStat(title: "RODADAS", value: rounds, icon: "arrow.triangle.2.circlepath")
                resultStat(title: "HP RESTANTE", value: remainingHP, icon: "heart.fill")
            }

            if let onRematch {
                Button(action: onRematch) {
                    Label("REVANCHE", systemImage: "arrow.clockwise")
                        .font(.system(size: 14, weight: .black))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .foregroundStyle(BattleTheme.ink)
                        .background(
                            LinearGradient(
                                colors: [BattleTheme.cyan, BattleTheme.violet],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                }
                .buttonStyle(.plain)

            }

            Button(action: onExit) {
                Label(exitTitle, systemImage: exitIcon)
                    .font(.system(size: 12, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .foregroundStyle(.white.opacity(0.95))
                    .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(17)
        // Keep the AR scene visible behind the compact result panel.
        .background(BattleTheme.ink.opacity(0.87), in: RoundedRectangle(cornerRadius: 23))
        .overlay {
            RoundedRectangle(cornerRadius: 23)
                .stroke(accent.opacity(0.65), lineWidth: 1)
        }
        .shadow(color: accent.opacity(0.15), radius: 16)
        .padding(.horizontal, 20)
        .padding(.bottom, 23)
    }

    private func resultStat(title: LocalizedStringKey, value: Int, icon: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.65))
                Text("\(value)")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Damage numbers projected over the RealityKit fighters
struct FloatingDamageOverlay: View {
    let event: FloatingDamageEvent?

    var body: some View {
        GeometryReader { _ in
            if let event {
                FloatingDamageNumber(amount: event.amount)
                    .id(event.id)
                    .position(
                        x: event.screenPoint?.x ?? -200,
                        y: event.screenPoint?.y ?? -200
                    )
                    .opacity(event.screenPoint == nil ? 0 : 1)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct FloatingDamageNumber: View {
    let amount: Int
    @State private var rise: CGFloat = 0
    @State private var opacity: Double = 1

    var body: some View {
        Text("−\(amount)")
            .font(.system(size: 27, weight: .black, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Color(red: 1.0, green: 0.35, blue: 0.28))
            .shadow(color: .black.opacity(0.90), radius: 3, x: 1, y: 2)
            .shadow(color: .red.opacity(0.35), radius: 8)
            .fixedSize()
            .offset(y: -rise)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.85)) {
                    rise = 52
                    opacity = 0
                }
            }
    }
}
