import Foundation
import SwiftUI
import Combine

// MARK: - Event Extra Data

struct ExtraDataPokemon: Decodable, Identifiable {
    let name: String
    let image: String
    var id: String { "\(name)-\(image)" }
}

struct ExtraDataBonus: Decodable, Identifiable {
    let text: String
    let image: String
    var id: String { text }
}

struct CommunityDayData: Decodable {
    let spawns: [ExtraDataPokemon]?
    let bonuses: [ExtraDataBonus]?
    let bonusDisclaimers: [String]?
    let shinies: [ExtraDataPokemon]?
}

struct RaidBossExtra: Decodable, Identifiable {
    let name: String
    let image: String
    let canBeShiny: Bool?
    var id: String { "\(name)-\(image)" }
}

struct RaidBattlesExtraData: Decodable {
    let bosses: [RaidBossExtra]?
    let shinies: [ExtraDataPokemon]?
}

struct GenericExtraData: Decodable {
    let hasSpawns: Bool?
    let hasFieldResearchTasks: Bool?
}

struct EventExtraData: Decodable {
    let communityday: CommunityDayData?
    let raidbattles: RaidBattlesExtraData?
    let promocodes: [String]?
    let generic: GenericExtraData?
}

// MARK: - LeekDuck Event
struct LeekDuckEvent: Decodable, Identifiable {
    let eventID: String
    let name: String
    let eventType: String
    let heading: String
    let link: String?
    let image: String?
    let start: String
    let end: String
    let extraData: EventExtraData?
    
    var id: String { eventID }
    
    var startDate: Date {
        let df = DateFormatter()
        let cleanStr = start.components(separatedBy: ".").first ?? start
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        df.timeZone = .current
        return df.date(from: cleanStr) ?? Date()
    }
    
    var endDate: Date {
        let df = DateFormatter()
        let cleanStr = end.components(separatedBy: ".").first ?? end
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        df.timeZone = .current
        return df.date(from: cleanStr) ?? Date()
    }
    
    var isActive: Bool {
        let now = Date()
        return startDate <= now && endDate > now
    }
    
    var isUpcoming: Bool {
        return startDate > Date()
    }
    
    var daysRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: endDate)
        return max(0, components.day ?? 0)
    }
    
    var hoursRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour], from: Date(), to: endDate)
        return max(0, components.hour ?? 0)
    }
    
    var timeRemainingText: String {
        let days = daysRemaining
        if isUpcoming {
            if days > 0 { return "Dans \(days)j" }
            let hours = hoursRemaining
            if hours > 0 { return "Dans \(hours)h" }
            return "Bientôt"
        } else {
            if days > 0 { return "\(days)j restant\(days > 1 ? "s" : "")" }
            let hours = hoursRemaining
            if hours > 0 { return "\(hours)h restante\(hours > 1 ? "s" : "")" }
            return "Bientôt terminé"
        }
    }

    var progressPercentage: Double {
        let total = endDate.timeIntervalSince(startDate)
        let elapsed = Date().timeIntervalSince(startDate)
        guard total > 0 else { return 0 }
        return max(0, min(1, elapsed / total))
    }
    
    var iconName: String {
        switch eventType {
        case "community-day": return "person.3.fill"
        case "season": return "leaf.fill"
        case "raid-battles", "raid-hour", "raid-day": return "bolt.shield.fill"
        case "spotlight-hour": return "star.circle.fill"
        case "research", "research-day": return "magnifyingglass"
        case "pokecoin-bounty": return "dollarsign.circle.fill"
        case "max-battles", "max-mondays": return "sparkles"
        default: return "calendar.badge.clock"
        }
    }
    
    var isSeason: Bool {
        return eventType == "season"
    }
}

// MARK: - LeekDuck Raid
struct LeekDuckRaidType: Decodable {
    let name: String
    let image: String?
}

struct LeekDuckRaidCPRange: Decodable {
    let min: Int
    let max: Int
}

struct LeekDuckRaidCP: Decodable {
    let normal: LeekDuckRaidCPRange
    let boosted: LeekDuckRaidCPRange
}

struct LeekDuckRaid: Decodable, Identifiable {
    var id = UUID()
    let name: String
    let tier: String
    let canBeShiny: Bool?
    let types: [LeekDuckRaidType]?
    let combatPower: LeekDuckRaidCP?
    let image: String
    
    enum CodingKeys: String, CodingKey {
        case name, tier, canBeShiny, types, combatPower, image
    }
}

// MARK: - LeekDuck Research
struct LeekDuckResearchReward: Decodable, Identifiable {
    let name: String
    let image: String
    let canBeShiny: Bool?
    let combatPower: LeekDuckRaidCPRange?
    
    var id: String { "\(name)-\(image)" }
}

struct LeekDuckResearch: Decodable, Identifiable {
    var id = UUID()
    let text: String
    let rewards: [LeekDuckResearchReward]
    
    enum CodingKeys: String, CodingKey {
        case text, rewards
    }
}

