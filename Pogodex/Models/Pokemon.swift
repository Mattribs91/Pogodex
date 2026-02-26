import SwiftUI
import Foundation

/// Retourne la clé de langue pour l'API ("French", "English", etc.)
/// basée sur la langue préférée de l'utilisateur, pas la locale de l'app.
/// Variable globale stockant la langue actuelle pour l'API.
var CurrentPokemonLanguageKey: String = "English"

/// Met à jour la langue des Pokémon basée sur les préférences système de l'utilisateur.
/// On ignore la `locale` fournie par SwiftUI car si l'app n'est pas traduite, elle reste en anglais.
/// Met à jour la langue des Pokémon basée sur les préférences système de l'utilisateur.
/// On parcourt la liste des langues préférées pour trouver la première supportée par l'API.
func updatePokemonLanguage(with locale: Locale) {
    // 1. Priorité absolue : Réglage utilisateur dans l'app
    if let userLang = UserDefaults.standard.string(forKey: "app_language") {
        CurrentPokemonLanguageKey = userLang
        print("DEBUG: User language preference found -> \(userLang)")
        return
    }

    let supportedPrefixes: [String: String] = [
        "fr": "French",
        "de": "German",
        "it": "Italian",
        "ja": "Japanese",
        "ko": "Korean",
        "es": "Spanish",
        "en": "English"
    ]
    
    // Parcourt toutes les langues préférées (ex: ["nl-BE", "de-DE", "en-US"])
    for code in Locale.preferredLanguages {
        // On prend les 2 premiers caractères (ex: "nl", "de")
        let prefix = String(code.prefix(2))
        if let key = supportedPrefixes[prefix] {
            CurrentPokemonLanguageKey = key
            print("DEBUG: Language found -> \(key) (Source: \(code))")
            return
        }
    }
    
    // Fallback
    CurrentPokemonLanguageKey = "English"
    print("DEBUG: No supported language found, default -> English (Source: \(Locale.preferredLanguages))")
}

func localizedLanguageKey() -> String {
    return CurrentPokemonLanguageKey
}

/// Modèle représentant un Pokémon tel que renvoyé par l'API `pokemon-go-api`.
struct Pokemon: Identifiable, Codable {
    /// Identifiant unique (ex: "BULBASAUR").
    let id: String
    /// Numéro du Pokédex national.
    let dexNr: Int
    /// Numéro de génération (1: Kanto, 2: Johto, etc.).
    let generation: Int
    /// Dictionnaire des noms (English, French, etc.).
    let names: [String: String]
    /// Ressources de base (images).
    let assets: Assets?
    /// Liste des formes alternatives et costumes.
    let assetForms: [AssetForm]?
    /// Type principal (pour la couleur).
    let primaryType: PokemonTypeEntry?
    /// Type secondaire.
    let secondaryType: PokemonTypeEntry?
    /// Stats de combat (stamina, attack, defense).
    let stats: PokemonStats?
    /// Classe du Pokémon (POKEMON_CLASS_LEGENDARY, POKEMON_CLASS_MYTHIC, etc.).
    let pokemonClass: String?
    /// Chaîne d'évolutions.
    let evolutions: [Evolution]?
    /// Formes régionales (Alola, Galar, Hisui, Paldea) — dict dans l'API, [] si vide.
    let regionForms: [String: RegionForm]?
    /// Méga-évolutions — dict dans l'API, [] si vide.
    let megaEvolutions: [String: MegaEvolution]?
    /// Est-ce que ce Pokémon a une méga-évolution ?
    let hasMegaEvolution: Bool?
    /// Est-ce que ce Pokémon a une forme Gigantamax ?
    let hasGigantamaxEvolution: Bool?
    
    // MARK: - Décodage custom (megaEvolutions et regionForms sont [] quand vides, {} quand remplis)
    
