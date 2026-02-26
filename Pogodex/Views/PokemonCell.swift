import SwiftUI

/// Cellule compacte pour afficher un Pokémon dans la grille.
struct PokemonCell: View, Equatable {
    let pokemon: Pokemon
    let capturedCount: Int
    let hasShiny: Bool
    let hasLucky: Bool
    let hasGigantamax: Bool
    let hasGigantamaxShiny: Bool
    // Clé de langue pour forcer le rafraîchissement au changement de langue
    let languageKey: String = localizedLanguageKey()
    
    // Permet à SwiftUI de sauter le render si les props n'ont pas changé
    static func == (lhs: PokemonCell, rhs: PokemonCell) -> Bool {
        lhs.pokemon.id == rhs.pokemon.id &&
        lhs.capturedCount == rhs.capturedCount &&
        lhs.hasShiny == rhs.hasShiny &&
        lhs.hasLucky == rhs.hasLucky &&
        lhs.hasGigantamax == rhs.hasGigantamax &&
        lhs.hasGigantamaxShiny == rhs.hasGigantamaxShiny &&
        lhs.languageKey == rhs.languageKey
    }

    var body: some View {
        let isCapturedOrLucky = capturedCount > 0 || hasLucky
        
        VStack(spacing: 6) {
            // Image Dynamique : Shiny HQ si capturé en shiny, sinon Normal HQ
            let imageUrl = hasShiny ? pokemon.officialShinyArtworkUrl : pokemon.officialArtworkUrl
            
            CachedAsyncImage(url: imageUrl ?? pokemon.imageUrl, size: 72)
                .opacity(isCapturedOrLucky ? 1.0 : 0.45)
                .grayscale(pokemon.isNotAvailable ? 0.99 : 0.0)
                .padding(.top, 10) // Descendre l'image pour ne pas chevaucher les badges
            
            // Numéro de Pokédex
            Text("#\(pokemon.dexNr)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
            
            // Nom du Pokémon
            Text(pokemon.name)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(isCapturedOrLucky ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .padding(.horizontal, 8)
        .background(backgroundView)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .overlay(alignmentBorder)
        .overlay(alignment: .topTrailing) { capturedbadge }
        .overlay(alignment: .topTrailing) { notAvailableBadge }
        .overlay(alignment: .topLeading) { 
            HStack(spacing: -4) { // Pour superposer légèrement si les deux sont présents
                classBadgeView 
                gigantamaxBadge 
            }
        }
        .shadow(color: Color.black.opacity(isCapturedOrLucky ? 0.08 : 0.03), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Captures Badge
    
    @ViewBuilder
    private var capturedbadge: some View {
        if capturedCount > 0 || hasLucky || hasShiny {
            HStack(spacing: 3) {
                if hasLucky {
                    Image(systemName: "star.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.yellow)
                }
                if hasShiny {
                    Image(systemName: "sparkles")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                }
                if capturedCount > 0 {
                    Text("\(capturedCount)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(badgeColor))
            .shadow(color: badgeColor.opacity(0.4), radius: 3, x: 0, y: 1)
            .offset(x: -6, y: 6)
        }
    }
    
    // MARK: - Not Available Badge
    
    @ViewBuilder
    private var notAvailableBadge: some View {
        if pokemon.isNotAvailable {
            Image(systemName: "clock.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(Color.gray.opacity(0.8))
                )
                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                .offset(x: -6, y: 6)
        }
    }
    
    // MARK: - Gigantamax Badge (Top Leading)
    
    @ViewBuilder
    private var gigantamaxBadge: some View {
        if hasGigantamax {
            HStack(spacing: 2) {
                Text("GMAX")
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(
                    hasGigantamaxShiny ?
                    AnyShapeStyle(
                        LinearGradient(
                            colors: [.yellow, .orange], // Or pour Shiny
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    ) :
                    AnyShapeStyle(
                        LinearGradient(
                            colors: [.red, .pink], // Rouge pour Normal
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
            )
            .shadow(color: hasGigantamaxShiny ? .orange.opacity(0.4) : .red.opacity(0.4), radius: 2, x: 0, y: 1)
            .offset(x: 6, y: 6)
        }
    }
    
    // MARK: - Border (Lucky/Shiny)
    
    @ViewBuilder
    private var alignmentBorder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(
                hasLucky ? luckyGradient : clearGradient,
                lineWidth: hasLucky ? 2.5 : 0
            )
    }
    
    private var luckyGradient: LinearGradient {
        LinearGradient(
            colors: [.yellow, .orange, .yellow],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var clearGradient: LinearGradient {
        LinearGradient(
            colors: [.clear],
            startPoint: .center,
            endPoint: .center
        )
    }
    
    // MARK: - Class Badge (Legendary/Mythic/UB)
    
    @ViewBuilder
    private var classBadgeView: some View {
        if pokemon.isLegendary {
            classBadge(text: "L", colors: [.yellow, .orange])
        } else if pokemon.isMythic {
            classBadge(text: "F", colors: [.pink, .purple])
        } else if pokemon.isUltraBeast {
            classBadge(text: "UC", colors: [.cyan, .blue])
        }
    }
    
    private func classBadge(text: String, colors: [Color]) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(minWidth: 16, minHeight: 16) // Force une taille minimale carrée
            .padding(.horizontal, text.count == 1 ? 0 : 5) // Pas de padding horizontal si 1 lettre
            .padding(.vertical, text.count == 1 ? 0 : 3)
            .background(
                Group {
                    if text.count == 1 {
                        Circle().fill(
                            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    } else {
                        Capsule().fill(
                            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    }
                }
            )
            .shadow(color: colors[0].opacity(0.4), radius: 2, x: 0, y: 1)
            .offset(x: 6, y: 6)
    }
    
    // MARK: - Badge Color
    
    private var badgeColor: Color {
        if hasLucky { return .orange }
        if hasShiny { return .orange }
        return .green
    }
    
    // MARK: - Background
    
    @ViewBuilder
    private var backgroundView: some View {
        ZStack {
            // Fond de base
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(backgroundColor)
            
            // Effet Shiny (dégradé subtil)
            if hasShiny {
                shinyEffect
            }
            
            // Effet "Lucky" (lueur dorée)
            if hasLucky {
                luckyEffect
            }
        }
    }
    
    private var shinyEffect: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.yellow.opacity(0.12),
                        Color.orange.opacity(0.06),
                        Color.yellow.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
    
    private var luckyEffect: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                RadialGradient(
                    colors: [Color.yellow.opacity(0.2), Color.clear],
                    center: .center,
                    startRadius: 5,
                    endRadius: 60
                )
            )
    }
    
    private var backgroundColor: some ShapeStyle {
        if capturedCount > 0 || hasLucky {
            return AnyShapeStyle(Color(.secondarySystemGroupedBackground))
        } else {
            return AnyShapeStyle(Color(.tertiarySystemGroupedBackground))
        }
    }
}

