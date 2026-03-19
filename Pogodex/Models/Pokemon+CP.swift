import Foundation

// MARK: - Calcul des PC
extension PokemonStats {
    /// Calcule le PC (Points de Combat) théorique d'un Pokémon selon ses stats de base, ses IV et son niveau.
    /// La formule exacte de Pokémon GO est: Max(10, Floor((Att + ivAtt) * Sqrt(Def + ivDef) * Sqrt(Sta + ivSta) * CPM^2 / 10))
    func calculateCP(level: Int, ivAttack: Int = 15, ivDefense: Int = 15, ivStamina: Int = 15) -> Int {
        guard let baseAtt = attack, let baseDef = defense, let baseSta = stamina else { return 10 }
        
        let cpm = CPMultiplier(for: level)
        let totalAtt = Double(baseAtt + ivAttack)
        let totalDef = Double(baseDef + ivDefense)
        let totalSta = Double(baseSta + ivStamina)
        
        let cp = (totalAtt * sqrt(totalDef) * sqrt(totalSta) * pow(cpm, 2)) / 10.0
        
        return max(10, Int(floor(cp)))
    }
    
    // PC Parfaits (IV 15/15/15) pour les niveaux clés
    var maxCpLevel15: Int { calculateCP(level: 15) } // Obtenu via Recherche Spéciale
    var maxCpLevel20: Int { calculateCP(level: 20) } // Obtenu via Raid ou Oeuf
    var maxCpLevel25: Int { calculateCP(level: 25) } // Obtenu via Raid Boosté Météo
    var maxCpLevel50: Int { calculateCP(level: 50) } // Max absolu du Pokémon
}

// MARK: - Accès depuis le modèle Pokemon
extension Pokemon {
    /// Retourne le PC max niveau 50 (Parfait 100%)
    var maxCP50: Int? { stats?.maxCpLevel50 }
    
    /// Retourne le PC généré en raid normal (Niveau 20, Parfait 100%)
    var perfectRaidCP: Int? { stats?.maxCpLevel20 }
    
    /// Retourne le PC généré en raid avec boost météo (Niveau 25, Parfait 100%)
    var perfectRaidBoostedCP: Int? { stats?.maxCpLevel25 }
    
    /// Retourne le PC généré en quête/recherche (Niveau 15, Parfait 100%)
    var perfectQuestCP: Int? { stats?.maxCpLevel15 }
}

/// Renvoie le "CP Multiplier" (CPM) officiel utilisé par le jeu pour un niveau donné.
private func CPMultiplier(for level: Int) -> Double {
    let cpmMap: [Int: Double] = [
        15: 0.51739395,
        20: 0.59740001,
        25: 0.66793400,
        50: 0.84029999
    ]
    // Retourne la valeur ou approximativement la valeur lvl 50 si non trouvé
    return cpmMap[level] ?? 0.84029999
}