    enum CodingKeys: String, CodingKey {
        case id, dexNr, generation, names, assets, assetForms
        case primaryType, secondaryType, stats, pokemonClass
        case evolutions, regionForms, megaEvolutions, hasMegaEvolution
        case hasGigantamaxEvolution
    }
    
    /// Initializer memberwise pour créer une instance Pokemon programmatiquement.
    init(
        id: String,
        dexNr: Int,
        generation: Int,
        names: [String: String],
        assets: Assets?,
        assetForms: [AssetForm]?,
        primaryType: PokemonTypeEntry?,
        secondaryType: PokemonTypeEntry?,
        stats: PokemonStats?,
        pokemonClass: String?,
        evolutions: [Evolution]?,
        regionForms: [String: RegionForm]?,
        megaEvolutions: [String: MegaEvolution]?,
        hasMegaEvolution: Bool?,
        hasGigantamaxEvolution: Bool?
    ) {
        self.id = id
        self.dexNr = dexNr
        self.generation = generation
        self.names = names
        self.assets = assets
        self.assetForms = assetForms
        self.primaryType = primaryType
        self.secondaryType = secondaryType
        self.stats = stats
        self.pokemonClass = pokemonClass
        self.evolutions = evolutions
        self.regionForms = regionForms
        self.megaEvolutions = megaEvolutions
        self.hasMegaEvolution = hasMegaEvolution
        self.hasGigantamaxEvolution = hasGigantamaxEvolution
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        dexNr = try container.decode(Int.self, forKey: .dexNr)
        generation = try container.decode(Int.self, forKey: .generation)
        
        // Décode tous les noms sans filtrer, pour permettre le changement de langue dynamique
        names = try container.decode([String: String].self, forKey: .names)
        
        assets = try container.decodeIfPresent(Assets.self, forKey: .assets)
        
        // On décode d'abord hasGigantamaxEvolution pour savoir si on doit injecter une forme Dynamax
        let _hasGigantamax = try container.decodeIfPresent(Bool.self, forKey: .hasGigantamaxEvolution)
        hasGigantamaxEvolution = _hasGigantamax
        
        // Gestion des formes avec injection Dynamax
        var forms = try container.decodeIfPresent([AssetForm].self, forKey: .assetForms) ?? []
        
        if _hasGigantamax == true {
            // Si le Pokémon a une forme Gigantamax, on ajoute aussi une variante "DYNAMAX" générique
            // si elle n'existe pas déjà.
            if !forms.contains(where: { $0.form == "DYNAMAX" }) {
                let dynamaxForm = AssetForm(
                    form: "DYNAMAX",
                    costume: nil,
                    image: assets?.image,      // On reprend l'image de base
                    shinyImage: assets?.shinyImage // On reprend l'image shiny de base
                )
                forms.append(dynamaxForm)
            }
        }
        assetForms = forms.isEmpty ? nil : forms
        
        primaryType = try container.decodeIfPresent(PokemonTypeEntry.self, forKey: .primaryType)
        secondaryType = try container.decodeIfPresent(PokemonTypeEntry.self, forKey: .secondaryType)
        stats = try container.decodeIfPresent(PokemonStats.self, forKey: .stats)
        pokemonClass = try container.decodeIfPresent(String.self, forKey: .pokemonClass)
        evolutions = try container.decodeIfPresent([Evolution].self, forKey: .evolutions)
        hasMegaEvolution = try container.decodeIfPresent(Bool.self, forKey: .hasMegaEvolution)
        // hasGigantamaxEvolution déjà décodé plus haut
        
        // megaEvolutions: dict quand rempli, [] (array vide) quand vide
        if let dict = try? container.decode([String: MegaEvolution].self, forKey: .megaEvolutions) {
            megaEvolutions = dict.isEmpty ? nil : dict
        } else {
            megaEvolutions = nil
        }
        
        // regionForms: dict quand rempli, [] (array vide) quand vide
        if let dict = try? container.decode([String: RegionForm].self, forKey: .regionForms) {
            regionForms = dict.isEmpty ? nil : dict
        } else {
            regionForms = nil
        }
    }
    
