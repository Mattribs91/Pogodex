import SwiftUI

struct PokemonDetailView: View {
    private struct ZoomedImageTarget: Identifiable {
        let id: URL
    }

    let pokemon: Pokemon
    @ObservedObject var viewModel: PogodexViewModel
    let showCaptureControls: Bool

    init(pokemon: Pokemon, viewModel: PogodexViewModel, showCaptureControls: Bool = true) {
        self.pokemon = pokemon
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.showCaptureControls = showCaptureControls
    }
    
    @State private var displayMode: DisplayMode = .normal
    @State private var selectedForm: AssetForm? = nil
    @State private var zoomedImage: ZoomedImageTarget?
    @State private var searchText: String = ""
    @State private var headerImage: Image? = nil
    @State private var hapticTrigger = 0

    @AppStorage("app_store_mode") private var isAppStoreMode: Bool = false
    
    enum DisplayMode: String, CaseIterable, Identifiable {
        case normal = "Normal"
        case shiny = "Shiny ✨"
        var id: String { self.rawValue }
    }
    
    /// Vérifie si au moins une variante a un shiny.
    private var hasAnyShiny: Bool {
        if pokemon.assetForms?.contains(where: { $0.shinyImage != nil }) == true {
            return true
        }
        if pokemon.assets?.shinyImage != nil {
            return true
        }
        return pokemon.officialShinyArtworkUrl != nil
    }

    private var gigamaxForm: AssetForm? {
        guard pokemon.isGigantamax else { return nil }
        return AssetForm(form: "GIGANTAMAX", costume: nil, image: pokemon.assets?.image, shinyImage: pokemon.assets?.shinyImage)
    }
    
    private var eternamaxForm: AssetForm? {
        guard pokemon.isEternamax else { return nil }
        // 1. Chercher dans assetForms (la forme ETERNAMAX y existe avec ses images)
        if let existing = pokemon.assetForms?.first(where: { $0.form == "ETERNAMAX" }) {
            return existing
        }
        // 2. Chercher dans regionForms via formId (l'id interne est "ETERNATUS", pas "ETERNATUS_ETERNAMAX")
        if let regionForm = pokemon.regionFormsList.first(where: { ($0.formId ?? $0.id).contains("ETERNAMAX") }) {
            return AssetForm(
                form: "ETERNAMAX",
                costume: nil,
                image: regionForm.assets?.image,
                shinyImage: regionForm.assets?.shinyImage
            )
        }
        // 3. Fallback : forme vide, le mapping HD prendra le relais
        return AssetForm(form: "ETERNAMAX", costume: nil, image: nil, shinyImage: nil)
    }

    private var hasEvolutionSection: Bool {
        pokemon.evolutions?.isEmpty == false
    }

    private var hasMegaSection: Bool {
        !pokemon.megaEvolutionsList.isEmpty
    }

    private var regionalFormsForDisplay: [RegionForm] {
        pokemon.regionFormsList.filter { !isEternamaxRegionForm($0) }
    }

    private var hasRegionalSection: Bool {
        !regionalFormsForDisplay.isEmpty
    }

    private var hasVariantsSection: Bool {
        if let forms = pokemon.assetForms {
            return !baseVariantForms(from: forms).isEmpty
        }
        return false
    }

    private var hasTopSectionGroup: Bool {
        hasEvolutionSection || hasMegaSection
    }

    /// URL de l'image affichée en haut selon forme sélectionnée + mode.
    private var headerImageURL: URL? {
        if let form = selectedForm {
            return pokemon.highResImageURL(for: form, shiny: displayMode == .shiny)
        }
        
        // Pour les Megas, utiliser directement le mapping
        if let megaID = Pokemon.megaMapping[pokemon.id] {
            let path = displayMode == .shiny ? "shiny/" : ""
            return URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/\(path)\(megaID).png")
        }
        
        if displayMode == .shiny {
            return pokemon.officialShinyArtworkUrl ?? pokemon.officialArtworkUrl
        }
        
        return pokemon.officialArtworkUrl
    }

    private func officialArtworkUrl(for dexNr: Int, shiny: Bool) -> URL? {
        let path = shiny
            ? "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/shiny/\(dexNr).png"
            : "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/\(dexNr).png"
        return URL(string: path)
    }

    private func megaOfficialArtworkUrl(for mega: MegaEvolution, basePokemonDexNr: Int, shiny: Bool) -> URL? {
        let path = shiny ? "shiny/" : ""
        return URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/\(path)\(basePokemonDexNr).png")
    }

