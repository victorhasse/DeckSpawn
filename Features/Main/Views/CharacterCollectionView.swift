import SwiftUI
import UIKit

// A Coleção não inicia uma ARSession nem carrega arquivos USDZ.
// A lista usa apenas o mesmo cadastro das cartas disponíveis no jogo.
struct CharacterCollectionView: View {
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                CharacterCollectionBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        header

                        HStack(spacing: 8) {
                            Text("PERSONAGENS DISPONÍVEIS")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .tracking(1.5)
                                .foregroundStyle(.white.opacity(0.72))

                            Spacer()

                            Text("\(CardDatabase.all.count)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.cyan)
                        }

                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(CardDatabase.all) { card in
                                NavigationLink(value: card) {
                                    CharacterCollectionTile(card: card)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 40)
                    .frame(maxWidth: 620)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 34, height: 34)
                            .background(.white.opacity(0.10), in: Circle())
                    }
                    .accessibilityLabel(Text("VOLTAR"))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: CardDefinition.self) { card in
                CharacterCollectionDetailView(card: card)
            }
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "square.grid.2x2.fill")
                    .foregroundStyle(.cyan)

                Text("DECKSPAWN")
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.64))
            }
            .font(.system(size: 11, weight: .bold, design: .rounded))

            Text("COLEÇÃO")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .tracking(1)
                .foregroundStyle(.white)

            Text("Toque em um personagem para ver os detalhes.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct CharacterCollectionTile: View {
    let card: CardDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CharacterCollectionPortrait(card: card)
                .frame(height: 176)
                .clipped()

            VStack(alignment: .leading, spacing: 8) {
                Text(card.displayName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red.opacity(0.86))
                    Text("\(card.maxHP)")
                    Spacer(minLength: 6)
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.yellow.opacity(0.9))
                    Text("\(card.attackPower)")
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(red: 0.065, green: 0.095, blue: 0.19))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(card.collectionAccent.opacity(0.34), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CharacterCollectionDetailView: View {
    let card: CardDefinition

    var body: some View {
        ZStack {
            CharacterCollectionBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    CharacterCollectionPortrait(card: card)
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(card.collectionAccent.opacity(0.42), lineWidth: 1)
                        }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("DETALHES DO PERSONAGEM")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(1.8)
                            .foregroundStyle(card.collectionAccent)

                        Text(card.displayName)
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text(LocalizedStringKey(card.collectionDescription))
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.76))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 12) {
                        statistic(title: "VIDA", value: card.maxHP, symbol: "heart.fill", tint: .red)
                        statistic(title: "ATAQUE", value: card.attackPower, symbol: "bolt.fill", tint: .yellow)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 40)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func statistic(
        title: LocalizedStringKey,
        value: Int,
        symbol: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))

                Text("\(value)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 16))
    }
}

// Retratos opcionais, sempre locais: Collection_<referenceImageName> em Assets.xcassets.
// Na ausência de uma imagem, uma arte vetorial leve substitui o retrato.
private struct CharacterCollectionPortrait: View {
    let card: CardDefinition

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [
                        card.collectionAccent.opacity(0.32),
                        Color(red: 0.05, green: 0.07, blue: 0.17),
                        Color(red: 0.10, green: 0.06, blue: 0.19)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .stroke(card.collectionAccent.opacity(0.23), lineWidth: 1)
                    .frame(width: geometry.size.width * 0.83)

                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 1)
                    .frame(width: geometry.size.width * 0.60)

                if let portrait = UIImage(named: card.collectionPortraitName) {
                    Image(uiImage: portrait)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    Image(systemName: card.collectionSymbol)
                        .font(.system(size: min(geometry.size.width * 0.37, 105), weight: .ultraLight))
                        .foregroundStyle(card.collectionAccent.opacity(0.94))
                        .shadow(color: card.collectionAccent.opacity(0.4), radius: 18)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityHidden(true)
    }
}

private struct CharacterCollectionBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.015, green: 0.025, blue: 0.075)

            LinearGradient(
                colors: [
                    Color(red: 0.035, green: 0.085, blue: 0.20),
                    Color(red: 0.015, green: 0.025, blue: 0.075),
                    Color(red: 0.09, green: 0.035, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

private extension CardDefinition {
    var collectionPortraitName: String {
        "Collection_\(referenceImageName)"
    }

    var collectionAccent: Color {
        switch referenceImageName {
        case "spiderman_cardgame": return Color(red: 0.95, green: 0.28, blue: 0.32)
        case "stormtrooper_cardgame": return Color(red: 0.45, green: 0.81, blue: 1.00)
        case "goku_cardgame": return Color(red: 1.00, green: 0.68, blue: 0.25)
        case "mrsincredible_cardgame": return Color(red: 0.78, green: 0.40, blue: 1.00)
        default: return .cyan
        }
    }

    var collectionSymbol: String {
        switch referenceImageName {
        case "spiderman_cardgame": return "circle.hexagongrid.fill"
        case "stormtrooper_cardgame": return "shield.fill"
        case "goku_cardgame": return "bolt.fill"
        case "mrsincredible_cardgame": return "star.fill"
        default: return "person.crop.square.fill"
        }
    }
}