// MARK: - LeekDuck Egg
struct LeekDuckEgg: Decodable, Identifiable {
    var id = UUID()
    let name: String
    let eggType: String
    let isAdventureSync: Bool?
    let image: String
    let canBeShiny: Bool?
    let combatPower: LeekDuckRaidCPRange?
    let isRegional: Bool?
    let isGiftExchange: Bool?
    let rarity: Int?
    
    enum CodingKeys: String, CodingKey {
        case name, eggType, isAdventureSync, image, canBeShiny, combatPower, isRegional, isGiftExchange, rarity
    }
}

// MARK: - LeekDuck Rocket Lineup
struct LeekDuckRocketPokemon: Decodable, Identifiable {
    let name: String
    let image: String
    let types: [String]?
    let isEncounter: Bool?
    let canBeShiny: Bool?
    
    var id: String { "\(name)-\(image)" }
}

struct LeekDuckRocket: Decodable, Identifiable {
    var id = UUID()
    let name: String
    let title: String
    let type: String
    let firstPokemon: [LeekDuckRocketPokemon]?
    let secondPokemon: [LeekDuckRocketPokemon]?
    let thirdPokemon: [LeekDuckRocketPokemon]?
    
    enum CodingKeys: String, CodingKey {
        case name, title, type, firstPokemon, secondPokemon, thirdPokemon
    }
}

@MainActor
final class GameEventsViewModel: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case overview = "Aperçu"
        case raids = "Raids"
        case quests = "Quêtes"
        case eggs = "Œufs"
        case rocket = "Rocket"

        var id: String { rawValue }
        var title: String { rawValue }
    }

    @Published var mode: Mode = .overview
    
    // Contenu
    @Published var activeSeason: LeekDuckEvent?
    @Published var activeEvents: [LeekDuckEvent] = []
    @Published var upcomingEvents: [LeekDuckEvent] = []
    
    @Published var raidsList: [LeekDuckRaid] = []
    @Published var researches: [LeekDuckResearch] = []
    @Published var eggs: [LeekDuckEgg] = []
    @Published var rockets: [LeekDuckRocket] = []

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    var hasAnyContent: Bool {
        activeSeason != nil || !activeEvents.isEmpty || !raidsList.isEmpty || !researches.isEmpty || !eggs.isEmpty || !rockets.isEmpty
    }

    func isCurrentModeEmpty() -> Bool {
        switch mode {
        case .overview: return false
        case .raids: return raidsList.isEmpty
        case .quests: return researches.isEmpty
        case .eggs: return eggs.isEmpty
        case .rocket: return rockets.isEmpty
        }
    }

    func fetchAll() async {
        isLoading = true
        errorMessage = nil
        print("🚀 Début fetchAll()")

        async let eventsTask = fetchGenericArray(url: "https://raw.githubusercontent.com/bigfoott/ScrapedDuck/data/events.json", type: LeekDuckEvent.self)
        async let raidsTask = fetchGenericArray(url: "https://raw.githubusercontent.com/bigfoott/ScrapedDuck/data/raids.json", type: LeekDuckRaid.self)
        async let researchTask = fetchGenericArray(url: "https://raw.githubusercontent.com/bigfoott/ScrapedDuck/data/research.json", type: LeekDuckResearch.self)
        async let eggsTask = fetchGenericArray(url: "https://raw.githubusercontent.com/bigfoott/ScrapedDuck/data/eggs.json", type: LeekDuckEgg.self)
        async let rocketTask = fetchGenericArray(url: "https://raw.githubusercontent.com/bigfoott/ScrapedDuck/data/rocketLineups.json", type: LeekDuckRocket.self)

        let allEvents = await eventsTask ?? []
        self.raidsList = await raidsTask ?? []
        self.researches = await researchTask ?? []
        self.eggs = await eggsTask ?? []
        self.rockets = await rocketTask ?? []

        print("📦 Données récupérées: \(allEvents.count) events, \(raidsList.count) raids, \(researches.count) researches, \(eggs.count) eggs, \(rockets.count) rockets")

        let now = Date()
        let validEvents = allEvents.filter { $0.endDate >= now }
        self.activeSeason = validEvents.first(where: { $0.isActive && $0.isSeason })
        self.activeEvents = validEvents.filter { $0.isActive && !$0.isSeason }.sorted { $0.endDate < $1.endDate }
        self.upcomingEvents = validEvents.filter { $0.isUpcoming }.sorted { $0.startDate < $1.startDate }

        lastUpdated = Date()
        isLoading = false

        if !hasAnyContent {
            errorMessage = "Impossible de charger les données depuis LeekDuck."
        }
        print("✅ Fin fetchAll()")
    }
    
    private func fetchGenericArray<T: Decodable>(url: String, type: T.Type) async -> [T]? {
        guard let urlObj = URL(string: url) else {
            print("❌ URL invalide: \(url)")
            return nil
        }
        do {
            print("🔄 Fetch en cours: \(url)")
            let (data, _) = try await URLSession.shared.data(from: urlObj)
            let decoded = try JSONDecoder().decode([T].self, from: data)
            print("✅ Succès \(type): \(decoded.count) items")
            return decoded
        } catch {
            print("❌ Erreur chargement \(url): \(error)")
            if let decodingError = error as? DecodingError {
                print("   Details: \(decodingError)")
            }
            return nil
        }
    }

}
