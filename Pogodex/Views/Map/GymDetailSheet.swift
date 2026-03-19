import SwiftUI
import MapKit
import Combine

struct GymDetailSheet: View {
    let gym: PogoMapGym
    let pokemonName: (Int) -> String
    @Environment(\.dismiss) private var dismiss
    @State private var timerTick = 0
    @State private var directionsTrigger = 0
    private let countdownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    gymHeaderSection
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))

                    if gym.hasActiveRaid {
                        gymRaidSection
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                    }

                    if let defenders = gym.defenders, !defenders.isEmpty {
                        gymDefendersSection(defenders)
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }

                    if let totalCp = gym.totalCp, totalCp > 0 {
                        gymStatsSection
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }

                    gymActionsSection
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .animation(.easeInOut(duration: 0.4), value: gym.hasActiveRaid)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Détails de l'arène")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
        .onReceive(countdownTimer) { _ in timerTick += 1 }
        .sensoryFeedback(.impact(weight: .medium), trigger: directionsTrigger)
    }

    // MARK: - Header Section

    @ViewBuilder
    private var gymHeaderSection: some View {
        VStack(spacing: 16) {
            if let urlString = gym.url,
               let imageUrl = URL(string: urlString.replacing("http://", with: "https://")) {
                ZStack {
                    AsyncImage(url: imageUrl) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay { ProgressView().scaleEffect(0.8) }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(.rect(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

                    VStack {
                        Spacer()
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(gym.name ?? "Arène")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 2)

                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(gym.teamColor)
                                        .frame(width: 12, height: 12)
                                        .shadow(color: gym.teamColor.opacity(0.5), radius: 2)
                                    Text(gym.teamName)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .shadow(color: .black.opacity(0.5), radius: 2)
                                    if gym.exRaidEligible == true {
                                        Text("EX")
                                            .font(.system(size: 10, weight: .black, design: .rounded))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.purple, in: Capsule())
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.7)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 20, bottomTrailingRadius: 20))
                    }
                }
            }

            if gym.url == nil {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(gym.name ?? "Arène inconnue")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        HStack(spacing: 8) {
                            Circle()
                                .fill(gym.teamColor.gradient)
                                .frame(width: 16, height: 16)
                                .shadow(color: gym.teamColor.opacity(0.3), radius: 2)
                            Text(gym.teamName)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(gym.teamColor)
                        }
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(gym.teamColor.gradient)
                            .frame(width: 50, height: 50)
                            .shadow(color: gym.teamColor.opacity(0.4), radius: 4)
                        Image(systemName: "shield.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }

            HStack {
                Image(systemName: "location.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(coordinateText(latitude: gym.lat, longitude: gym.lon))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(gym.teamColor.opacity(0.2), lineWidth: 1)
                }
        )
    }

    // MARK: - Raid Section

    @ViewBuilder
    private var gymRaidSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(gym.raidLevelColor)
                Text(PogoMapGym.raidTierLabel(gym.raidLevel ?? 0))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(gym.raidLevelColor)
                Spacer()

                let _ = timerTick
                if !gym.isRaidHatched, let battle = gym.raidBattleTimestamp {
                    let hatchIn = Date(timeIntervalSince1970: TimeInterval(battle)).timeIntervalSince(.now)
                    if hatchIn > 0 {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Éclosion dans")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                            Text(raidCountdown(hatchIn))
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(.orange)
                        }
                    }
                } else if let end = gym.raidEndTimestamp {
                    let remaining = Date(timeIntervalSince1970: TimeInterval(end)).timeIntervalSince(.now)
                    if remaining > 0 {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Fin du raid")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                            Text(raidCountdown(remaining))
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(remaining < 300 ? Color.red : Color.blue)
                        }
                    }
                }
            }

            HStack(spacing: 20) {
                if let pokemonId = gym.raidPokemonId, pokemonId > 0 {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient(
                                colors: [gym.raidLevelColor.opacity(0.15), gym.raidLevelColor.opacity(0.05)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 90, height: 90)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(gym.raidLevelColor.opacity(0.3), lineWidth: 1)
                            }

                        CachedAsyncImage(
                            url: URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/\(pokemonId).png"),
                            size: 70, contentMode: .fit
                        )
                        .frame(width: 70, height: 70)
                        .background(.ultraThinMaterial, in: Circle())
                        .clipShape(.circle)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(pokemonName(pokemonId))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("#\(pokemonId)")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                        if let cp = gym.raidPokemonCp, cp > 0 {
                            Label("CP \(cp)", systemImage: "bolt.fill")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.orange)
                        }
                        Text("Boss de raid")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(gym.raidLevelColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(gym.raidLevelColor.opacity(0.1), in: Capsule())
                    }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient(
                                colors: [gym.raidLevelColor.opacity(0.15), gym.raidLevelColor.opacity(0.05)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 90, height: 90)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(gym.raidLevelColor.opacity(0.3), lineWidth: 1)
                            }
                        Text("🥚")
                            .font(.system(size: 50))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Œuf de raid")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text(PogoMapGym.raidTierLabel(gym.raidLevel ?? 0))
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                        if let battle = gym.raidBattleTimestamp {
                            let remaining = Date(timeIntervalSince1970: TimeInterval(battle)).timeIntervalSince(.now)
                            if remaining > 0 {
                                Text("Éclosion à \(raidCountdown(remaining))")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.1), in: Capsule())
                            } else {
                                Text("Boss inconnu")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.1), in: Capsule())
                            }
                        }
                    }
                }
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(gym.raidLevelColor.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(gym.raidLevelColor.opacity(0.2), lineWidth: 1)
                }
        )
    }

    // MARK: - Defenders Section

    @ViewBuilder
    private func gymDefendersSection(_ defenders: [PogoMapDefender]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "shield.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(gym.teamColor)
                Text("Défenseurs (\(defenders.count))")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(defenders.indices, id: \.self) { i in
                    defenderCard(defenders[i])
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                }
        )
    }

    @ViewBuilder
    private func defenderCard(_ defender: PogoMapDefender) -> some View {
        VStack(spacing: 8) {
            CachedAsyncImage(
                url: URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/\(defender.pokemonId).png"),
                size: 60, contentMode: .fit
            )
            .frame(width: 60, height: 60)
            .background(.ultraThinMaterial, in: Circle())
            .clipShape(.circle)

            VStack(spacing: 2) {
                Text(pokemonName(defender.pokemonId))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text("PC: \(defender.cpNow)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                let motivPct = Int((defender.motivationNow ?? 0) * 100)
                Text("\(motivPct)%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(motivPct > 50 ? .green : .red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((motivPct > 50 ? Color.green : Color.red).opacity(0.1), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
                }
        )
    }

    // MARK: - Stats Section

    @ViewBuilder
    private var gymStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.purple)
                Text("Statistiques")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Spacer()
            }
            VStack(spacing: 12) {
                HStack {
                    Label("PC Total", systemImage: "star.fill")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                    Spacer()
                    Text("\(gym.totalCp ?? 0)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                }
                HStack {
                    Label("Places libres", systemImage: "person.3.fill")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                    Spacer()
                    Text("\(gym.availableSlots ?? 0)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                }
        )
    }

    // MARK: - Actions Section

    @ViewBuilder
    private var gymActionsSection: some View {
        Button("Itinéraire à pied", systemImage: "figure.walk") {
            directionsTrigger += 1
            let destination = MKMapItem(
                location: CLLocation(latitude: gym.lat, longitude: gym.lon),
                address: nil
            )
            destination.name = gym.name ?? "Arène"
            destination.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
            ])
        }
        .font(.system(size: 16, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .shadow(color: Color.blue.opacity(0.3), radius: 4, y: 2)
    }

    // MARK: - Helpers

    private func raidCountdown(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return "\(m):\(s.formatted(.number.precision(.integerLength(2))))"
    }

    private func coordinateText(latitude: Double, longitude: Double) -> String {
        "\(latitude.formatted(.number.precision(.fractionLength(5)))), \(longitude.formatted(.number.precision(.fractionLength(5))))"
    }
}
