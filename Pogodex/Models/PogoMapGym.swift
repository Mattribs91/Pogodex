import SwiftUI
import CoreLocation

// MARK: - PogoMapGym

struct PogoMapGym: Identifiable, Hashable {
    let id: String
    let name: String?
    let url: String?
    let lat: Double
    let lon: Double
    let teamId: Int?
    let availableSlots: Int?
    let totalCp: Int?
    let guardingPokemonId: Int?
    let defenders: [PogoMapDefender]?
    let raidLevel: Int?
    let raidBattleTimestamp: Int?
    let raidEndTimestamp: Int?
    let raidPokemonId: Int?
    let raidPokemonForm: Int?
    let raidPokemonMove1: Int?
    let raidPokemonMove2: Int?
    let raidPokemonCp: Int?
    let raidPokemonGender: Int?
    let raidPokemonEvolution: Int?
    let exRaidEligible: Bool?
    let inBattle: Bool?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var hasActiveRaid: Bool {
        guard let end = raidEndTimestamp, let level = raidLevel, level > 0 else { return false }
        let extendedEnd = Date(timeIntervalSince1970: TimeInterval(end)).addingTimeInterval(5 * 60)
        return extendedEnd > .now
    }

    var isRaidHatched: Bool {
        guard hasActiveRaid else { return false }
        if let pokemonId = raidPokemonId, pokemonId > 0 { return true }
        guard let battle = raidBattleTimestamp else { return false }
        return Date(timeIntervalSince1970: TimeInterval(battle)) <= .now
    }

    var teamColor: Color {
        switch teamId {
        case 1: .blue
        case 2: .red
        case 3: .yellow
        default: .gray
        }
    }

    var teamName: String {
        switch teamId {
        case 1: "Mystic"
        case 2: "Valor"
        case 3: "Instinct"
        default: "Neutre"
        }
    }

    var raidLevelColor: Color {
        switch raidLevel {
        case 1: .pink
        case 3: .orange
        case 4, 6, 7: .brown
        case 5: .purple
        case 8: .red
        case 9, 10, 11: Color(red: 0.6, green: 0.2, blue: 0.8)
        case 13, 14, 15: .pink
        default: .red
        }
    }

    static func == (lhs: PogoMapGym, rhs: PogoMapGym) -> Bool {
        lhs.id == rhs.id &&
        lhs.raidLevel == rhs.raidLevel &&
        lhs.raidEndTimestamp == rhs.raidEndTimestamp &&
        lhs.raidPokemonId == rhs.raidPokemonId &&
        lhs.teamId == rhs.teamId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(raidLevel)
        hasher.combine(raidEndTimestamp)
    }
}

// MARK: - Raid tier labels

extension PogoMapGym {
    static func raidTierLabel(_ level: Int) -> String {
        switch level {
        case 1: "Raid ★1"
        case 3: "Raid ★3"
        case 4, 6: "Méga Raid"
        case 5: "Raid ★5"
        case 7: "Méga Légendaire"
        case 8: "Raid Primo"
        case 9: "Raid Obscur T1"
        case 10: "Raid Obscur T3"
        case 11: "Raid Obscur T5"
        case 12: "Raid Élite"
        case 13: "Combat Max T1"
        case 14: "Combat Max T3"
        case 15: "Combat Max / Gigamax"
        default: "Raid Niv.\(level)"
        }
    }

    static func raidTierShortLabel(_ level: Int) -> String {
        switch level {
        case 1: "T1"
        case 3: "T3"
        case 4: "Méga"
        case 5: "T5"
        case 6: "Méga"
        case 7: "M-Lég"
        case 8: "Primo"
        case 9: "Obs. 1"
        case 10: "Obs. 3"
        case 11: "Obs. 5"
        case 12: "Élite"
        case 13: "Max 1"
        case 14: "Max 3"
        case 15: "Max 5"
        default: "★\(level)"
        }
    }
}

// MARK: - PogoMapDefender

struct PogoMapDefender {
    let pokemonId: Int
    let cpNow: Int
    let cpWhenDeployed: Int
    let motivationNow: Double?
}
