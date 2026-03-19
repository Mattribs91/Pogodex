import SwiftUI

struct HundoAnnotationView: View {
    let poke: PogoMapPokemon

    private var ivColor: Color {
        if poke.iv >= 100 { .red }
        else if poke.iv >= 90 { .orange }
        else if poke.iv >= 80 { .yellow }
        else { .blue }
    }

    private var ivLabel: String {
        poke.ivInt >= 100 ? "💯" : "\(poke.ivInt)%"
    }

    var body: some View {
        let spriteId = poke.displayPokemonId ?? poke.pokemonId
        VStack(spacing: 0) {
            CachedAsyncImage(
                url: URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/\(spriteId).png"),
                size: 40
            )
            .frame(width: 40, height: 40)
            .background(Color.white.opacity(0.8))
            .clipShape(.circle)
            .overlay {
                Circle().stroke(ivColor, lineWidth: 2)
            }
            .shadow(radius: 2)

            Text(ivLabel)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(ivColor)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .offset(y: -5)
        }
    }
}
