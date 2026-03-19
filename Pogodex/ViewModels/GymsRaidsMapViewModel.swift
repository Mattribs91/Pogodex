import Combine
import MapKit

@MainActor
final class GymsRaidsMapViewModel: ObservableObject {
    @Published var displayedGyms: [PogoMapGym] = []
    @Published var displayedHundos: [PogoMapPokemon] = []
    @Published var isLoadingMap = false
    @Published var mapError: String?

    private var allGyms: [String: PogoMapGym] = [:]
    private var allHundos: [String: PogoMapPokemon] = [:]
    private var currentLoadTask: Task<Void, Never>?
    private var blockedUntil = Date.distantPast

    func loadMap(in region: MKCoordinateRegion, minIV: Double = 100.0) async {
        guard Date.now >= blockedUntil else { return }

        currentLoadTask?.cancel()
        let task = Task {
            await _loadMap(in: region, minIV: minIV)
        }
        currentLoadTask = task
        await task.value
    }

    private func _loadMap(in region: MKCoordinateRegion, minIV: Double) async {
        isLoadingMap = true
        mapError = nil

        async let gymRequest = PogoMapFetcher.fetchGyms(in: region)
        async let hundoRequest = PogoMapFetcher.fetchHundos(in: region, minIV: minIV)

        let (gymResult, hundoResult) = await (gymRequest, hundoRequest)

        guard !Task.isCancelled else {
            isLoadingMap = false
            return
        }

        // MARK: Process hundos

        switch hundoResult {
        case .success(let fetchedHundos):
            let now = Int(Date.now.timeIntervalSince1970)
            for poke in fetchedHundos where poke.expireTimestamp > now {
                allHundos[poke.id] = poke
            }
            allHundos = allHundos.filter { $0.value.expireTimestamp > now }

            let center = region.center
            if allHundos.count > 300 {
                let capped = allHundos.values
                    .sorted { abs($0.lat - center.latitude) + abs($0.lon - center.longitude) < abs($1.lat - center.latitude) + abs($1.lon - center.longitude) }
                    .prefix(200)
                allHundos = Dictionary(uniqueKeysWithValues: capped.map { ($0.id, $0) })
            }

            let delta = region.span.latitudeDelta
            let gridSize: Double = {
                if delta > 0.1 { return 0.008 }
                if delta > 0.05 { return 0.004 }
                if delta > 0.025 { return 0.002 }
                if delta > 0.015 { return 0.001 }
                return 0
            }()

            let isVisible: (PogoMapPokemon) -> Bool
            if gridSize > 0 {
                let snapLat = max(gridSize, delta)
                let snapLon = max(gridSize, region.span.longitudeDelta)
                let hMinLat = floor((center.latitude - snapLat) / gridSize) * gridSize
                let hMaxLat = ceil((center.latitude + snapLat) / gridSize) * gridSize
                let hMinLon = floor((center.longitude - snapLon) / gridSize) * gridSize
                let hMaxLon = ceil((center.longitude + snapLon) / gridSize) * gridSize
                isVisible = { $0.lat >= hMinLat && $0.lat <= hMaxLat && $0.lon >= hMinLon && $0.lon <= hMaxLon }
            } else {
                isVisible = { abs($0.lat - center.latitude) <= delta && abs($0.lon - center.longitude) <= region.span.longitudeDelta }
            }
            let visibleHundos = allHundos.values.filter(isVisible)

            var stableSet = displayedHundos.filter { poke in
                poke.expireTimestamp > now && allHundos[poke.id] != nil && isVisible(poke)
            }
            if gridSize > 0 {
                var occupiedCells = Set<String>()
                var occupiedIds = Set<String>()
                for poke in stableSet {
                    occupiedCells.insert("\(Int(floor(poke.lon / gridSize)))_\(Int(floor(poke.lat / gridSize)))")
                    occupiedIds.insert(poke.id)
                }
                for poke in visibleHundos.filter({ !occupiedIds.contains($0.id) })
                    .sorted(by: { $0.iv != $1.iv ? $0.iv > $1.iv : $0.id < $1.id }) {
                    guard stableSet.count < 80 else { break }
                    let key = "\(Int(floor(poke.lon / gridSize)))_\(Int(floor(poke.lat / gridSize)))"
                    if occupiedCells.insert(key).inserted {
                        occupiedIds.insert(poke.id)
                        stableSet.append(poke)
                    }
                }
                displayedHundos = stableSet
            } else {
                let existingIds = Set(stableSet.map { $0.id })
                let additions = visibleHundos.filter { !existingIds.contains($0.id) }
                    .sorted { $0.iv != $1.iv ? $0.iv > $1.iv : $0.id < $1.id }
                displayedHundos = Array((stableSet + additions).prefix(80))
            }
        case .failure(let error):
            print("[HUNDOS] Failed: \(error)")
            if isSessionExpired(error) {
                mapError = "Session PogoMap expirée. Mets à jour le cookie de session pour recharger la carte."
                blockedUntil = Date.now.addingTimeInterval(30)
            }
        }

        // MARK: Process gyms

        switch gymResult {
        case .success(let fetchedGyms):
            for gym in fetchedGyms { allGyms[gym.id] = gym }

            // Clear expired raids
            for (id, gym) in allGyms {
                if let end = gym.raidEndTimestamp {
                    let extendedEnd = Date(timeIntervalSince1970: TimeInterval(end)).addingTimeInterval(5 * 60)
                    if extendedEnd < .now, let level = gym.raidLevel, level > 0 {
                        allGyms[id] = PogoMapGym(
                            id: gym.id, name: gym.name, url: gym.url, lat: gym.lat, lon: gym.lon,
                            teamId: gym.teamId, availableSlots: gym.availableSlots, totalCp: gym.totalCp,
                            guardingPokemonId: gym.guardingPokemonId, defenders: gym.defenders,
                            raidLevel: nil, raidBattleTimestamp: nil, raidEndTimestamp: nil,
                            raidPokemonId: nil, raidPokemonForm: nil, raidPokemonMove1: nil, raidPokemonMove2: nil,
                            raidPokemonCp: nil, raidPokemonGender: nil, raidPokemonEvolution: nil,
                            exRaidEligible: gym.exRaidEligible, inBattle: nil
                        )
                    }
                }
            }

            let center = region.center
            if allGyms.count > 150 {
                let sorted = allGyms.values.sorted {
                    abs($0.lat - center.latitude) + abs($0.lon - center.longitude) <
                    abs($1.lat - center.latitude) + abs($1.lon - center.longitude)
                }
                allGyms = Dictionary(uniqueKeysWithValues: sorted.prefix(100).map { ($0.id, $0) })
            }

            let zoomLevel = region.span.latitudeDelta
            let gymGridSize: Double = {
                if zoomLevel > 0.1 { return 0.008 }
                if zoomLevel > 0.05 { return 0.004 }
                if zoomLevel > 0.025 { return 0.002 }
                if zoomLevel > 0.015 { return 0.001 }
                return 0.0
            }()

            let visibleGyms: [PogoMapGym]
            if gymGridSize > 0 {
                let snapLat = max(gymGridSize, region.span.latitudeDelta)
                let snapLon = max(gymGridSize, region.span.longitudeDelta)
                let gMinLat = floor((center.latitude - snapLat) / gymGridSize) * gymGridSize
                let gMaxLat = ceil((center.latitude + snapLat) / gymGridSize) * gymGridSize
                let gMinLon = floor((center.longitude - snapLon) / gymGridSize) * gymGridSize
                let gMaxLon = ceil((center.longitude + snapLon) / gymGridSize) * gymGridSize
                visibleGyms = allGyms.values.filter {
                    $0.lat >= gMinLat && $0.lat <= gMaxLat && $0.lon >= gMinLon && $0.lon <= gMaxLon
                }
            } else {
                visibleGyms = allGyms.values.filter {
                    abs($0.lat - center.latitude) <= zoomLevel && abs($0.lon - center.longitude) <= region.span.longitudeDelta
                }
            }

            if gymGridSize > 0 {
                var grid: [String: PogoMapGym] = [:]
                var kept: [PogoMapGym] = []
                for gym in visibleGyms.sorted(by: { $0.hasActiveRaid != $1.hasActiveRaid ? $0.hasActiveRaid : $0.id < $1.id }) {
                    let key = "\(Int(floor(gym.lon / gymGridSize)))_\(Int(floor(gym.lat / gymGridSize)))"
                    if let existing = grid[key] {
                        if gym.hasActiveRaid && !existing.hasActiveRaid {
                            grid[key] = gym
                            kept.removeAll { $0.id == existing.id }
                            kept.append(gym)
                        }
                    } else {
                        grid[key] = gym
                        kept.append(gym)
                    }
                }
                displayedGyms = Array(kept.prefix(80))
            } else {
                displayedGyms = Array(visibleGyms.sorted {
                    $0.hasActiveRaid != $1.hasActiveRaid ? $0.hasActiveRaid : $0.id < $1.id
                }.prefix(80))
            }
        case .failure(let error):
            if isSessionExpired(error) {
                mapError = "Session PogoMap expirée. Mets à jour le cookie de session pour recharger la carte."
                blockedUntil = Date.now.addingTimeInterval(30)
            } else {
                mapError = error.localizedDescription
            }
        }

        isLoadingMap = false
    }

    private func isSessionExpired(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == "PogoMap" {
            return nsError.localizedDescription.localizedCaseInsensitiveContains("session_expired")
        }
        return nsError.localizedDescription.localizedCaseInsensitiveContains("session_expired")
    }
}
