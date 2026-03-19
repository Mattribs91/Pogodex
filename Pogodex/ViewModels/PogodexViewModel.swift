import OSLog
import Combine
import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// ViewModel principal pour gérer la logique du Pokédex et le chargement via API.
@MainActor
class PogodexViewModel: ObservableObject {
    
    /// Liste plate des Pokémon (source de vérité).
    @Published var pokemons: [Pokemon] = []
    
    /// Liste des Pokémon par Génération.
    @Published var groupedPokemons: [Int: [Pokemon]] = [:]
    
    /// Liste triée des générations présentes.
    @Published var generations: [Int] = []
    
    /// Dictionnaire contenant les compteurs de captures.
    /// Format clé: "{pokemonID}_{formID}_{isShiny}" -> Valeur: Nombre de captures
    @Published var capturedCounts: [String: Int] = [:]
    
    /// Compteurs des "Chanceux" (Lucky).
    /// Format: "{pokemonID}_{formID}_{isShiny}" -> Count
    @Published var luckyCounts: [String: Int] = [:]
    
    /// Indique si les données sont en cours de chargement.
    @Published var isLoading = true
    
    /// Message d'erreur éventuel.
    @Published var errorMessage: String?
    
    /// Indique si la synchronisation iCloud est active.
    @Published var isCloudSyncActive: Bool = false
    
    /// Indique si une synchronisation iCloud est en cours.
    @Published var isSyncing: Bool = false

    private let logger = Logger(subsystem: "com.pogotracker", category: "PogoDexViewModel")
    private var saveTask: Task<Void, Never>?  // Debounce pour saveData
    
    /// Initialisateur du ViewModel.
    init() {
        loadData()
    }
    
    /// Récupère la liste des Pokémon depuis l'API.
    @MainActor
    func fetchPokemon() async {
        isLoading = true
        errorMessage = nil
        logger.info("Début du chargement des Pokémon...")
        
        guard let url = URL(string: "https://pokemon-go-api.github.io/pokemon-go-api/api/pokedex.json") else {
            errorMessage = "URL invalide"
            logger.error("URL invalide")
            isLoading = false
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decodedPokemons = try JSONDecoder().decode([Pokemon].self, from: data)
            
            // Les noms sont déjà filtrés pendant le décodage JSON (init(from:))
            // pour ne garder que la langue actuelle + English
            
            // On trie par numéro de Pokédex
            self.pokemons = decodedPokemons.sorted { $0.dexNr < $1.dexNr }
            
            // Groupement par génération
            self.groupedPokemons = Dictionary(grouping: self.pokemons, by: { $0.generation })
            self.generations = self.groupedPokemons.keys.sorted()

            logger.info("Succès : \(self.pokemons.count) Pokémon chargés, répartis en \(self.generations.count) générations.")
            isLoading = false
        } catch {
            // Ignorer les erreurs d'annulation (pull-to-refresh rapide, etc.)
            if error is CancellationError || (error as? URLError)?.code == .cancelled {
                logger.debug("Chargement annulé.")
                // On NE coupe PAS le chargement ici si on a déjà des données en cache
                // On laisse isLoading à false seulement si on avait vraiment rien
                if self.pokemons.isEmpty {
                    isLoading = false
                }
                return
            }
            
            logger.error("Erreur de chargement: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .typeMismatch(let type, let context):
                    logger.error("TypeMismatch: \(type) at \(context.codingPath.map(\.stringValue).joined(separator: ".")) — \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    logger.error("ValueNotFound: \(type) at \(context.codingPath.map(\.stringValue).joined(separator: ".")) — \(context.debugDescription)")
                case .keyNotFound(let key, let context):
                    logger.error("KeyNotFound: \(key.stringValue) at \(context.codingPath.map(\.stringValue).joined(separator: ".")) — \(context.debugDescription)")
                case .dataCorrupted(let context):
                    logger.error("DataCorrupted at \(context.codingPath.map(\.stringValue).joined(separator: ".")) — \(context.debugDescription)")
                @unknown default:
                    logger.error("Unknown DecodingError: \(decodingError)")
                }
            }
            errorMessage = "Erreur de chargement des données: \(error.localizedDescription)"
            isLoading = false
        }
    }

    /// Format ID: "{pokemonID}_{formID}_{shiny}"
    func captureID(pokemon: Pokemon, form: AssetForm, shiny: Bool) -> String {
        return "\(pokemon.id)_\(form.id)_\(shiny ? "shiny" : "normal")"
    }

