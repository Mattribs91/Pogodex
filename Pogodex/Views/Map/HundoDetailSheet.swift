import SwiftUI
import MapKit
import Combine

struct HundoDetailSheet: View {
    let poke: PogoMapPokemon
    let pokemonName: (Int) -> String
    @Environment(\.dismiss) private var dismiss
    @State private var timerTick = 0
    private let countdownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let spriteId = poke.displayPokemonId ?? poke.pokemonId
        NavigationStack {
            VStack(spacing: 16) {
                CachedAsyncImage(
                    url: URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/\(spriteId).png"),
                    size: 120
                )
                .frame(width: 120, height: 120)

                Text(pokemonName(poke.pokemonId))
                    .font(.title2.bold())

                if let displayId = poke.displayPokemonId, displayId != poke.pokemonId {
                    Text("Déguisé en \(pokemonName(displayId))")
                        .font(.subheadline)
                        .foregroundStyle(.purple)
                }

                HStack(spacing: 20) {
                    Label("\(poke.ivInt)% IV", systemImage: "star.fill")
                        .foregroundStyle(poke.ivInt >= 100 ? .yellow : .orange)
                        .font(.headline)

                    if let form = poke.form, form != 0 {
                        Label("Forme \(form)", systemImage: "sparkles")
                            .font(.subheadline)
                    }
                }

                if let atk = poke.atkIv, let def = poke.defIv, let sta = poke.staIv {
                    HStack(spacing: 16) {
                        statBadge("ATK", value: atk)
                        statBadge("DEF", value: def)
                        statBadge("STA", value: sta)
                    }
                }

                HStack(spacing: 16) {
                    if let cp = poke.cp {
                        Label("CP \(cp)", systemImage: "bolt.fill")
                            .font(.subheadline)
                    }
                    if let level = poke.level {
                        Label("Niv. \(level)", systemImage: "arrow.up.circle")
                            .font(.subheadline)
                    }
                }

                let _ = timerTick
                let remaining = Date(timeIntervalSince1970: TimeInterval(poke.expireTimestamp)).timeIntervalSince(.now)
                if remaining > 0 {
                    let verified = poke.expireTimestampVerified == true
                    Label(
                        "Disparaît dans \(raidCountdown(remaining))\(verified ? " ✓" : " ~")",
                        systemImage: "clock"
                    )
                    .font(.subheadline)
                    .foregroundStyle(remaining < 300 ? .red : .secondary)
                } else {
                    Label("Expiré", systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }

                Text(coordinateText(latitude: poke.lat, longitude: poke.lon))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Pokémon sauvage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .onReceive(countdownTimer) { _ in timerTick += 1 }
    }

    private func statBadge(_ label: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(value == 15 ? .green : value >= 13 ? .orange : .primary)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(width: 50, height: 45)
        .background(Color.gray.opacity(0.1))
        .clipShape(.rect(cornerRadius: 8))
    }

    private func raidCountdown(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return "\(m):\(s.formatted(.number.precision(.integerLength(2))))"
    }

    private func coordinateText(latitude: Double, longitude: Double) -> String {
        "\(latitude.formatted(.number.precision(.fractionLength(5)))), \(longitude.formatted(.number.precision(.fractionLength(5))))"
    }
}