    private func isGigantamaxForm(_ form: AssetForm?) -> Bool {
        guard let formName = form?.form else { return false }
        return formName == "GIGANTAMAX" || formName == "GIGANTAMAX_MEGA" || formName == "ETERNAMAX"
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Fond qui couvre TOUT l'écran
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            LinearGradient(
                colors: [
                    themeColor.opacity(0.35),
                    themeColor.opacity(0.15),
                    themeColor.opacity(0.05),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 800)
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    
                    // ── Sections d'information ──
                    VStack(spacing: 12) {
                        if hasTopSectionGroup {
                            sectionContainer {
                                VStack(spacing: 12) {
                                    if hasEvolutionSection {
                                        evolutionChainContent
                                    }
                                    
                                    if hasMegaSection {
                                        megaEvolutionsContent
                                    }
                                }
                            }
                        }
                        
                        // ── Stats & PC ──
                        if pokemon.stats != nil {
                            sectionContainer {
                                statsAndCPContent
                            }
                        }
                        
                        if pokemon.isNotAvailable {
                            notAvailableView
                                .padding(.bottom, 20)
                        } else if hasVariantsSection {
                            sectionContainer {
                                variantsContent
                            }
                            .padding(.bottom, 20) // Ajout d'espace sous la section variantes
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 70)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $zoomedImage) { zoomedImage in
            NavigationStack {
                ImageZoomView(url: zoomedImage.id) {
                    self.zoomedImage = nil
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Fermer", systemImage: "xmark") { self.zoomedImage = nil }
                    }
                }
            }
            .presentationDetents([.fraction(0.68)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(.clear)
            .interactiveDismissDisabled(false)
        }
    }
    
    // MARK: - En-tête
    
    private var headerSection: some View {
        VStack(spacing: 10) {
            // ── Image principale ──
            Group {
                if let url = headerImageURL {
                    Button {
                        zoomedImage = ZoomedImageTarget(id: url)
                    } label: {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .onAppear { headerImage = image }
                                    #if canImport(UIKit)
                                    .modifier(PixelatedImageModifier(url: url, isAppStoreMode: isAppStoreMode))
                                    #endif
                            } else if phase.error != nil {
                                placeholderImage
                            } else {
                                if let headerImage {
                                    headerImage
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        #if canImport(UIKit)
                                        .modifier(PixelatedImageModifier(url: url, isAppStoreMode: isAppStoreMode))
                                        #endif
                                } else {
                                    ProgressView()
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .id(url) // Force SwiftUI à recréer la vue au changement d'URL (normal ↔ shiny)
                    .frame(width: 320, height: 320)
                } else {
                    placeholderImage
                        .frame(width: 320, height: 320)
                }
            }
            .transition(.opacity)
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            .frame(maxWidth: .infinity)
            .padding(.top, 100)
            
            // ── Identité ──
            VStack(spacing: 1) {
                Text(pokemon.name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                
                Text("#\(pokemon.dexNr.formatted(.number.precision(.integerLength(3))))")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                
                if let form = selectedForm {
                    Text(form.displayName)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(themeColor)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedForm?.id)
            
            // ── Types (inline, compact) ──
            HStack(spacing: 6) {
                if let pt = pokemon.primaryType {
                    typePillLarge(pt)
                }
                if let st = pokemon.secondaryType {
                    typePillLarge(st)
                }
            }
            
            // ── Localisation Régionale ──
            if let location = regionalLocations[pokemon.dexNr] {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.red)
                    Text(location)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            
            // ── Badge Classe ──
            HStack(spacing: 8) {
                // Badge Légendaire/Fabuleux/Ultra Chimère (toujours affiché si applicable)
                if pokemon.isLegendary {
                    HStack(spacing: 5) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        Text("Légendaire")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                            )
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .glassEffect(.regular, in: .capsule)
                } else if pokemon.isMythic {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        Text("Fabuleux")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing)
                            )
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .glassEffect(.regular, in: .capsule)
                } else if pokemon.isUltraBeast {
                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        Text("Ultra Chimère")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing)
                            )
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .glassEffect(.regular, in: .capsule)
                }
                
                // Badge Gigantamax (cliquable)
                if pokemon.isGigantamax, let gmaxForm = gigamaxForm {
                    let badge = HStack(spacing: 5) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(colors: [.red, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        Text("Gigantamax")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [.red, .pink], startPoint: .leading, endPoint: .trailing)
                            )
                    }
                    
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if selectedForm?.form == gmaxForm.form {
                                selectedForm = nil
                            } else {
                                selectedForm = gmaxForm
                            }
                        }
                    } label: {
                        Group {
                            if selectedForm?.form == gmaxForm.form {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Normal")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                }
                                .foregroundStyle(.primary)
                            } else {
                                badge
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .glassEffect(.regular, in: .capsule)
                }
                
                // Badge Eternamax (cliquable)
                if pokemon.isEternamax, let eternaForm = eternamaxForm {
                    let badge = HStack(spacing: 5) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(colors: [.purple, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        Text("Eternamax")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [.purple, .red], startPoint: .leading, endPoint: .trailing)
                            )
                    }
                    
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if selectedForm?.form == eternaForm.form {
                                selectedForm = nil
                            } else {
                                selectedForm = eternaForm
                            }
                        }
                    } label: {
                        Group {
                            if selectedForm?.form == eternaForm.form {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Normal")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                }
                                .foregroundStyle(.primary)
                            } else {
                                badge
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .glassEffect(.regular, in: .capsule)
                }
            }
            
            // ── Picker Shiny ──
            if hasAnyShiny {
                Picker("Mode", selection: $displayMode.animation(.easeInOut(duration: 0.3))) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 50)
                .padding(.top, 2)
            }
            
            // ── Boutons Capture + Chanceux ──
            standardCaptureButton
        }
        .padding(.bottom, 16)
    }
    