    /// Retourne le nom de la région pour une génération donnée.
    func regionName(for generation: Int) -> String {
        let lang = localizedLanguageKey()
        
        switch generation {
        case 1:
            switch lang {
            case "Japanese": return "カントー (第1世代)"
            case "Korean": return "관동 (1세대)"
            default: return "Kanto (Gen 1)"
            }
        case 2:
            switch lang {
            case "Japanese": return "ジョウト (第2世代)"
            case "Korean": return "성도 (2세대)"
            default: return "Johto (Gen 2)"
            }
        case 3:
            switch lang {
            case "Japanese": return "ホウエン (第3世代)"
            case "Korean": return "호연 (3세대)"
            default: return "Hoenn (Gen 3)"
            }
        case 4:
            switch lang {
            case "Japanese": return "シンオウ (第4世代)"
            case "Korean": return "신오 (4세대)"
            default: return "Sinnoh (Gen 4)"
            }
        case 5:
            switch lang {
            case "French": return "Unys (Gen 5)"
            case "German": return "Einall (Gen 5)"
            case "Spanish": return "Teselia (Gen 5)"
            case "Italian": return "Unima (Gen 5)"
            case "Japanese": return "イッシュ (第5世代)"
            case "Korean": return "하나 (5세대)"
            default: return "Unova (Gen 5)"
            }
        case 6:
            switch lang {
            case "Japanese": return "カロス (第6世代)"
            case "Korean": return "칼로스 (6세대)"
            default: return "Kalos (Gen 6)"
            }
        case 7:
            switch lang {
            case "Japanese": return "アローラ (第7世代)"
            case "Korean": return "알로라 (7세대)"
            default: return "Alola (Gen 7)"
            }
        case 8:
            switch lang {
            case "Japanese": return "ガラル (第8世代)"
            case "Korean": return "가라르 (8세대)"
            default: return "Galar (Gen 8)"
            }
        case 9:
            switch lang {
            case "Japanese": return "パルデア (第9世代)"
            case "Korean": return "팔데아 (9세대)"
            default: return "Paldea (Gen 9)"
            }
        default: 
            switch lang {
            case "French": return "Génération \(generation)"
            case "German": return "Generation \(generation)"
            case "Spanish": return "Generación \(generation)"
            case "Italian": return "Generazione \(generation)"
            case "Japanese": return "第\(generation)世代"
            case "Korean": return "\(generation)세대"
            default: return "Generation \(generation)"
            }
        }
    }
    
    /// Incrémente le compteur de capture pour une variante spécifique.
    func incrementCapture(pokemon: Pokemon, form: AssetForm, shiny: Bool) {
        let id = captureID(pokemon: pokemon, form: form, shiny: shiny)
        capturedCounts[id, default: 0] += 1
        saveData()
    }
    
    /// Décrémente le compteur de capture.
    func decrementCapture(pokemon: Pokemon, form: AssetForm, shiny: Bool) {
        let id = captureID(pokemon: pokemon, form: form, shiny: shiny)
        if let count = capturedCounts[id], count > 0 {
            capturedCounts[id] = count - 1
            if capturedCounts[id] == 0 {
                capturedCounts.removeValue(forKey: id)
            }
            saveData()
        }
    }
    
    /// Bascule l'état de capture (Legacy behavior: 0 -> 1, >0 -> 0).
    /// Utilisé pour la compatibilité ou le toggle simple.
    func toggleCapture(pokemon: Pokemon, form: AssetForm, shiny: Bool) {
        let id = captureID(pokemon: pokemon, form: form, shiny: shiny)
        if (capturedCounts[id] ?? 0) > 0 {
            capturedCounts.removeValue(forKey: id)
        } else {
            capturedCounts[id] = 1
        }
        saveData()
    }
    
    // MARK: - Helpers for Optional Forms (Standard Fallback)
    
    func getCaptureCount(pokemon: Pokemon, form: AssetForm?, shiny: Bool) -> Int {
        let targetForm = form ?? AssetForm.standard
        let id = captureID(pokemon: pokemon, form: targetForm, shiny: shiny)
        return capturedCounts[id, default: 0]
    }
    
    func incrementCapture(pokemon: Pokemon, form: AssetForm?, shiny: Bool) {
        let targetForm = form ?? AssetForm.standard
        incrementCapture(pokemon: pokemon, form: targetForm, shiny: shiny)
    }
    