    /// Liste des méga-évolutions (pour itération dans les vues).
    var megaEvolutionsList: [MegaEvolution] {
        guard let megas = megaEvolutions else { return [] }
        return Array(megas.values).sorted { $0.id < $1.id }
    }
    
    /// Liste des formes régionales (pour itération dans les vues).
    var regionFormsList: [RegionForm] {
        guard let regions = regionForms else { return [] }
        return Array(regions.values).sorted { $0.id < $1.id }
    }
    
    // MARK: - Propriétés calculées
    
    /// Indique si le Pokémon n'a aucune image (ni de base, ni de variante).
    var isNotAvailable: Bool {
        let hasNoBaseAssets = assets?.image == nil && assets?.shinyImage == nil
        let hasNoVariantAssets = assetForms?.allSatisfy({ $0.image == nil && $0.shinyImage == nil }) ?? true
        return hasNoBaseAssets && hasNoVariantAssets
    }
    
    /// Retourne le nom localisé (selon la langue du téléphone).
    /// Retourne le nom localisé (selon la langue du téléphone).
    /// Retourne le nom localisé (selon la langue du téléphone).
    var name: String {
        let key = localizedLanguageKey()
        return names[key] ?? names["English"] ?? "Inconnu"
    }
    
    /// Vérifie si le Pokémon a une forme Gigantamax.
    var isGigantamax: Bool {
        hasGigantamaxEvolution == true
    }
    
    /// Vérifie si le Pokémon a une forme Eternamax.
    var isEternamax: Bool {
        // Vérifier dans le mapping
        if Pokemon.eternamaxMapping[self.id] != nil {
            return true
        }
        // Vérifier dans assetForms
        if assetForms?.contains(where: { $0.form == "ETERNAMAX" }) == true {
            return true
        }
        // Vérifier dans regionForms via formId
        return regionFormsList.contains(where: { ($0.formId ?? $0.id).contains("ETERNAMAX") })
    }
    
    /// Retourne l'URL de l'Official Artwork (PokeAPI) haute qualité.
    var officialArtworkUrl: URL? {
        let urlString = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/\(dexNr).png"
        return URL(string: urlString)
    }
    
    /// Retourne l'URL de l'Official Artwork SHINY (PokeAPI) haute qualité.
    var officialShinyArtworkUrl: URL? {
        let urlString = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/shiny/\(dexNr).png"
        return URL(string: urlString)
    }

    /// Retourne l'URL de l'image principale (Assets du jeu).
    /// Priorité : assets.image → première image disponible dans assetForms → nil.
    var imageUrl: URL? {
        if let main = assets?.image, let url = URL(string: main) {
            return url
        }
        if let formImage = assetForms?.first(where: { $0.image != nil })?.image,
           let url = URL(string: formImage) {
            return url
        }
        return nil
    }
    
    /// URL de l'image shiny principale.
    var shinyImageUrl: URL? {
        if let shiny = assets?.shinyImage, let url = URL(string: shiny) {
            return url
        }
        if let formShiny = assetForms?.first(where: { $0.shinyImage != nil })?.shinyImage,
           let url = URL(string: formShiny) {
            return url
        }
        return nil
    }
    
    /// URL Haute Résolution (Home 3D Render) si disponible.
    var highResHomeImageUrl: URL? {
        let urlString = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/\(dexNr).png"
        return URL(string: urlString)
    }
    
    var highResHomeShinyImageUrl: URL? {
        let urlString = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/shiny/\(dexNr).png"
        return URL(string: urlString)
    }
    
    /// Couleur associée au type principal du Pokémon.
    var typeColor: Color? {
        guard let type = primaryType?.type else { return nil }
        return Self.colorForType(type)
    }
    