    @ViewBuilder
    private var standardCaptureButton: some View {
        if showCaptureControls && !pokemon.isNotAvailable {
            let targetForm = (selectedForm != nil && isGigantamaxForm(selectedForm)) ? selectedForm : nil
            HStack(spacing: 10) {
                captureControl(
                    count: viewModel.getCaptureCount(pokemon: pokemon, form: targetForm, shiny: displayMode == .shiny),
                    isShiny: displayMode == .shiny,
                    isActive: targetForm != nil,
                    form: targetForm
                )
                
                luckyControl(
                    count: viewModel.getLuckyCount(pokemon: pokemon, form: targetForm, shiny: displayMode == .shiny),
                    isShiny: displayMode == .shiny,
                    form: targetForm
                )
            }
            .padding(.horizontal, 50)
        }
    }
    
    /// Couleur du thème (basée sur le type principal).
    private var themeColor: Color {
        pokemon.typeColor ?? .blue
    }
    
    // MARK: - Local Capture Control (Header)
    @Namespace private var headerAnimationNamespace

    @ViewBuilder
    private func captureControl(count: Int, isShiny: Bool, isActive: Bool, form: AssetForm? = nil) -> some View {
        Group {
            if count > 0 {
                // Mode "Compteur" avec +/-
                HStack(spacing: 0) {
                    // Bouton Moins
                    Button(action: {
                        triggerHaptic()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            let targetForm = form ?? AssetForm.standard
                            viewModel.decrementCapture(pokemon: pokemon, form: targetForm, shiny: isShiny)
                        }
                    }) {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 44, height: 32)
                            .contentShape(Rectangle())
                    }
                    
                    Divider()
                        .overlay(Color.white.opacity(0.5))
                        .padding(.vertical, 4)
                    
                    // Label Central
                    Text("\(count)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .contentTransition(.numericText())
                    
                    Divider()
                        .overlay(Color.white.opacity(0.5))
                        .padding(.vertical, 4)
                    
                    // Bouton Plus
                    Button(action: {
                        triggerHaptic()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            let targetForm = form ?? AssetForm.standard
                            viewModel.incrementCapture(pokemon: pokemon, form: targetForm, shiny: isShiny)
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 44, height: 32)
                            .contentShape(Rectangle())
                    }
                }
                .foregroundStyle(.white)
                .background(
                    Capsule()
                        .fill(isShiny ? Color.orange : Color.blue)
                )
                .matchedGeometryEffect(id: "captureButton", in: headerAnimationNamespace)
            } else {
                // Mode "Capturé" simple
                Button(action: {
                    triggerHaptic()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        let targetForm = form ?? AssetForm.standard
                        viewModel.incrementCapture(pokemon: pokemon, form: targetForm, shiny: isShiny)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "circle")
                            .font(.system(size: 12, weight: .bold))
                        Text("Capturé")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(
                        Capsule()
                            .fill(Color(.tertiarySystemFill))
                    )
                    .matchedGeometryEffect(id: "captureButton", in: headerAnimationNamespace)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: count > 0)
    }

    @ViewBuilder
    private func luckyControl(count: Int, isShiny: Bool, form: AssetForm?) -> some View {
        Group {
            if count > 0 {
                HStack(spacing: 0) {
                    Button(action: {
                        triggerHaptic()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.decrementLucky(pokemon: pokemon, form: form, shiny: isShiny)
                        }
                    }) {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 44, height: 32)
                            .contentShape(Rectangle())
                    }
                    
                    Divider().overlay(Color.black.opacity(0.2)).padding(.vertical, 4)
                    
                    Text("\(count)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .contentTransition(.numericText())
                    
                    Divider().overlay(Color.black.opacity(0.2)).padding(.vertical, 4)
                    
                    Button(action: {
                        triggerHaptic()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.incrementLucky(pokemon: pokemon, form: form, shiny: isShiny)
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 44, height: 32)
                            .contentShape(Rectangle())
                    }
                }
                .foregroundStyle(.black)
                .background(Capsule().fill(Color.yellow))
                .matchedGeometryEffect(id: "luckyButtonHeader", in: headerAnimationNamespace)
            } else {
                Button(action: {
                    triggerHaptic()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.incrementLucky(pokemon: pokemon, form: form, shiny: isShiny)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Chanceux")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(Capsule().fill(Color(.tertiarySystemFill)))
                    .matchedGeometryEffect(id: "luckyButtonHeader", in: headerAnimationNamespace)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: count > 0)
    }

    private func triggerHaptic() {
        hapticTrigger += 1
    }
    
    private var placeholderImage: some View {
        Image(systemName: pokemon.isNotAvailable ? "clock" : "photo")
            .font(.system(size: 50))
            .foregroundStyle(.tertiary)
    }
    
    // MARK: - Stats & PC
    
    private var statsAndCPContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Stats & PC", icon: "chart.bar.fill")
            
            VStack(spacing: 16) {
                // Stats de base
                if let stats = pokemon.stats {
                    VStack(spacing: 8) {
                        if let atk = stats.attack {
                            statBar(label: "Attaque", value: atk, max: 300, color: .red)
                        }
                        if let def = stats.defense {
                            statBar(label: "Defense", value: def, max: 300, color: .blue)
                        }
                        if let sta = stats.stamina {
                            statBar(label: "PV", value: sta, max: 300, color: .green)
                        }
                    }
                }
                
                // PC
                VStack(spacing: 10) {
                    if let cp = pokemon.perfectRaidCP {
                        cpRow(label: "PC Raid (100%)", value: "\(cp)", icon: "bolt.shield.fill", color: .red)
                    }
                    if let cpBoosted = pokemon.perfectRaidBoostedCP {
                        cpRow(label: "PC Raid Booste Meteo (100%)", value: "\(cpBoosted)", icon: "cloud.sun.fill", color: .orange)
                    }
                    if let cpQuest = pokemon.perfectQuestCP {
                        cpRow(label: "PC Quete/Recherche (100%)", value: "\(cpQuest)", icon: "magnifyingglass", color: .purple)
                    }
                    if let cpMax = pokemon.maxCP50 {
                        cpRow(label: "PC Max (Niv.50)", value: "\(cpMax)", icon: "star.fill", color: .yellow)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    private func statBar(label: String, value: Int, max: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .frame(width: 65, alignment: .leading)
                .foregroundStyle(.secondary)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(UIColor.tertiarySystemFill))
                        .frame(height: 8)
                    
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * min(CGFloat(value) / CGFloat(max), 1.0), height: 8)
                }
            }
            .frame(height: 8)
            
            Text("\(value)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .frame(width: 40, alignment: .trailing)
        }
    }
    
    private func cpRow(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 24)
            
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 10))
    }

    // MARK: - Section Container
    
    private func sectionContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Type Pill (Large, pour le header)
    
    private func typePillLarge(_ typeEntry: PokemonTypeEntry) -> some View {
        let key = localizedLanguageKey()
        let name = typeEntry.names[key] ?? typeEntry.names["English"] ?? ""
        
        return Text(name)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(Pokemon.colorForType(typeEntry.type)))
    }

    private func typeIconImage(for typeEntry: PokemonTypeEntry) -> Image? {
        guard let assetName = typeIconAssetName(typeEntry.type) else { return nil }
        #if canImport(UIKit)
        if UIImage(named: assetName) != nil {
            return Image(assetName)
        }
        #endif
        return nil
    }

    private func typeIconAssetName(_ type: String) -> String? {
        guard type.hasPrefix("POKEMON_TYPE_") else { return nil }
        let raw = type.replacingOccurrences(of: "POKEMON_TYPE_", with: "").lowercased()
        guard let first = raw.first else { return nil }
        let name = String(first).uppercased() + raw.dropFirst()
        return "GO_\(name)"
    }
    
    private var classInfo: (String, String, [Color]) {
        if pokemon.isEternamax {
            return ("Eternamax", "arrow.up.left.and.arrow.down.right", [.purple, .red])
        } else if pokemon.isGigantamax {
            return ("Gigantamax", "arrow.up.left.and.arrow.down.right", [.red, .pink])
        } else if pokemon.isLegendary {
            return ("Légendaire", "crown.fill", [.yellow, .orange])
        } else if pokemon.isMythic {
            return ("Fabuleux", "sparkle", [.pink, .purple])
        } else {
            return ("Ultra Chimère", "bolt.fill", [.cyan, .blue])
        }
    }

    // MARK: - Méga-Évolutions (Content)

    private var megaEvolutionsContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Méga-Évolutions", icon: "flame.fill")
            
            VStack(spacing: 8) {
                ForEach(pokemon.megaEvolutionsList) { mega in
                    megaEvolutionRow(mega)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    private func megaEvolutionRow(_ mega: MegaEvolution) -> some View {
        let megaUrl = displayMode == .shiny
            ? (megaOfficialArtworkUrl(for: mega, basePokemonDexNr: pokemon.dexNr, shiny: true)
                ?? mega.highResShinyImageURL
                ?? mega.shinyImageUrl
                ?? mega.highResImageURL
                ?? mega.imageUrl)
            : (megaOfficialArtworkUrl(for: mega, basePokemonDexNr: pokemon.dexNr, shiny: false)
                ?? mega.highResImageURL
                ?? mega.imageUrl)
        
        // Créer un Pokemon temporaire pour la navigation
        let targetPokemon = Pokemon(from: mega, basePokemon: pokemon)
        
        return NavigationLink(destination: PokemonDetailView(pokemon: targetPokemon, viewModel: viewModel, showCaptureControls: true)) {
            HStack(spacing: 12) {
                // Image plus compacte
                if let url = megaUrl {
                    // Taille FIXE indépendante du mode (70x70) pour éviter le redimensionnement
                    let imageSize: CGFloat = 70 
                    CachedAsyncImage(url: url, size: imageSize, contentMode: .fill)
                        .frame(width: imageSize, height: imageSize)
                        .clipped()
                } else {
                    // Placeholder si pas d'image
                    Color.clear.frame(width: 70, height: 70)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(mega.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    // Types
                    HStack(spacing: 4) {
                        if let pt = mega.primaryType {
                            typePill(pt)
                        }
                        if let st = mega.secondaryType {
                            typePill(st)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.tertiarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(megaGradientColor(mega).opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func megaGradientColor(_ mega: MegaEvolution) -> Color {
        guard let type = mega.primaryType?.type else { return .purple }
        return Pokemon.colorForType(type)
    }

    // MARK: - Chaîne d'Évolutions (Content)
    
    private var evolutionChainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Évolutions", icon: "arrow.triangle.branch")
            
            let evolutions = pokemon.evolutions ?? []
            
            HStack {
                Spacer(minLength: 0)
                evolutionRowContent(evolutions: evolutions)
                Spacer(minLength: 0)
            }
            .padding(.top, 4)
            .padding(.bottom, 20)
            // Force le rafraîchissement quand les données de capture changent
            .id("evo_chain_\(viewModel.totalCapturedCount)")
        }
    }

    @ViewBuilder
    private func evolutionRowContent(evolutions: [Evolution]) -> some View {
        if evolutions.count == 1 {
            // S'il n'y a qu'une seule évolution, on centre tout pour plus d'élégance
            HStack(alignment: .center, spacing: 12) {
                Spacer()
                EvolutionCard(
                    name: pokemon.name,
                    dexNr: pokemon.dexNr,
                    imageUrl: displayMode == .shiny
                        ? (pokemon.officialShinyArtworkUrl ?? pokemon.officialArtworkUrl)
                        : pokemon.officialArtworkUrl,
                    isCurrent: true,
                    isCaptured: viewModel.countCaptured(for: pokemon) > 0,
                    themeColor: themeColor
                )
                
                evolutionConnector(evolutions[0])
                evolutionTargetCard(evolutions[0])
                Spacer()
            }
            .id(displayMode)
        } else {
            // Pour les évolutions multiples (ex: Évoli), on affiche le Pokémon de base en haut
            // et ses évolutions en dessous dans une grille
            VStack(alignment: .center, spacing: 16) {
                EvolutionCard(
                    name: pokemon.name,
                    dexNr: pokemon.dexNr,
                    imageUrl: displayMode == .shiny
                        ? (pokemon.officialShinyArtworkUrl ?? pokemon.officialArtworkUrl)
                        : pokemon.officialArtworkUrl,
                    isCurrent: true,
                    isCaptured: viewModel.countCaptured(for: pokemon) > 0,
                    themeColor: themeColor
                )
                
                Image(systemName: "arrow.down")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.secondary)
                
                if !evolutions.isEmpty {
                    if evolutions.count == 2 {
                        HStack(spacing: 24) {
                            ForEach(evolutions) { evo in
                                VStack(spacing: 8) {
                                    evolutionTargetCard(evo)
                                    evolutionConditions(evo)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 16)], spacing: 16) {
                            ForEach(evolutions) { evo in
                                VStack(spacing: 8) {
                                    evolutionTargetCard(evo)
                                    evolutionConditions(evo)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .id(displayMode)
        }
    }
    
    @ViewBuilder
    private func evolutionConditions(_ evo: Evolution) -> some View {
        // Afficher les conditions d'évolution sous la carte
        VStack(spacing: 2) {
            if let candies = evo.candies {
                Text("\(candies) 🍬")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                // Espace vide pour aligner les objets si pas de bonbons
                Text(" ")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            
            if let item = evo.item {
                Text(item.name)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                // Espace vide pour aligner les bonbons si pas d'objet
                Text(" ")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
    }

    @ViewBuilder
    private func evolutionTargetCard(_ evo: Evolution) -> some View {
        let evoName = formatEvoName(evo.id)
        let targetPokemon = viewModel.pokemons.first(where: { $0.id == evo.id })
        let dexNr = targetPokemon?.dexNr
        let evoUrl = displayMode == .shiny
            ? (targetPokemon?.officialShinyArtworkUrl ?? targetPokemon?.officialArtworkUrl)
            : targetPokemon?.officialArtworkUrl

        if let target = targetPokemon {
            let isCaptured = viewModel.countCaptured(for: target) > 0

            NavigationLink(destination: PokemonDetailView(pokemon: target, viewModel: viewModel)) {
                EvolutionCard(
                    name: evoName,
                    dexNr: dexNr ?? 0,
                    imageUrl: evoUrl,
                    isCurrent: false,
                    isCaptured: isCaptured,
                    themeColor: themeColor
                )
            }
            .buttonStyle(.plain)
        } else {
            // Cette branche ne devrait théoriquement pas être atteinte si l'évolution est valide dans la base
            let isCaptured = viewModel.pokemons.first(where: { $0.id == evo.id }).map { target in
                viewModel.countCaptured(for: target) > 0
            } ?? false

            EvolutionCard(
                name: evoName,
                dexNr: dexNr ?? 0,
                imageUrl: evoUrl,
                isCurrent: false,
                isCaptured: isCaptured,
                themeColor: themeColor
            )
            .opacity(1.0)
        }
    }

    private func evolutionConnector(_ evo: Evolution) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Capsule()
                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    .frame(width: 48, height: 6)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 2) {
                if let candies = evo.candies {
                    Text("\(candies) 🍬")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                if let item = evo.item {
                    Text(item.name)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true) // Permet au texte de prendre sa hauteur
                        .frame(maxWidth: 80) // Plus large pour les langues asiatiques
                }
            }
        }
        .frame(width: 80) // Élargir le connecteur globalement
    }
    
    struct EvolutionCard: View {
        let name: String
        let dexNr: Int
        let imageUrl: URL?
        let isCurrent: Bool
        let isCaptured: Bool
        let themeColor: Color
        
        var body: some View {
            VStack(spacing: 6) {
                ZStack {
                    if isCurrent {
                        themeColor.opacity(0.12)
                            .clipShape(Circle())
                            .blur(radius: 8)
                    }
                    
                    if let url = imageUrl {
                        CachedAsyncImage(url: url, size: 70)
                            .frame(width: 70, height: 70)
                    } else {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                            .frame(width: 70, height: 70)
                    }
                    
                    // Badge de capture (conservé car subtil)
                    if isCaptured {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16)) // Un peu plus grand
                            .foregroundStyle(.green)
                            .background(Circle().fill(.white))
                            .offset(x: 28, y: -28) // Plus à l'extérieur pour ne pas cacher le visage
                    }
                }
                
                VStack(spacing: 2) {
                    Text(name)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Text("#\(dexNr.formatted(.number.precision(.integerLength(3))))")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 92)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isCurrent ? themeColor.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
    }
    
    private func formatEvoName(_ id: String) -> String {
        // Cherche d'abord le Pokémon dans la liste pour avoir le nom traduit
        if let targetPokemon = viewModel.pokemons.first(where: { $0.id == id }) {
            return targetPokemon.name
        }
        // Fallback : Convert "IVYSAUR" → "Ivysaur"
        return id.replacingOccurrences(of: "_", with: " ").capitalized
    }
    

    
    /// Essaye de trouver le dexNr d'un Pokémon par son ID dans la liste chargée.
    private func findDexNr(for pokemonId: String) -> Int? {
        viewModel.pokemons.first(where: { $0.id == pokemonId })?.dexNr
    }
    

    

    

    
    // MARK: - Helpers
    
    private func typePill(_ typeEntry: PokemonTypeEntry) -> some View {
        let key = localizedLanguageKey()
        let name = typeEntry.names[key] ?? typeEntry.names["English"] ?? ""
        
        return Text(name)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Pokemon.colorForType(typeEntry.type)))
    }
    
    private func miniStat(icon: String, value: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
    }
    
    private func sectionHeader(_ title: String, icon: String = "") -> some View {
        HStack(spacing: 6) {
            if !icon.isEmpty {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.2)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }
    
    // MARK: - Variantes (Content)
    
    private var variantsContent: some View {
        Group {
            VStack(alignment: .leading, spacing: 0) {
                if let forms = pokemon.assetForms {
                    sectionHeader("Variantes", icon: "sparkles")
                        .frame(minHeight: 1) // Prevent 1206x0 error

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Filtrer les variantes...", text: $searchText)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)

                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    .clipShape(.capsule)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 16)

                    let filteredForms = filteredVariantForms(from: forms)
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 130), spacing: 12)],
                        alignment: .center,
                        spacing: 12
                    ) {
                        ForEach(filteredForms) { form in
                            VariantCard(
                                pokemon: pokemon,
                                form: form,
                                displayMode: displayMode,
                                showCaptureControls: showCaptureControls,
                                viewModel: viewModel,
                                onImageTap: { url in zoomedImage = ZoomedImageTarget(id: url) }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
    }
    
    private var notAvailableView: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Disponibilité", icon: "clock.fill")
                .frame(minHeight: 1)

            VStack(spacing: 16) {
                Image(systemName: "clock")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue.opacity(0.8))
                
                Text("Pas encore disponible\ndans Pokémon GO")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
        )
    }

    private func isEternamaxRegionForm(_ form: RegionForm) -> Bool {
        (form.formId ?? form.id).contains("ETERNAMAX")
    }

    private func baseVariantForms(from forms: [AssetForm]) -> [AssetForm] {
        forms.filter { form in
            // Exclure "Standard", les formes sans image, les Mega Evolutions, Gigantamax et Eternamax (qui ont leur propre section)
            let isStandard = form.displayName == "Standard"
            let hasNoImage = form.image == nil && form.shinyImage == nil
            let isMega = form.displayName.lowercased().contains("mega")
            let isGigantamax = form.form == "GIGANTAMAX" || form.form == "GIGANTAMAX_MEGA"
            let isEternamax = form.form == "ETERNAMAX"
            let isDynamax = form.form == "DYNAMAX"
            
            return !isStandard && !hasNoImage && !isMega && !isGigantamax && !isEternamax && !isDynamax
        }
    }

    private func filteredVariantForms(from forms: [AssetForm]) -> [AssetForm] {
        let variantsOnly = baseVariantForms(from: forms)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let filtered = variantsOnly.filter { form in
            query.isEmpty || form.displayName.localizedStandardContains(query)
        }
        
        return filtered.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }
}

// MARK: - Vue Zoom Plein Écran

struct ImageZoomView: View {
    let url: URL?
    let onDismiss: () -> Void
    private let baseImageScale: CGFloat = 1.14
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Button(action: dismiss) {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                if let url = url {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .scaleEffect(baseImageScale * scale)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 20)
                                .gesture(
                                    MagnifyGesture()
                                        .onChanged { value in scale = value.magnification }
                                        .onEnded { _ in withAnimation { scale = 1.0 } }
                                )
                        } else if phase.error != nil {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white.opacity(0.6))
                                Text("Erreur de chargement")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        } else {
                            ProgressView().tint(.white).scaleEffect(1.5)
                        }
                    }
                } else {
                    ProgressView().scaleEffect(1.5)
                }

                Spacer(minLength: 0)
            }
        }
    }
    
    private func dismiss() {
        withAnimation {
            onDismiss()
        }
    }
}

// MARK: - Carte de Variante (Nouveau Design Grille)

struct VariantCard: View {
    let pokemon: Pokemon
    let form: AssetForm
    let displayMode: PokemonDetailView.DisplayMode
    let showCaptureControls: Bool
    @ObservedObject var viewModel: PogodexViewModel
    let onImageTap: (URL) -> Void
    @State private var hapticTrigger = 0
    
    private func triggerHaptic() {
        hapticTrigger += 1
    }
    
    var body: some View {
        let isShiny = (displayMode == .shiny)
        let count = viewModel.captureCount(pokemon: pokemon, form: form, shiny: isShiny)
        let isCaptured = count > 0
        let luckyCount = viewModel.getLuckyCount(pokemon: pokemon, form: form, shiny: isShiny)
        
        VStack(spacing: 8) {
            // ── Header (Image + Nom) ──
            VStack(spacing: 6) {
                variantImage
                
                Text(PokemonTranslation.translate(name: form.displayName, for: pokemon.name))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 4)
                    
                // Affichage de la région d'origine si c'est une forme régionale
                if form.displayName.contains("Alola") {
                    Text("Région d'Alola")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                } else if form.displayName.contains("Galar") {
                    Text("Région de Galar")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                } else if form.displayName.contains("Hisui") {
                    Text("Région de Hisui")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                } else if form.displayName.contains("Paldea") {
                    Text("Région de Paldea")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                // ── Localisation de la variante (sous le nom) ──
                let formKey = "\(pokemon.dexNr)_\(form.form?.uppercased() ?? "")"
                if let location = regionalFormLocations[formKey] {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.red)
                        Text(location)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
            .padding(.horizontal, 4)
            
            if showCaptureControls {
                // ── Actions ──
                VStack(spacing: 6) {
                    captureControl(
                        count: count,
                        isShiny: isShiny,
                        isActive: isCaptured
                    )
                    
                    luckyControl(
                        count: luckyCount,
                        isShiny: isShiny,
                        form: form
                    )
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
        }
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
    }
    
    // MARK: - Image
    
    private var variantImage: some View {
        let formUrl = pokemon.highResImageURL(for: form, shiny: displayMode == .shiny)
        // Fallback à l'image principale du Pokémon si la variante n'en a pas
        let finalUrl: URL? = {
            if let url = formUrl {
                return url
            } else if let assetImg = displayMode == .shiny ? pokemon.assets?.shinyImage : pokemon.assets?.image {
                return URL(string: assetImg)
            }
            return nil
        }()
        
        return Group {
            if let url = finalUrl {
                Button {
                    onImageTap(url)
                } label: {
                    CachedAsyncImage(url: url, size: 70, contentMode: .fit)
                        .frame(width: 70, height: 70)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundStyle(.tertiary)
                    .frame(width: 70, height: 70)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
    }
    
    // MARK: - Contrôles Actions
    
    @Namespace private var animationNamespace

    @ViewBuilder
    private func captureControl(count: Int, isShiny: Bool, isActive: Bool) -> some View {
        Group {
            if count > 0 {
                // Mode "Compteur" avec +/-
                HStack(spacing: 0) {
                    // Bouton Moins
                    Button(action: {
                        triggerHaptic()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.decrementCapture(pokemon: pokemon, form: form, shiny: isShiny)
                        }
                    }) {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 44, height: 32)
                            .contentShape(Rectangle())
                    }
                    
                    Divider().overlay(Color.white.opacity(0.5)).padding(.vertical, 4)
                    
                    Text("\(count)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .contentTransition(.numericText())
                    
                    Divider().overlay(Color.white.opacity(0.5)).padding(.vertical, 4)
                    
                    // Bouton Plus
                    Button(action: {
                        triggerHaptic()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.incrementCapture(pokemon: pokemon, form: form, shiny: isShiny)
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 44, height: 32)
                            .contentShape(Rectangle())
                    }
                }
                .foregroundStyle(.white)
                .background(Capsule().fill(isShiny ? Color.orange : Color.blue))
                .matchedGeometryEffect(id: "captureButton", in: animationNamespace)
            } else {
                // Mode "Capturé" simple
                Button(action: {
                    triggerHaptic()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.incrementCapture(pokemon: pokemon, form: form, shiny: isShiny)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "circle")
                            .font(.system(size: 12, weight: .bold))
                        Text("Capturé")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(Capsule().fill(Color(.tertiarySystemFill)))
                    .matchedGeometryEffect(id: "captureButton", in: animationNamespace)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: count > 0)
    }
    
    @ViewBuilder
    private func luckyControl(count: Int, isShiny: Bool, form: AssetForm?) -> some View {
        Group {
            if count > 0 {
                HStack(spacing: 0) {
                    Button(action: {
                        triggerHaptic()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.decrementLucky(pokemon: pokemon, form: form, shiny: isShiny)
                        }
                    }) {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 44, height: 32)
                            .contentShape(Rectangle())
                    }
                    
                    Divider().overlay(Color.black.opacity(0.2)).padding(.vertical, 4)
                    
                    Text("\(count)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .contentTransition(.numericText())
                    
                    Divider().overlay(Color.black.opacity(0.2)).padding(.vertical, 4)
                    
                    Button(action: {
                        triggerHaptic()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.incrementLucky(pokemon: pokemon, form: form, shiny: isShiny)
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 44, height: 32)
                            .contentShape(Rectangle())
                    }
                }
                .foregroundStyle(.black)
                .background(Capsule().fill(Color.yellow))
                .matchedGeometryEffect(id: "luckyButton", in: animationNamespace)
            } else {
                Button(action: {
                    triggerHaptic()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.incrementLucky(pokemon: pokemon, form: form, shiny: isShiny)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Chanceux")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(Capsule().fill(Color(.tertiarySystemFill)))
                    .matchedGeometryEffect(id: "luckyButton", in: animationNamespace)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: count > 0)
    }
}