    func decrementCapture(pokemon: Pokemon, form: AssetForm?, shiny: Bool) {
        let targetForm = form ?? AssetForm.standard
        decrementCapture(pokemon: pokemon, form: targetForm, shiny: shiny)
    }


    
    /// Vérifie si une variante est capturée (count > 0).
    func isCaptured(pokemon: Pokemon, form: AssetForm, shiny: Bool) -> Bool {
        return (capturedCounts[captureID(pokemon: pokemon, form: form, shiny: shiny)] ?? 0) > 0
    }
    
    /// Retourne le nombre exact de captures pour une variante.
    func captureCount(pokemon: Pokemon, form: AssetForm, shiny: Bool) -> Int {
        return capturedCounts[captureID(pokemon: pokemon, form: form, shiny: shiny)] ?? 0
    }

    /// Incrémente le compteur "Chanceux".
    func incrementLucky(pokemon: Pokemon, form: AssetForm?, shiny: Bool) {
        let targetForm = form ?? AssetForm.standard
        let id = captureID(pokemon: pokemon, form: targetForm, shiny: shiny)
        luckyCounts[id, default: 0] += 1
        saveData()
    }
    
    /// Décrémente le compteur "Chanceux".
    func decrementLucky(pokemon: Pokemon, form: AssetForm?, shiny: Bool) {
        let targetForm = form ?? AssetForm.standard
        let id = captureID(pokemon: pokemon, form: targetForm, shiny: shiny)
        if let count = luckyCounts[id], count > 0 {
            luckyCounts[id] = count - 1
            if luckyCounts[id] == 0 {
                luckyCounts.removeValue(forKey: id)
            }
            saveData()
        }
    }
    
    /// Retourne le nombre de Lucky pour une variante.
    func getLuckyCount(pokemon: Pokemon, form: AssetForm?, shiny: Bool) -> Int {
        let targetForm = form ?? AssetForm.standard
        return luckyCounts[captureID(pokemon: pokemon, form: targetForm, shiny: shiny)] ?? 0
    }
    
    // MARK: - Persistance (iCloud + UserDefaults)
    
    private let capturedCountsKey = "captured_counts_v1"
    private let luckyCountsKey = "lucky_counts_v1"
    
    // Ancien format pour migration
    private let capturedKey = "captured_variants_v1"
    private let luckySetKey = "lucky_captures_v1"
    
    private let trainerNicknameKey = "trainer_nickname"

