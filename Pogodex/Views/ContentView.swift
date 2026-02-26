import SwiftUI

/// Vue principale du Pokédex — liste des Pokémon par région.
struct ContentView: View {
    @ObservedObject var viewModel: PogodexViewModel
    @AppStorage("app_language") private var appLanguage: String = "English"
    @State private var filterMode: SearchView.FilterMode = .all
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            Group {
                if let error = viewModel.errorMessage, viewModel.pokemons.isEmpty {
                    errorView(error)
                } else {
                    mainContent
                }
            }
            .navigationTitle("Pogodex")
            .refreshable {
                // Vider agressivement le cache d'images
                await MainActor.run {
                    autoreleasepool {
                        ImageCache.shared.clearCache()
                    }
                }
                
                // Petit délai pour laisser la mémoire se libérer
                try? await Task.sleep(for: .milliseconds(100))
                
                await viewModel.fetchPokemon()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // Bouton Filtre à gauche
                    Menu {
                        Picker("Filtrer par", selection: $filterMode) {
                            ForEach(SearchView.FilterMode.allCases) { mode in
                                Label(mode.rawValue, systemImage: iconForMode(mode))
                                    .tag(mode)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 16))
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    // Bouton Paramètres à droite
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16))
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(viewModel: viewModel)
            }
        }
    }
    
    private func iconForMode(_ mode: SearchView.FilterMode) -> String {
        switch mode {
        case .all: return "circle.grid.2x2"
        case .captured: return "checkmark.circle"
        case .missing: return "circle"
        }
    }
    
    // MARK: - Loading
    
    // MARK: - Error
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Réessayer") {
                Task { await viewModel.fetchPokemon() }
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Capsule().fill(.blue))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Main Content
    
    private var hasVisiblePokemon: Bool {
        for gen in viewModel.generations {
            let pokemonsInGen = viewModel.groupedPokemons[gen] ?? []
            let hasMatch = pokemonsInGen.contains { pokemon in
                switch filterMode {
                case .all: return true
                case .captured: return viewModel.countCaptured(for: pokemon) > 0
                case .missing: return viewModel.countCaptured(for: pokemon) == 0
                }
            }
            if hasMatch { return true }
        }
        return false
    }
    
    private var mainContent: some View {
        Group {
            if !hasVisiblePokemon {
                emptyStateView
                    .transition(.opacity.animation(.easeInOut(duration: 0.25)))
            } else {
                ScrollView {
                    // ⚡ Un seul LazyVGrid pour TOUT le contenu.
                    // AVANT : LazyVStack > LazyVGrid par génération → quand une gen
                    // scrollait à l'écran, TOUTES ses ~150 cellules se chargeaient
                    // d'un coup et la RAM ne descendait jamais.
                    // MAINTENANT : chaque cellule est individuellement lazy.
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(viewModel.generations, id: \.self) { gen in
                            // Filtrage des Pokémon pour cette génération
                            let pokemonsInGen = viewModel.groupedPokemons[gen] ?? []
                            let filteredInGen = pokemonsInGen.filter { pokemon in
                                switch filterMode {
                                case .all: return true
                                case .captured: return viewModel.countCaptured(for: pokemon) > 0
                                case .missing: return viewModel.countCaptured(for: pokemon) == 0
                                }
                            }
                            
                            if !filteredInGen.isEmpty {
                                Section {
                                    ForEach(filteredInGen, id: \.id) { pokemon in
                                        pokemonGridCell(pokemon: pokemon)
                                    }
                                } header: {
                                    regionHeader(for: gen)
                                        .frame(minHeight: 1) // Empêche le layout pass à hauteur 0
                                }
                            }
                        }
                    }
                    .animation(.default, value: filterMode)
                    .padding(.horizontal, 12)
                    .padding(.top, -8) // Réduire l'espace sous le titre
                    .padding(.bottom, 24) // Un peu d'espace en bas pour ne pas coller à la TabBar
                }
                .background(Color(UIColor.systemGroupedBackground))
                .transition(.opacity.animation(.easeInOut(duration: 0.25)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: hasVisiblePokemon)
        .navigationDestination(for: String.self) { pokemonId in
            if let pokemon = viewModel.pokemons.first(where: { $0.id == pokemonId }) {
                PokemonDetailView(pokemon: pokemon, viewModel: viewModel)
            }
        }
    }
    
    private var emptyStateView: some View {
        Group {
            if viewModel.isLoading {
                Color.clear
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        Image(systemName: filterMode == .captured ? "tray" : "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        
                        Text(emptyStateMessage)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity)
                    .containerRelativeFrame(.vertical)
                }
                .background(Color(UIColor.systemGroupedBackground))
            }
        }
    }
    
    private var emptyStateMessage: String {
        switch filterMode {
        case .all: return "Aucun Pokémon trouvé."
        case .captured: return "Vous n'avez encore capturé aucun Pokémon."
        case .missing: return "Félicitations ! Vous avez capturé tous les Pokémon."
        }
    }
    
    // MARK: - Grid
    
    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 100), spacing: 12)]
    }
    
    private func pokemonGridCell(pokemon: Pokemon) -> some View {
        let count = viewModel.countCaptured(for: pokemon)
        let shiny = viewModel.hasCapturedShiny(for: pokemon)
        let lucky = viewModel.hasCapturedLucky(for: pokemon)
        let gigantamax = viewModel.hasCapturedGigantamax(for: pokemon)
        let gigantamaxShiny = viewModel.hasCapturedGigantamaxShiny(for: pokemon)
        
        // NavigationLink(value:) → PokemonDetailView créé UNIQUEMENT au tap
        return NavigationLink(value: pokemon.id) {
            PokemonCell(
                pokemon: pokemon,
                capturedCount: count,
                hasShiny: shiny,
                hasLucky: lucky,
                hasGigantamax: gigantamax,
                hasGigantamaxShiny: gigantamaxShiny
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Region Header
    
    private func regionHeader(for gen: Int) -> some View {
        let total = viewModel.totalPokemonCount(for: gen)
        let captured = viewModel.capturedPokemonCount(for: gen)
        let progress = total > 0 ? Double(captured) / Double(total) : 0
        
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: regionIcon(for: gen))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(regionColor(for: gen))
                
                Text(viewModel.regionName(for: gen))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                
                Spacer()
                
                Text("\(captured)/\(total)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            
            ProgressView(value: progress)
                .tint(regionColor(for: gen))
        }
        .padding(.horizontal, 0)
        .padding(.top, 20)
        .padding(.bottom, 6)
    }
    
    /// SF Symbol pour chaque région.
    private func regionIcon(for gen: Int) -> String {
        switch gen {
        case 1: return "leaf.fill"
        case 2: return "bolt.fill"
        case 3: return "drop.fill"
        case 4: return "diamond.fill"
        case 5: return "shield.fill"
        case 6: return "building.2.fill"
        case 7: return "sun.max.fill"
        case 8: return "crown.fill"
        case 9: return "sparkles"
        default: return "star.fill"
        }
    }
    
    /// Couleur thème pour chaque région.
    private func regionColor(for gen: Int) -> Color {
        switch gen {
        case 1: return .green
        case 2: return .yellow
        case 3: return .blue
        case 4: return .purple
        case 5: return .gray
        case 6: return .pink
        case 7: return .orange
        case 8: return .cyan
        case 9: return .indigo
        default: return .mint
        }
    }
}

// MARK: - Search View

/// Vue de recherche (onglet Search natif Liquid Glass).
struct SearchView: View {
    @ObservedObject var viewModel: PogodexViewModel
    @AppStorage("app_language") private var appLanguage: String = "English"
    @State private var searchText = ""
    @State private var filterMode: FilterMode = .all
    
    enum FilterMode: String, CaseIterable, Identifiable {
        case all = "Tous"
        case captured = "Capturés"
        case missing = "Manquants"
        
        var id: String { self.rawValue }
    }
    
    private var filteredPokemons: [Pokemon] {
        // Filtrage initial par possession
        let baseList: [Pokemon]
        switch filterMode {
        case .all:
            baseList = viewModel.pokemons
        case .captured:
            baseList = viewModel.pokemons.filter { viewModel.countCaptured(for: $0) > 0 }
        case .missing:
            baseList = viewModel.pokemons.filter { viewModel.countCaptured(for: $0) == 0 }
        }
        
        guard !searchText.isEmpty else { return baseList }
        let query = searchText.lowercased()
        
        if query.hasPrefix("#"), let num = Int(query.dropFirst()) {
            return baseList.filter { $0.dexNr == num }
        }
        
        let currentLang = localizedLanguageKey()
        
        return baseList.filter { pokemon in
            // Ignorer les accents et la casse pour le nom
            let nameMatch = pokemon.name.folding(options: .diacriticInsensitive, locale: .current)
                .lowercased()
                .contains(query.folding(options: .diacriticInsensitive, locale: .current))
            
            let dexMatch = String(pokemon.dexNr).contains(query)
            
            // Recherche par type (uniquement dans la langue actuelle)
            let primaryTypeMatch = pokemon.primaryType?.names[currentLang]?
                .folding(options: .diacriticInsensitive, locale: .current)
                .lowercased()
                .contains(query.folding(options: .diacriticInsensitive, locale: .current)) ?? false
                
            let secondaryTypeMatch = pokemon.secondaryType?.names[currentLang]?
                .folding(options: .diacriticInsensitive, locale: .current)
                .lowercased()
                .contains(query.folding(options: .diacriticInsensitive, locale: .current)) ?? false
            
            // Recherche par région
            let regionMatch = viewModel.regionName(for: pokemon.generation)
                .folding(options: .diacriticInsensitive, locale: .current)
                .lowercased()
                .contains(query.folding(options: .diacriticInsensitive, locale: .current))
            
            return nameMatch || dexMatch || primaryTypeMatch || secondaryTypeMatch || regionMatch
        }
    }
    
    private var groupedFilteredPokemons: [(Int, [Pokemon])] {
        let grouped = Dictionary(grouping: filteredPokemons, by: { $0.generation })
        return grouped.sorted { $0.key < $1.key }
    }
    
    var body: some View {
        NavigationStack {
            searchContent
                .background(Color(UIColor.systemGroupedBackground))
                .navigationTitle("Recherche")
        }
        .searchable(
            text: $searchText,
            placement: .automatic,
            prompt: "Nom ou numéro (#25)..."
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    // Bouton Filtre
                    Menu {
                        Picker("Filtrer par", selection: $filterMode) {
                            ForEach(FilterMode.allCases) { mode in
                                Label(mode.rawValue, systemImage: iconForMode(mode))
                                    .tag(mode)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 16))
                    }
                    
                        // Bouton Paramètres
                        /*
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 16))
                        }
                        */
                    }
                }
            }
    }
    
    private func iconForMode(_ mode: FilterMode) -> String {
        switch mode {
        case .all: return "circle.grid.2x2"
        case .captured: return "checkmark.circle"
        case .missing: return "circle"
        }
    }
    
    // MARK: - Sub-views (split for compiler type-check)
    
    @ViewBuilder
    private var searchContent: some View {
        if searchText.isEmpty {
            emptyStateView
        } else if filteredPokemons.isEmpty {
            noResultsView
        } else {
            searchResultsGrid
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text("Rechercher un Pokémon")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Text("Par nom ou numéro (#25)")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Aucun résultat")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var searchResultsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                ForEach(groupedFilteredPokemons, id: \.0) { gen, pokemons in
                    Section {
                        ForEach(pokemons) { pokemon in
                            searchResultCell(for: pokemon)
                        }
                    } header: {
                        regionHeader(for: gen)
                            .frame(minHeight: 1)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Region Header (Dupliqué de ContentView pour la recherche)
    
    private func regionHeader(for gen: Int) -> some View {
        let total = viewModel.totalPokemonCount(for: gen)
        let captured = viewModel.capturedPokemonCount(for: gen)
        let progress = total > 0 ? Double(captured) / Double(total) : 0
        
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: regionIcon(for: gen))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(regionColor(for: gen))
                
                Text(viewModel.regionName(for: gen))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                
                Spacer()
                
                Text("\(captured)/\(total)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            
            ProgressView(value: progress)
                .tint(regionColor(for: gen))
        }
        .padding(.horizontal, 0)
        .padding(.top, 20)
        .padding(.bottom, 6)
    }
    
    private func regionIcon(for gen: Int) -> String {
        switch gen {
        case 1: return "leaf.fill"
        case 2: return "bolt.fill"
        case 3: return "drop.fill"
        case 4: return "diamond.fill"
        case 5: return "shield.fill"
        case 6: return "building.2.fill"
        case 7: return "sun.max.fill"
        case 8: return "crown.fill"
        case 9: return "sparkles"
        default: return "star.fill"
        }
    }
    
    private func regionColor(for gen: Int) -> Color {
        switch gen {
        case 1: return .green
        case 2: return .yellow
        case 3: return .blue
        case 4: return .purple
        case 5: return .gray
        case 6: return .pink
        case 7: return .orange
        case 8: return .cyan
        case 9: return .indigo
        default: return .mint
        }
    }
    
    private func searchResultCell(for pokemon: Pokemon) -> some View {
        let count = viewModel.countCaptured(for: pokemon)
        let shiny = viewModel.hasCapturedShiny(for: pokemon)
        let lucky = viewModel.hasCapturedLucky(for: pokemon)
        let gigantamax = viewModel.hasCapturedGigantamax(for: pokemon)
        let gigantamaxShiny = viewModel.hasCapturedGigantamaxShiny(for: pokemon)
        
        return NavigationLink(destination: PokemonDetailView(pokemon: pokemon, viewModel: viewModel)) {
            PokemonCell(
                pokemon: pokemon,
                capturedCount: count,
                hasShiny: shiny,
                hasLucky: lucky,
                hasGigantamax: gigantamax,
                hasGigantamaxShiny: gigantamaxShiny
            )
        }
        .buttonStyle(.plain)
    }
}