    /// Vérifie si le Pokémon est Légendaire.
    var isLegendary: Bool {
        pokemonClass == "POKEMON_CLASS_LEGENDARY"
    }
    
    /// Vérifie si le Pokémon est Fabuleux.
    var isMythic: Bool {
        pokemonClass == "POKEMON_CLASS_MYTHIC"
    }
    
    /// Vérifie si le Pokémon est Ultra Beast.
    var isUltraBeast: Bool {
        pokemonClass == "POKEMON_CLASS_ULTRA_BEAST"
    }
    
    /// Nom localisé du type principal.
    var primaryTypeName: String? {
        guard let names = primaryType?.names else { return nil }
        let key = localizedLanguageKey()
        return names[key] ?? names["English"]
    }
    
    /// Nom localisé du type secondaire.
    var secondaryTypeName: String? {
        guard let names = secondaryType?.names else { return nil }
        let key = localizedLanguageKey()
        return names[key] ?? names["English"]
    }
    
    /// Couleur pour un type donné.
    static func colorForType(_ type: String) -> Color {
        switch type {
        case "POKEMON_TYPE_NORMAL": return .gray
        case "POKEMON_TYPE_FIGHTING": return .orange
        case "POKEMON_TYPE_FLYING": return .blue.opacity(0.6)
        case "POKEMON_TYPE_POISON": return .purple
        case "POKEMON_TYPE_GROUND": return .brown
        case "POKEMON_TYPE_ROCK": return .brown.opacity(0.6)
        case "POKEMON_TYPE_BUG": return .green
        case "POKEMON_TYPE_GHOST": return .purple.opacity(0.8)
        case "POKEMON_TYPE_STEEL": return .gray.opacity(0.8)
        case "POKEMON_TYPE_FIRE": return .red
        case "POKEMON_TYPE_WATER": return .blue
        case "POKEMON_TYPE_GRASS": return .green
        case "POKEMON_TYPE_ELECTRIC": return .yellow
        case "POKEMON_TYPE_PSYCHIC": return .pink
        case "POKEMON_TYPE_ICE": return .cyan
        case "POKEMON_TYPE_DRAGON": return .indigo
        case "POKEMON_TYPE_DARK": return .black.opacity(0.8)
        case "POKEMON_TYPE_FAIRY": return .pink.opacity(0.6)
        default: return .blue
        }
    }
}

/// Structure contenant les URLs des images de base.
struct Assets: Codable {
    let image: String?
    let shinyImage: String?
}

/// Stats de combat d'un Pokémon.
struct PokemonStats: Codable {
    let stamina: Int?
    let attack: Int?
    let defense: Int?
}

/// Structure pour décoder le type (Primary/Secondary).
struct PokemonTypeEntry: Codable {
    let type: String
    let names: [String: String]
}

/// Évolution d'un Pokémon.
struct Evolution: Codable, Identifiable {
    let id: String
    let formId: String?
    let candies: Int?
    let item: EvolutionItem?
    let quests: [EvolutionQuest]?
}

/// Objet requis pour une évolution (Pierre Soleil, etc.).
struct EvolutionItem: Codable {
    let id: String?
    let names: [String: String]?
    
    /// Nom localisé de l'objet.
    var name: String {
        let key = localizedLanguageKey()
        return names?[key] ?? names?["English"] ?? (id ?? "")
    }
}

/// Quête/condition pour une évolution.
struct EvolutionQuest: Codable {
    let id: String?
    let type: String?
}

/// Forme régionale d'un Pokémon.
struct RegionForm: Codable, Identifiable {
    let id: String
    let formId: String?
    let dexNr: Int?
    let generation: Int?
    let names: [String: String]?
    let stats: PokemonStats?
    let primaryType: PokemonTypeEntry?
    let secondaryType: PokemonTypeEntry?
    let assets: Assets?
    let evolutions: [Evolution]?
    