    private var canUseCloudStore: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }
    
    private func saveData() {
        // Annuler la tâche précédente si elle existe (Debounce)
        saveTask?.cancel()
        
        saveTask = Task {
            do {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 sec
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self.isSyncing = true
                }
                
                // 1. Sauvegarde locale (UserDefaults)
                UserDefaults.standard.set(capturedCounts, forKey: capturedCountsKey)
                UserDefaults.standard.set(luckyCounts, forKey: luckyCountsKey)
                
                // 2. Sauvegarde iCloud (NSUbiquitousKeyValueStore)
                if self.canUseCloudStore {
                    let cloudStore = NSUbiquitousKeyValueStore.default
                    cloudStore.set(capturedCounts, forKey: capturedCountsKey)
                    cloudStore.set(luckyCounts, forKey: luckyCountsKey)

                    // Sauvegarder aussi le pseudo
                    if let nickname = UserDefaults.standard.string(forKey: trainerNicknameKey) {
                        cloudStore.set(nickname, forKey: trainerNicknameKey)
                    }

                    cloudStore.synchronize()
                }
                
                // Petit délai pour montrer l'animation de synchro
                try await Task.sleep(nanoseconds: 500_000_000)
                
                await MainActor.run {
                    self.isSyncing = false
                }
                
            } catch {
                // Task cancelled
                await MainActor.run {
                    self.isSyncing = false
                }
            }
        }
    }
    
    private func loadData() {
        isCloudSyncActive = canUseCloudStore

        // Observer les changements iCloud
        if canUseCloudStore {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(iCloudDataDidChange(_:)),
                name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: NSUbiquitousKeyValueStore.default
            )

            // Synchroniser au démarrage
            NSUbiquitousKeyValueStore.default.synchronize()
        }
        
        // Charger les données (priorité iCloud > Local)
        loadFromCloudOrLocal()
    }
    
    @objc private func iCloudDataDidChange(_ notification: Notification) {
        // Recharger les données quand iCloud notifie d'un changement venant d'un autre appareil
        loadFromCloudOrLocal()
    }
    
    private func loadFromCloudOrLocal() {
        let localStore = UserDefaults.standard
        let cloudStore: NSUbiquitousKeyValueStore? = canUseCloudStore ? .default : nil

        // Vérifier si iCloud est disponible (token non nil)
        isCloudSyncActive = canUseCloudStore
        
        // --- CHARGEMENT PSEUDO ---
        if let cloudStore, let cloudNickname = cloudStore.string(forKey: trainerNicknameKey) {
            localStore.set(cloudNickname, forKey: trainerNicknameKey)
        }
        
        // --- CHARGEMENT CAPTURES ---
        // Essayer iCloud d'abord
        if let cloudStore, let cloudCounts = cloudStore.dictionary(forKey: capturedCountsKey) as? [String: Int] {
            capturedCounts = cloudCounts
            // Mettre à jour le local pour être synchro
            localStore.set(cloudCounts, forKey: capturedCountsKey)
        }
        // Sinon Local (nouveau format)
        else if let localCounts = localStore.dictionary(forKey: capturedCountsKey) as? [String: Int] {
            capturedCounts = localCounts
        }
        // Sinon Migration (ancien format Set)
        else if let oldSet = localStore.array(forKey: capturedKey) as? [String] {
            var newCounts: [String: Int] = [:]
            for id in oldSet { newCounts[id] = 1 }
            capturedCounts = newCounts
            saveData() // Sauvegarder dans le nouveau format (Local + Cloud)
        }
        
        // --- CHARGEMENT LUCKY ---
        if let cloudStore, let cloudLucky = cloudStore.dictionary(forKey: luckyCountsKey) as? [String: Int] {
            luckyCounts = cloudLucky
            localStore.set(cloudLucky, forKey: luckyCountsKey)
        }
        else if let localLucky = localStore.dictionary(forKey: luckyCountsKey) as? [String: Int] {
            luckyCounts = localLucky
        }
        else if let oldLuckySet = localStore.array(forKey: luckySetKey) as? [String] {
            var newLuckyCounts: [String: Int] = [:]
            for id in oldLuckySet { newLuckyCounts[id] = 1 }
            luckyCounts = newLuckyCounts
            saveData()
        }
    }
    
    /// Vérifie si une variante est chanceuse.
    func isLucky(pokemon: Pokemon, form: AssetForm, shiny: Bool) -> Bool {
        return (luckyCounts[captureID(pokemon: pokemon, form: form, shiny: shiny)] ?? 0) > 0
    }
    
    /// Compte le nombre total de variantes capturées pour un Pokémon (en comptant les multiples ? Non, "espèces capturées").
    /// Ici on veut savoir si le Pokemon est "complété".
    /// Pour le header "XX/YY", on compte généralement les Uniques.
    func countCapturedUnique(for pokemon: Pokemon) -> Int {
        // On compte combien de variantes ont un count > 0
        return capturedCounts.keys.filter { $0.hasPrefix("\(pokemon.id)_") }.count
    }
    
    /// Retourne le nombre total de captures (toutes variantes confondues) pour un Pokémon.
    /// Utilisé par PokemonCell pour le badge.
    func countCaptured(for pokemon: Pokemon) -> Int {
        return capturedCounts
            .filter { $0.key.hasPrefix("\(pokemon.id)_") }
            .values
            .reduce(0, +)
    }
    
    // MARK: - Statistiques
    
    /// Réinitialise toutes les données de capture (Local + iCloud)
    func resetAllData() {
        capturedCounts.removeAll()
        luckyCounts.removeAll()
        
        // Supprimer localement
        UserDefaults.standard.removeObject(forKey: capturedCountsKey)
        UserDefaults.standard.removeObject(forKey: luckyCountsKey)
        UserDefaults.standard.removeObject(forKey: capturedKey)
        UserDefaults.standard.removeObject(forKey: luckySetKey)
        
        // Supprimer sur iCloud
        if canUseCloudStore {
            let cloudStore = NSUbiquitousKeyValueStore.default
            cloudStore.removeObject(forKey: capturedCountsKey)
            cloudStore.removeObject(forKey: luckyCountsKey)
            cloudStore.synchronize()
        }
        
        saveData()
    }
    
    /// Nombre total de Pokémon (espèces) dans une génération.
    func totalPokemonCount(for gen: Int) -> Int {
        return groupedPokemons[gen]?.count ?? 0
    }
    
    /// Nombre de Pokémon (espèces) dont au moins une variante a été capturée dans une génération.
    func capturedPokemonCount(for gen: Int) -> Int {
        guard let pokemons = groupedPokemons[gen] else { return 0 }
        return pokemons.filter { countCapturedUnique(for: $0) > 0 }.count
    }
    
    /// Nombre total de variantes capturées (toutes générations, UNIQUES).
    var totalCapturedCount: Int { capturedCounts.count }
    
    /// Nombre total de variantes shiny capturées (UNIQUES).
    var totalShinyCount: Int {
        capturedCounts.keys.filter { $0.hasSuffix("_shiny") }.count
    }
    
    /// Nombre total de variantes chanceuses.
    var totalLuckyCount: Int { luckyCounts.count }
    
    /// Vérifie si une variante SHINY a été capturée pour ce Pokémon (count > 0).
    func hasCapturedShiny(for pokemon: Pokemon) -> Bool {
        return capturedCounts.keys.contains { variantId in
            variantId.hasPrefix("\(pokemon.id)_") && variantId.hasSuffix("_shiny")
        }
    }
    
    /// Vérifie si une variante CHANCEUSE (Lucky) a été capturée pour ce Pokémon.
    func hasCapturedLucky(for pokemon: Pokemon) -> Bool {
        return luckyCounts.contains { (key, count) in
            key.hasPrefix("\(pokemon.id)_") && count > 0
        }
    }
    
    /// Vérifie si une variante spécifique GIGANTAMAX est capturée (avec gestion Shiny)
    func hasCapturedGigantamax(for pokemon: Pokemon) -> Bool {
        // On cherche une clé qui contient l'ID du Pokémon et "GIGANTAMAX"
        // Le suffixe peut être "_shiny" ou "_normal"
        return capturedCounts.keys.contains { key in
            key.starts(with: "\(pokemon.id)_") && key.contains("GIGANTAMAX") && (capturedCounts[key] ?? 0) > 0
        }
    }
    
    /// Vérifie si une variante spécifique GIGANTAMAX est capturée en SHINY
    func hasCapturedGigantamaxShiny(for pokemon: Pokemon) -> Bool {
        return capturedCounts.keys.contains { key in
            key.starts(with: "\(pokemon.id)_") && key.contains("GIGANTAMAX") && key.hasSuffix("_shiny") && (capturedCounts[key] ?? 0) > 0
        }
    }
    
    // MARK: - Prefetching
    
    /// Précharge les images des N premiers Pokémon pour éviter le "pop-in" au lancement.
    @MainActor
    func prefetchImages(limit: Int = 12) async {
        logger.info("Début du préchargement des images (limit: \(limit))...")
        
        let pokemonsToLoad = Array(pokemons.prefix(limit))
        
        await withTaskGroup(of: Void.self) { group in
            for pokemon in pokemonsToLoad {
                // IMPORTANT: On doit utiliser la même logique d'URL que PokemonCell
                // 1. Image normale (Artwork HQ)
                if let normalUrl = pokemon.officialArtworkUrl ?? pokemon.imageUrl {
                    group.addTask { await self.loadImage(url: normalUrl) }
                }
                
                // 2. Image Shiny (si capturé)
                if self.hasCapturedShiny(for: pokemon), let shinyUrl = pokemon.officialShinyArtworkUrl ?? pokemon.shinyImageUrl {
                    group.addTask { await self.loadImage(url: shinyUrl) }
                }
            }
        }
        
        logger.info("Préchargement terminé.")
    }
    
    /// Helper pour charger une image unique dans le cache (avec downsample)
    @MainActor
    private func loadImage(url: URL) async {
        if ImageCache.shared.image(for: url) != nil { return }
        
        do {
            let (data, _) = try await ImageLoader.shared.session.data(from: url)
            
            // Downsample comme CachedAsyncImage pour économiser la RAM
            autoreleasepool {
                let options = [kCGImageSourceShouldCache: false] as CFDictionary
                guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return }
                
                let maxDimension: CGFloat = 72 * 3.0 // 3x taille de cell
                let downsampleOptions = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceShouldCacheImmediately: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxDimension
                ] as CFDictionary
                
                guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else { return }
                
                #if canImport(UIKit)
                let uiImg = UIImage(cgImage: cgImage)
                ImageCache.shared.storeNative(uiImg, for: url)
                #elseif canImport(AppKit)
                let nsImg = NSImage(cgImage: cgImage, size: NSSize(width: 72, height: 72))
                ImageCache.shared.storeNative(nsImg, for: url)
                #endif
            }
        } catch {
            // Ignore errors
        }
    }
}
