import SwiftUI
import UIKit

/// Short presentation between opponent summon and the existing 3-2-1 countdown.
/// Reuses locally generated Collection portraits; never starts ARKit or reads USDZ.
struct BattleVersusOverlay: View {
    let player: CardDefinition
    let opponent: CardDefinition

    @State private var appeared = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.04, blue: 0.13),
                        Color(red: 0.09, green: 0.035, blue: 0.15),
                        Color(red: 0.02, green: 0.04, blue: 0.13)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 12) {
                    Spacer(minLength: 12)
                    Text("PREPARE-SE")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .tracking(4)
                        .foregroundStyle(.cyan)

                    HStack(alignment: .center, spacing: 8) {
                        contender(player, side: "VOCÊ", alignment: .leading, textAlignment: .leading, accent: .cyan)
                            .offset(x: appeared ? 0 : -40)
                        Text("VS")
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .cyan.opacity(0.8), radius: 14)
                            .scaleEffect(appeared ? 1.0 : 0.6)
                            .accessibilityHidden(true)
                        contender(opponent, side: "CPU", alignment: .trailing, textAlignment: .trailing, accent: .purple)
                            .offset(x: appeared ? 0 : 40)
                    }
                    .padding(.horizontal, 14)
                    .opacity(appeared ? 1 : 0)

                    Text("A batalha vai começar")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer(minLength: 12)
                }
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear {
                withAnimation(.easeOut(duration: 0.42)) { appeared = true }
            }
        }
        .allowsHitTesting(true)
        .accessibilityElement(children: .contain)
    }

    private func contender(
        _ card: CardDefinition,
        side: LocalizedStringKey,
        alignment: HorizontalAlignment,
        textAlignment: Alignment,
        accent: Color
    ) -> some View {
        VStack(alignment: alignment, spacing: 10) {
            Text(side)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(accent)
            GeometryReader { proxy in
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(accent.opacity(0.16))
                    if let picture = UIImage(named: "Collection_\(card.referenceImageName)") {
                        Image(uiImage: picture)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 54, weight: .thin))
                            .foregroundStyle(accent)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(accent.opacity(0.55), lineWidth: 1.5)
                }
            }
            .frame(height: 180)

            Text(card.displayName)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: textAlignment)
        }
        .frame(maxWidth: .infinity)
    }
}
