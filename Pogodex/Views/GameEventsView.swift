import SwiftUI

struct GameEventsView: View {
    @StateObject private var eventsViewModel = GameEventsViewModel()
    @ObservedObject var viewModel: PogodexViewModel
    @State private var selectedEvent: LeekDuckEvent?
    @State private var selectedSeason: LeekDuckEvent?
    @State private var selectedRaid: LeekDuckRaid?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        modeSelector
                        
                        if eventsViewModel.isLoading && !eventsViewModel.hasAnyContent {
                            loadingView
                        } else if let error = eventsViewModel.errorMessage, !eventsViewModel.hasAnyContent {
                            errorView(message: error)
                        } else {
                            contentForCurrentMode
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .refreshable {
                    await eventsViewModel.fetchAll()
                }
            }
            .navigationTitle("Événements")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await eventsViewModel.fetchAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task {
                await eventsViewModel.fetchAll()
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailSheet(event: event)
            }
            .sheet(item: $selectedSeason) { season in
                SeasonDetailSheet(season: season)
            }
            .sheet(item: $selectedRaid) { raid in
                raidDetailSheet(raid)
            }
        }
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(GameEventsViewModel.Mode.allCases) { mode in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            eventsViewModel.mode = mode
                        }
                    } label: {
                        Text(mode.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(eventsViewModel.mode == mode ? 
                                          LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                          LinearGradient(colors: [Color(.tertiarySystemFill)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            )
                            .foregroundStyle(eventsViewModel.mode == mode ? .white : .primary)
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentForCurrentMode: some View {
        if eventsViewModel.isCurrentModeEmpty() {
            emptyState
        } else {
            switch eventsViewModel.mode {
            case .overview: overviewContent
            case .quests: questsContent
            case .raids: raidsContent
            case .eggs: eggsContent
            case .rocket: rocketContent
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            Text("Rien ici pour le moment")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            
            Text("Tire vers le bas pour rafraîchir")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Chargement…")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 80)
    }

    // MARK: - Overview

    private var overviewContent: some View {
        LazyVStack(spacing: 20) {
            // Saison en cours
            if let activeSeason = eventsViewModel.activeSeason {
                Button { selectedSeason = activeSeason } label: {
                    seasonCard(activeSeason)
                }
                .buttonStyle(.plain)
            }

            // Événements actifs
            if !eventsViewModel.activeEvents.isEmpty {
                VStack(spacing: 16) {
                    HStack {
                        Circle()
                            .fill(.orange)
                            .frame(width: 8, height: 8)
                        Text("En ce moment")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Spacer()
                    }
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(eventsViewModel.activeEvents.prefix(4)) { event in
                            Button { selectedEvent = event } label: {
                                eventCardCompact(event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Événements à venir
            if !eventsViewModel.upcomingEvents.isEmpty {
                VStack(spacing: 16) {
                    HStack {
                        Circle()
                            .fill(.blue)
                            .frame(width: 8, height: 8)
                        Text("À venir")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Spacer()
                    }
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(eventsViewModel.upcomingEvents.prefix(4)) { event in
                            Button { selectedEvent = event } label: {
                                eventCardCompact(event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 20)
    }

    // MARK: - Overview Helpers

    private func eventCardCompact(_ event: LeekDuckEvent) -> some View {
        VStack(spacing: 8) {
            // Icône
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                event.isUpcoming ? Color.blue.opacity(0.15) : Color.orange.opacity(0.15),
                                event.isUpcoming ? Color.blue.opacity(0.08) : Color.orange.opacity(0.08)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: event.iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(event.isUpcoming ? .blue : .orange)
            }
            
            // Texte
            VStack(spacing: 4) {
                Text(event.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(event.timeRemainingText)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(event.isUpcoming ? .blue : .orange)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
                )
        )
    }

    private func seasonCard(_ season: LeekDuckEvent) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green.opacity(0.15), Color.green.opacity(0.08)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.green)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(season.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("\(season.daysRemaining) jours restants")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            
            // Progress bar
            VStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green.opacity(0.1))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.green, .mint]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * season.progressPercentage, height: 6)
                    }
                }
                .frame(height: 6)
                
                HStack {
                    Text("\(Int(season.progressPercentage * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                    Spacer()
                    Text("Jusqu'au \(season.endDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.green.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Quests

    private var questsContent: some View {
        LazyVStack(spacing: 16) {
            ForEach(eventsViewModel.researches) { quest in
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.blue)
                            .frame(width: 24, height: 24)
                        
                        Text(quest.text)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .lineLimit(2)
                    }

                    if !quest.rewards.isEmpty {
                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                ForEach(quest.rewards) { reward in
                                    HStack(spacing: 6) {
                                        CachedAsyncImage(
                                            url: URL(string: reward.image),
                                            size: 20,
                                            contentMode: .fit
                                        )
                                        Text(reward.name)
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .lineLimit(1)
                                        if reward.canBeShiny == true {
                                            Image(systemName: "sparkles")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(.yellow)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color(.tertiarySystemGroupedBackground))
                                    )
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        .scrollIndicators(.hidden)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
                        )
                )
            }
        }
        .padding(.vertical, 20)
    }

    // MARK: - Raids

    private var raidsContent: some View {
        LazyVStack(spacing: 16) {
            let grouped = Dictionary(grouping: eventsViewModel.raidsList, by: { $0.tier })
            let sortedKeys = grouped.keys.sorted { raidTierOrder($0) < raidTierOrder($1) }

            ForEach(sortedKeys, id: \.self) { tier in
                if let raids = grouped[tier] {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: raidTierIcon(tier))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(raidTierColor(tier))
                            Text(tier)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                            Spacer()
                            Text("\(raids.count) boss")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)

                        ScrollView(.horizontal) {
                            HStack(spacing: 12) {
                                ForEach(raids) { raid in
                                    Button {
                                        selectedRaid = raid
                                    } label: {
                                        raidBossCard(raid)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .scrollIndicators(.hidden)
                    }
                }
            }
        }
        .padding(.vertical, 12)
    }

    private func raidBossCard(_ raid: LeekDuckRaid) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                CachedAsyncImage(url: URL(string: raid.image), size: 80, contentMode: .fit)
                    .frame(width: 80, height: 80)

                if raid.canBeShiny == true {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.yellow)
                        .padding(4)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }

            Text(raid.name)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if let cp = raid.combatPower {
                VStack(spacing: 2) {
                    Text("PC 100%: \(cp.normal.max)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.blue)
                    Text("Boost: \(cp.boosted.max)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.orange)
                }
            }
        }
        .frame(width: 120)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }

    private func raidDetailSheet(_ raid: LeekDuckRaid) -> some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        CachedAsyncImage(url: URL(string: raid.image), size: 90, contentMode: .fit)
                            .frame(width: 90, height: 90)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(raid.name)
                                .font(.system(size: 22, weight: .bold, design: .rounded))

                            Text(raid.tier)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(raidTierColor(raid.tier))

                            if raid.canBeShiny == true {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(.yellow)
                                    Text("Peut etre Shiny")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                if let cp = raid.combatPower {
                    Section("PC de capture (100% IV)") {
                        HStack {
                            Image(systemName: "bolt.shield.fill")
                                .foregroundStyle(.red)
                            Text("PC Normal")
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            Text("\(cp.normal.min) - \(cp.normal.max)")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.blue)
                        }
                        HStack {
                            Image(systemName: "cloud.sun.fill")
                                .foregroundStyle(.orange)
                            Text("PC Booste Meteo")
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            Text("\(cp.boosted.min) - \(cp.boosted.max)")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.orange)
                        }
                    }

                    Section("PC Parfait (15/15/15)") {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text("100% IV Normal")
                            Spacer()
                            Text("\(cp.normal.max)")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(.blue)
                        }
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.orange)
                            Text("100% IV Booste")
                            Spacer()
                            Text("\(cp.boosted.max)")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(.orange)
                        }
                    }
                }

                if let types = raid.types, !types.isEmpty {
                    Section("Types") {
                        HStack(spacing: 8) {
                            ForEach(types, id: \.name) { type in
                                HStack(spacing: 4) {
                                    if let img = type.image, let url = URL(string: img) {
                                        CachedAsyncImage(url: url, size: 20, contentMode: .fit)
                                            .frame(width: 20, height: 20)
                                    }
                                    Text(type.name)
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.tertiarySystemFill), in: Capsule())
                            }
                        }
                    }
                }
            }
            .navigationTitle("Raid Boss")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { selectedRaid = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Raid Helpers

    private func raidTierOrder(_ tier: String) -> Int {
        let t = tier.lowercased()
        if t.contains("mega") || t.contains("ultra") { return 0 }
        if t.contains("5") || t.contains("legendary") { return 1 }
        if t.contains("shadow") { return 2 }
        if t.contains("3") { return 3 }
        if t.contains("1") { return 4 }
        return 5
    }

    private func raidTierIcon(_ tier: String) -> String {
        let t = tier.lowercased()
        if t.contains("mega") { return "flame.fill" }
        if t.contains("5") || t.contains("legendary") { return "crown.fill" }
        if t.contains("shadow") { return "moon.fill" }
        if t.contains("3") { return "bolt.shield.fill" }
        return "shield.fill"
    }

    private func raidTierColor(_ tier: String) -> Color {
        let t = tier.lowercased()
        if t.contains("mega") { return .purple }
        if t.contains("5") || t.contains("legendary") { return .yellow }
        if t.contains("shadow") { return .indigo }
        if t.contains("3") { return .orange }
        return .blue
    }

    // MARK: - Eggs

    private var eggsContent: some View {
        LazyVStack(spacing: 20) {
            let grouped = Dictionary(grouping: eventsViewModel.eggs, by: { $0.eggType })
            let sortedKeys = grouped.keys.sorted()

            ForEach(sortedKeys, id: \.self) { type in
                if let eggs = grouped[type] {
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "egg.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(eggColor(for: type))
                            Text("Œufs \(type)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Spacer()
                        }

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 10) {
                            ForEach(eggs) { egg in
                                VStack(spacing: 6) {
                                    CachedAsyncImage(
                                        url: URL(string: egg.image),
                                        size: 32,
                                        contentMode: .fit
                                    )
                                    .frame(height: 32)

                                    Text(egg.name)
                                        .font(.system(size: 9, weight: .medium, design: .rounded))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .frame(maxWidth: .infinity)

                                    if egg.canBeShiny == true {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundStyle(.yellow)
                                    }
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(.tertiarySystemGroupedBackground))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
                                        )
                                )
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.secondarySystemGroupedBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
                            )
                    )
                }
            }
        }
        .padding(.vertical, 20)
    }

    private func eggColor(for type: String) -> Color {
        if type.contains("2") { return .green }
        if type.contains("5") { return .orange }
        if type.contains("7") { return .pink }
        if type.contains("10") { return .purple }
        if type.contains("12") { return .red }
        return .green
    }

    // MARK: - Rocket

    private var rocketContent: some View {
        LazyVStack(spacing: 16) {
            ForEach(eventsViewModel.rockets) { rocket in
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.purple.opacity(0.15), Color.purple.opacity(0.08)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.purple)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rocket.name)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Text(rocket.title)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 12) {
                        rocketSlot(title: "1", pokemon: rocket.firstPokemon)
                        rocketSlot(title: "2", pokemon: rocket.secondPokemon)
                        rocketSlot(title: "3", pokemon: rocket.thirdPokemon)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
                        )
                )
            }
        }
        .padding(.vertical, 20)
    }

    private func rocketSlot(title: String, pokemon: [LeekDuckRocketPokemon]?) -> some View {
        VStack(spacing: 8) {
            Text("\(title)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)

            if let pokemon, !pokemon.isEmpty {
                VStack(spacing: 4) {
                    ForEach(pokemon) { mon in
                        CachedAsyncImage(url: URL(string: mon.image), size: 28, contentMode: .fit)
                            .frame(height: 28)
                    }
                }
            } else {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.tertiary)
                    .frame(height: 28)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            VStack(spacing: 8) {
                Text("Connexion impossible")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text(message)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                Task { await eventsViewModel.fetchAll() }
            } label: {
                Text("Réessayer")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 80)
    }
}

// MARK: - Event Detail Sheet

struct EventDetailSheet: View {
    let event: LeekDuckEvent
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    eventImageSection
                    eventInfoSection
                    eventDatesSection
                    if event.isActive { eventProgressSection }
                    eventLinkSection
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Détail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var eventImageSection: some View {
        if let imageURL = event.image, let url = URL(string: imageURL) {
            CachedAsyncImage(url: url, size: 200, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.tertiarySystemGroupedBackground))
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var eventInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(event.eventType.replacingOccurrences(of: "-", with: " ").capitalized)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.accentColor))

            Text(event.name)
                .font(.system(size: 22, weight: .bold, design: .rounded))

            if !event.heading.isEmpty {
                Text(event.heading)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var eventDatesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Dates", systemImage: "calendar")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Début")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.tertiary)
                    Text(event.startDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                Divider().frame(height: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fin")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.tertiary)
                    Text(event.endDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
                )
        )
    }

    private var eventProgressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Progression", systemImage: "chart.line.uptrend.xyaxis")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.orange.opacity(0.12))
                        .frame(height: 6)
                    Capsule()
                        .fill(Color.orange)
                        .frame(width: geo.size.width * event.progressPercentage, height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(Int(event.progressPercentage * 100))% terminé")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                Spacer()
                Text(event.timeRemainingText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
                )
        )
    }

    @ViewBuilder
    private var eventLinkSection: some View {
        if let link = event.link, let url = URL(string: link) {
            Link(destination: url) {
                HStack {
                    Image(systemName: "safari")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Voir sur LeekDuck")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Color.accentColor)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.accentColor.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }
}

// MARK: - Season Detail Sheet

struct SeasonDetailSheet: View {
    let season: LeekDuckEvent
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    seasonImageSection
                    seasonInfoSection
                    seasonProgressSection
                    seasonDatesSection
                    seasonLinkSection
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Saison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var seasonImageSection: some View {
        if let imageURL = season.image, let url = URL(string: imageURL) {
            CachedAsyncImage(url: url, size: 240, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.green.opacity(0.05))
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var seasonInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Saison en cours")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.green)

            Text(season.name)
                .font(.system(size: 24, weight: .bold, design: .rounded))

            if !season.heading.isEmpty {
                Text(season.heading)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var seasonProgressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Progression de la saison", systemImage: "chart.line.uptrend.xyaxis")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.green.opacity(0.12))
                        .frame(height: 8)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * season.progressPercentage, height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(Int(season.progressPercentage * 100))%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(season.daysRemaining) jours restants")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Text("Fin le \(season.endDate.formatted(date: .long, time: .omitted))")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
                )
        )
    }

    private var seasonDatesSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Début")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tertiary)
                Text(season.startDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemGroupedBackground))
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("Fin")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tertiary)
                Text(season.endDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    @ViewBuilder
    private var seasonLinkSection: some View {
        if let link = season.link, let url = URL(string: link) {
            Link(destination: url) {
                HStack {
                    Image(systemName: "safari")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Détails sur LeekDuck")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.green)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.green.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.green.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }
}