    var name: String {
        let key = localizedLanguageKey()
        return names?[key] ?? names?["English"] ?? id.capitalized
    }
    
    var imageUrl: URL? {
        guard let img = assets?.image else { return nil }
        return URL(string: img)
    }
    
    var shinyImageUrl: URL? {
        guard let img = assets?.shinyImage else { return nil }
        return URL(string: img)
    }
    
    /// Identifie la région d'après l'ID (RATTATA_ALOLA → "Alola")
    var regionName: String {
        if id.contains("ALOLA") { return "Alola" }
        if id.contains("GALARIAN") || id.contains("GALAR") { return "Galar" }
        if id.contains("HISUIAN") || id.contains("HISUI") { return "Hisui" }
        if id.contains("PALDEA") { return "Paldea" }
        return "Régional"
    }
}

/// Méga-évolution d'un Pokémon.
struct MegaEvolution: Codable, Identifiable {
    let id: String
    let names: [String: String]?
    let stats: PokemonStats?
    let primaryType: PokemonTypeEntry?
    let secondaryType: PokemonTypeEntry?
    let assets: MegaAssets?
    
    var name: String {
        let key = localizedLanguageKey()
        return names?[key] ?? names?["English"] ?? id.capitalized
    }
    
    var imageUrl: URL? {
        guard let img = assets?.image else { return nil }
        return URL(string: img)
    }
    
    var shinyImageUrl: URL? {
        guard let img = assets?.shinyImage else { return nil }
        return URL(string: img)
    }
    
    /// Haute résolution de l'image normale (Official Artwork si disponible)
    var highResImageURL: URL? {
        // 1. Essayer le mapping ID manuel (pour avoir l'artwork officiel)
        if let id = Pokemon.megaMapping[self.id] {
            return URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/\(id).png")
        }
        
        // 2. Sinon, pas d'image HD
        return nil
    }
    
    /// Haute résolution de l'image shiny (Official Artwork si disponible)
    var highResShinyImageURL: URL? {
        if let id = Pokemon.megaMapping[self.id] {
            return URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/shiny/\(id).png")
        }
        return nil
    }
}

struct MegaAssets: Codable {
    let image: String?
    let shinyImage: String?
}

/// Structure représentant une variante (forme ou costume) d'un Pokémon.
struct AssetForm: Codable, Identifiable {
    // IMPORTANT: ID stable pour SwiftUI, on combine form+costume+image
    // pour garantir l'unicité sans UUID() qui change à chaque rendu.
    var id: String {
        let f = form ?? "_"
        let c = costume ?? "_"
        let i = image ?? "_"
        return "\(f)_\(c)_\(i)"
    }
    
    let form: String?
    let costume: String?
    let image: String?
    let shinyImage: String?
    
    /// URL de l'image de cette forme.
    var imageURL: URL? {
        guard let img = image else { return nil }
        return URL(string: img)
    }
    
    /// URL Haute Résolution (Home 3D Render) si disponible.
    var highResImageURL: URL? {
        guard let img = image else { return nil }
        // Pas de HD pour les costumes (chapeaux, etc.) car souvent indisponibles
        guard costume == nil else { return imageURL }
        
        let highRes = img.replacingOccurrences(of: "/sprites/pokemon/", with: "/sprites/pokemon/other/official-artwork/")
        return URL(string: highRes)
    }
    
    var shinyImageURL: URL? {
        guard let img = shinyImage else { return nil }
        return URL(string: img)
    }
    
    /// URL Haute Résolution Shiny (Home 3D Render) si disponible.
    var highResShinyImageURL: URL? {
        guard let img = shinyImage else { return nil }
        guard costume == nil else { return shinyImageURL }
        
        let highRes = img.replacingOccurrences(of: "/sprites/pokemon/", with: "/sprites/pokemon/other/official-artwork/")
        return URL(string: highRes)
    }
    
