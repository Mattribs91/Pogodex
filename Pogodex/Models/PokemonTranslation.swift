import Foundation

struct PokemonTranslation {
    static let formMappings: [String: String] = [
        // Pikachu Cosplay
        "POP_STAR": "Starteur",
        "ROCK_STAR": "Rockeur",
        "LIBRE": "Catcheur",
        "PH_D": "Docteur",
        "FLYING": "Volant",
        "SURFING": "Surfeur",
        
        // Costumes Génériques
        "ANNIVERSARY": "Anniversaire",
        "COSTUME": "Costumé",
        "HALLOWEEN": "Halloween",
        "HOLIDAY": "Fêtes",
        "WINTER": "Hiver",
        "SUMMER": "Été",
        "SPRING": "Printemps",
        "FALL": "Automne",
        "FLOWER_CROWN": "Couronne Fleurs",
        "STRAW_HAT": "Chapeau Paille",
        "PARTY_HAT": "Chapeau Fête",
        "SANTA_HAT": "Bonnet Noël",
        "WITCH_HAT": "Chapeau Sorcière",
        "DETECTIVE": "Détective",
        
        // Formes Régionales / Autre
        "ALOLA": "Alola",
        "GALARIAN": "Galar",
        "HISUIAN": "Hisui",
        "PALDEA": "Paldea",
        "SHADOW": "Obscur",
        "PURIFIED": "Purifié",
        "ARMORED": "Armure",
        "CLONE": "Clone",
        
        // Méga / Primo / Gigantamax
        "MEGA": "Méga",
        "PRIMAL": "Primo",
        "GIGANTAMAX": "Gigamax",
        "DYNAMAX": "Dynamax",
        "NORMAL": "Standard"
    ]
    
    static func translate(name: String, for pokemonName: String) -> String {
        let language = localizedLanguageKey()
        
        // 1. Nettoyage préliminaire : Enlever le nom du Pokémon (ex: "PIKACHU_POP_STAR" -> "POP_STAR")
        var cleanName = name.uppercased()
            .replacingOccurrences(of: pokemonName.uppercased(), with: "")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Si vide après nettoyage (ex: "PIKACHU" -> ""), retour au nom original
        if cleanName.isEmpty { cleanName = name.uppercased() }
        
        // Si la langue est Anglais (ou non supportée dans le mapping), on retourne le nom nettoyé en Title Case
        if language == "English" {
            return cleanName.capitalized
        }
        
        // Si la langue est Français, on utilise le mapping
        if language == "French" {
            let parts = cleanName.components(separatedBy: " ")
            var translatedParts: [String] = []
            
            for part in parts {
                if let mapped = formMappings[part] {
                    translatedParts.append(mapped)
                } else {
                    translatedParts.append(part.capitalized)
                }
            }
            return translatedParts.joined(separator: " ")
        }
        
        // Fallback pour les autres langues (Allemand, Espagnol...) :
        // Idéalement il faudrait des mappings dédiés, mais pour l'instant on garde l'anglais propre.
        return cleanName.capitalized
    }
}
