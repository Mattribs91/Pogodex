import SwiftUI

struct RaidAnnotationView: View {
    let gym: PogoMapGym
    let pokemonName: String
    let timerTick: Int

    var body: some View {
        let teamColor = gym.teamColor

        VStack(spacing: 4) {
            VStack(spacing: 2) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(RadialGradient(
                            colors: [teamColor, teamColor.opacity(0.8)],
                            center: .center,
                            startRadius: 5,
                            endRadius: 25
                        ))
                        .frame(width: 52, height: 52)
                        .shadow(color: teamColor.opacity(0.6), radius: 6, y: 3)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white.opacity(0.4), lineWidth: 1)
                        }

                    if let pokemonId = gym.raidPokemonId, pokemonId > 0 {
                        CachedAsyncImage(
                            url: URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/\(pokemonId).png"),
                            size: 40, contentMode: .fit
                        )
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                        .clipShape(.circle)
                    } else {
                        Text("🥚")
                            .font(.system(size: 32))
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                .overlay(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(RadialGradient(
                                colors: [.black.opacity(0.9), .black.opacity(0.7)],
                                center: .center,
                                startRadius: 2,
                                endRadius: 12
                            ))
                            .frame(width: 32, height: 16)
                            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)

                        Text(PogoMapGym.raidTierShortLabel(gym.raidLevel ?? 0))
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .offset(y: -8)
                }

                if let pokemonId = gym.raidPokemonId, pokemonId > 0 {
                    Text(pokemonName)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: Capsule())
                        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                }

                let _ = timerTick
                if !gym.isRaidHatched, let battle = gym.raidBattleTimestamp {
                    let hatchIn = Date(timeIntervalSince1970: TimeInterval(battle)).timeIntervalSince(.now)
                    if hatchIn > 0 {
                        countdownBadge(seconds: hatchIn, color: hatchIn < 300 ? .red : teamColor)
                    }
                } else if let end = gym.raidEndTimestamp {
                    let remaining = Date(timeIntervalSince1970: TimeInterval(end)).timeIntervalSince(.now)
                    if remaining > 0 {
                        countdownBadge(seconds: remaining, color: remaining < 300 ? .red : teamColor)
                    }
                }
            }

            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 12))
                .foregroundStyle(teamColor)
                .offset(y: 1)
        }
    }

    private func countdownBadge(seconds: TimeInterval, color: Color) -> some View {
        Text(raidCountdown(seconds))
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color, in: Capsule())
            .shadow(color: color.opacity(0.4), radius: 3, y: 1)
    }

    private func raidCountdown(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return "\(m):\(s.formatted(.number.precision(.integerLength(2))))"
    }
}