    /// Nom affichable de la variante.
    var displayName: String {
        if let costume = costume {
            return costume.replacingOccurrences(of: "_", with: " ").capitalized
        }
        if let form = form {
            return form.replacingOccurrences(of: "_", with: " ").capitalized
        }
        return "Standard"
    }
}

extension AssetForm {
    static let standard = AssetForm(form: "NORMAL", costume: nil, image: nil, shinyImage: nil)
}


extension Pokemon {
    /// Retourne l'URL HD (Official Artwork) pour une forme donnée (Gmax, etc.)
    func highResImageURL(for form: AssetForm, shiny: Bool) -> URL? {
        // GIGANTAMAX
        if let formName = form.form, (formName == "GIGANTAMAX" || formName == "GIGANTAMAX_MEGA") {
            if let gmaxID = Pokemon.gmaxMapping[self.id] {
                let path = shiny ? "shiny/" : ""
                return URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/\(path)\(gmaxID).png")
            }
        }
        
        // ETERNAMAX
        if let formName = form.form, formName == "ETERNAMAX" {
            if let eternalID = Pokemon.eternamaxMapping[self.id] {
                let path = shiny ? "shiny/" : ""
                return URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/\(path)\(eternalID).png")
            }
        }
        
        return shiny ? form.highResShinyImageURL : form.highResImageURL
    }

    static let megaMapping: [String: Int] = [
        "ABOMASNOW_MEGA": 10060,
        "ABSOL_MEGA": 10057,
        "ABSOL_MEGA_Z": 10307,
        "AERODACTYL_MEGA": 10042,
        "AGGRON_MEGA": 10053,
        "ALAKAZAM_MEGA": 10037,
        "ALTARIA_MEGA": 10067,
        "AMPHAROS_MEGA": 10045,
        "AUDINO_MEGA": 10069,
        "BANETTE_MEGA": 10056,
        "BARBARACLE_MEGA": 10298,
        "BAXCALIBUR_MEGA": 10325,
        "BEEDRILL_MEGA": 10090,
        "BLASTOISE_MEGA": 10036,
        "BLAZIKEN_MEGA": 10050,
        "CAMERUPT_MEGA": 10087,
        "CHANDELURE_MEGA": 10291,
        "CHARIZARD_MEGA_X": 10034,
        "CHARIZARD_MEGA_Y": 10035,
        "CHESNAUGHT_MEGA": 10292,
        "CHIMECHO_MEGA": 10306,
        "CLEFABLE_MEGA": 10278,
        "CRABOMINABLE_MEGA": 10315,
        "DARKRAI_MEGA": 10312,
        "DELPHOX_MEGA": 10293,
        "DIANCIE_MEGA": 10075,
        "DRAGALGE_MEGA": 10299,
        "DRAGONITE_MEGA": 10281,
        "DRAMPA_MEGA": 10302,
        "EELEKTROSS_MEGA": 10290,
        "EMBOAR_MEGA": 10286,
        "EXCADRILL_MEGA": 10287,
        "FALINKS_MEGA": 10303,
        "FERALIGATR_MEGA": 10283,
        "FLOETTE_MEGA": 10296,
        "FROSLASS_MEGA": 10285,
        "GALLADE_MEGA": 10068,
        "GARCHOMP_MEGA": 10058,
        "GARCHOMP_MEGA_Z": 10309,
        "GARDEVOIR_MEGA": 10051,
        "GENGAR_MEGA": 10038,
        "GLALIE_MEGA": 10074,
        "GLIMMORA_MEGA": 10321,
        "GOLISOPOD_MEGA": 10316,
        "GOLURK_MEGA": 10313,
        "GRENINJA_MEGA": 10294,
        "GYARADOS_MEGA": 10041,
        "HAWLUCHA_MEGA": 10300,
        "HEATRAN_MEGA": 10311,
        "HERACROSS_MEGA": 10047,
        "HOUNDOOM_MEGA": 10048,
        "KANGASKHAN_MEGA": 10039,
        "LATIAS_MEGA": 10062,
        "LATIOS_MEGA": 10063,
        "LOPUNNY_MEGA": 10088,
        "LUCARIO_MEGA": 10059,
        "LUCARIO_MEGA_Z": 10310,
        "MAGEARNA_MEGA": 10317,
        "MAGEARNA_ORIGINAL_MEGA": 10318,
        "MALAMAR_MEGA": 10297,
        "MANECTRIC_MEGA": 10055,
        "MAWILE_MEGA": 10052,
        "MEDICHAM_MEGA": 10054,
        "MEGANIUM_MEGA": 10282,
        "MEOWSTIC_MEGA": 10314,
        "METAGROSS_MEGA": 10076,
        "MEWTWO_MEGA_X": 10043,
        "MEWTWO_MEGA_Y": 10044,
        "PIDGEOT_MEGA": 10073,
        "PINSIR_MEGA": 10040,
        "PYROAR_MEGA": 10295,
        "RAICHU_MEGA_X": 10304,
        "RAICHU_MEGA_Y": 10305,
        "RAYQUAZA_MEGA": 10079,
        "SABLEYE_MEGA": 10066,
        "SALAMENCE_MEGA": 10089,
        "SCEPTILE_MEGA": 10065,
        "SCIZOR_MEGA": 10046,
        "SCOLIPEDE_MEGA": 10288,
        "SCOVILLAIN_MEGA": 10320,
        "SCRAFTY_MEGA": 10289,
        "SHARPEDO_MEGA": 10070,
        "SKARMORY_MEGA": 10284,
        "SLOWBRO_MEGA": 10071,
        "STARAPTOR_MEGA": 10308,
        "STARMIE_MEGA": 10280,
        "STEELIX_MEGA": 10072,
        "SWAMPERT_MEGA": 10064,
        "TATSUGIRI_CURLY_MEGA": 10322,
        "TATSUGIRI_DROOPY_MEGA": 10323,
        "TATSUGIRI_STRETCHY_MEGA": 10324,
        "TYRANITAR_MEGA": 10049,
        "VENUSAUR_MEGA": 10033,
        "VICTREEBEL_MEGA": 10279,
        "ZERAORA_MEGA": 10319,
        "ZYGARDE_MEGA": 10301
    ]

    static let eternamaxMapping: [String: Int] = [
        "ETERNATUS": 10190
    ]
    
    static let gmaxMapping: [String: Int] = [
        "ALCREMIE": 10223,
        "APPLETUN": 10217,
        "BLASTOISE": 10197,
        "BUTTERFREE": 10198,
        "CENTISKORCH": 10220,
        "CHARIZARD": 10196,
        "CINDERACE": 10210,
        "COALOSSAL": 10215,
        "COPPERAJAH": 10224,
        "CORVIKNIGHT": 10212,
        "DREDNAW": 10214,
        "DURALUDON": 10225,
        "EEVEE": 10205,
        "FLAPPLE": 10216,
        "GARBODOR": 10207,
        "GENGAR": 10202,
        "GRIMMSNARL": 10222,
        "HATTERENE": 10221,
        "INTELEON": 10211,
        "KINGLER": 10203,
        "LAPRAS": 10204,
        "MACHAMP": 10201,
        "MELMETAL": 10208,
        "MEOWTH": 10200,
        "ORBEETLE": 10213,
        "PIKACHU": 10199,
        "RILLABOOM": 10209,
        "SANDACONDA": 10218,
        "SNORLAX": 10206,
        "TOXTRICITY-AMPED": 10219,
        "TOXTRICITY-LOW-KEY": 10228,
        "URSHIFU-RAPID-STRIKE": 10227,
        "URSHIFU-SINGLE-STRIKE": 10226,
        "VENUSAUR": 10195
    ]
}
