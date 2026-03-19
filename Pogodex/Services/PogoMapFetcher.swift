import Foundation
import MapKit

enum PogoMapFetcher {

    private static let endpoint = "https://www.pogomap.fr/graphql"
    private static let authEndpoint = "https://www.pogomap.fr/auth/local/callback"
    private static let hardcodedAuthUsername = ""
    private static let hardcodedAuthPassword = ""
    private static let sessionCookieDefaultsKey = "pogomap_session_cookie"
    private static let usernameDefaultsKey = "pogomap_auth_username"
    private static let passwordDefaultsKey = "pogomap_auth_password"
    private static let fallbackSessionCookie = "reactmap1=s%3AVAlJGNU46XKITaS7Y_27J4ImvmHJBehK.eeQJ8lrUG1bdZsqoVma9%2Fx18KezHqLTm8%2B1ZD5qaFDs"
    private static var sessionCookie: String = UserDefaults.standard.string(forKey: sessionCookieDefaultsKey) ?? fallbackSessionCookie
    private static let defaultClientVersion = "1.40.0-develop.22"
    private static var cachedAvailableKeys: [String]?
    
    private static let noRedirectSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        return URLSession(configuration: config, delegate: NoRedirectDelegate(), delegateQueue: nil)
    }()

    private class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest) async -> URLRequest? {
            return nil // Cancel redirect
        }
    }

    static func setSessionCookieFromRaw(_ rawCookie: String) -> Bool {
        let extracted = extractSessionCookie(from: rawCookie) ?? {
            if rawCookie.hasPrefix("reactmap1=") {
                return String(rawCookie.split(separator: ";", maxSplits: 1).first ?? Substring(rawCookie))
            }
            return nil
        }()

        guard let extracted, !extracted.isEmpty else { return false }

        sessionCookie = extracted
        UserDefaults.standard.set(extracted, forKey: sessionCookieDefaultsKey)
        print("[AUTH] Session cookie set manually")
        return true
    }

    // MARK: - Shared Request Builder

    private static func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("PogoMap.fr", forHTTPHeaderField: "apollographql-client-name")
        request.setValue(defaultClientVersion, forHTTPHeaderField: "apollographql-client-version")
        request.setValue("https://www.pogomap.fr", forHTTPHeaderField: "Origin")
        request.setValue("https://www.pogomap.fr/", forHTTPHeaderField: "Referer")
        request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        request.timeoutInterval = 10
        return request
    }

    private static func makeSessionBootstrapRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("https://www.pogomap.fr", forHTTPHeaderField: "Origin")
        request.setValue("https://www.pogomap.fr/", forHTTPHeaderField: "Referer")
        request.timeoutInterval = 10
        return request
    }

    private static func makeAuthRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("https://www.pogomap.fr", forHTTPHeaderField: "Origin")
        request.setValue("https://www.pogomap.fr/login", forHTTPHeaderField: "Referer")
        request.timeoutInterval = 10
        return request
    }

    private static func parseServerMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let errors = json["errors"] as? [[String: Any]],
              let message = errors.first?["message"] as? String else {
            return nil
        }
        return message
    }

    private static func isSessionExpiredMessage(_ message: String?) -> Bool {
        guard let message else { return false }
        return message.localizedCaseInsensitiveContains("session_expired")
    }

    private static func extractSessionCookie(from setCookieHeader: String) -> String? {
        let pattern = #"reactmap1=[^;\s,]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(setCookieHeader.startIndex..<setCookieHeader.endIndex, in: setCookieHeader)
        guard let match = regex.firstMatch(in: setCookieHeader, options: [], range: nsRange),
              let range = Range(match.range, in: setCookieHeader) else {
            return nil
        }
        return String(setCookieHeader[range])
    }

    private static func updateSessionCookieIfNeeded(from response: HTTPURLResponse) -> Bool {
        guard let setCookieHeader = response.value(forHTTPHeaderField: "Set-Cookie"),
              let refreshedCookie = extractSessionCookie(from: setCookieHeader),
              refreshedCookie != sessionCookie else {
            return false
        }

        sessionCookie = refreshedCookie
        UserDefaults.standard.set(refreshedCookie, forKey: sessionCookieDefaultsKey)
        print("[AUTH] Session cookie updated")
        return true
    }

    private static func refreshSessionCookieFromWebsite() async -> Bool {
        guard let bootstrapURL = URL(string: "https://www.pogomap.fr/") else { return false }

        do {
            let request = makeSessionBootstrapRequest(url: bootstrapURL)
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResp = response as? HTTPURLResponse else { return false }

            let didUpdate = updateSessionCookieIfNeeded(from: httpResp)
            if !didUpdate {
                print("[AUTH] No fresh session cookie received from bootstrap")
            }
            return didUpdate
        } catch {
            print("[AUTH] Bootstrap request failed: \(error.localizedDescription)")
            return false
        }
    }

    static func refreshSessionCookieWithCredentialsPublic() async -> Bool {
        guard let authURL = URL(string: authEndpoint) else { return false }

        let username = hardcodedAuthUsername.isEmpty
            ? (UserDefaults.standard.string(forKey: usernameDefaultsKey) ?? "")
            : hardcodedAuthUsername
        let password = hardcodedAuthPassword.isEmpty
            ? (UserDefaults.standard.string(forKey: passwordDefaultsKey) ?? "")
            : hardcodedAuthPassword

        guard !username.isEmpty, !password.isEmpty else {
            print("[AUTH] Missing credentials in UserDefaults (keys: \(usernameDefaultsKey), \(passwordDefaultsKey))")
            return false
        }

        let payload: [String: String] = [
            "username": username,
            "password": password
        ]

        do {
            var request = makeAuthRequest(url: authURL)
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (_, response) = try await noRedirectSession.data(for: request)
            guard let httpResp = response as? HTTPURLResponse else { return false }

            let didUpdate = updateSessionCookieIfNeeded(from: httpResp)
            if !didUpdate {
                print("[AUTH] Login did not return a fresh session cookie")
            }
            return didUpdate
        } catch {
            print("[AUTH] Credential login failed: \(error.localizedDescription)")
            return false
        }
    }

    private static func performGraphQLRequest(body: [String: Any], timeout: TimeInterval) async -> Result<Data, Error> {
        guard let url = URL(string: endpoint) else { return .failure(URLError(.badURL)) }

        do {
            let payload = try JSONSerialization.data(withJSONObject: body)

            for attempt in 0...1 {
                var request = makeRequest(url: url)
                request.timeoutInterval = timeout
                request.httpBody = payload
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResp = response as? HTTPURLResponse else {
                    return .failure(URLError(.badServerResponse))
                }

                _ = updateSessionCookieIfNeeded(from: httpResp)

                let serverMessage = parseServerMessage(from: data)
                let isExpired = isSessionExpiredMessage(serverMessage)

                if httpResp.statusCode == 200, !isExpired {
                    return .success(data)
                }

                if attempt == 0, (isExpired || httpResp.statusCode == 511) {
                    var refreshed = await refreshSessionCookieWithCredentialsPublic()
                    if !refreshed {
                        refreshed = await refreshSessionCookieFromWebsite()
                    }
                    if refreshed {
                        print("[AUTH] Retrying GraphQL after cookie refresh")
                        continue
                    }
                }

                if let serverMessage {
                    return .failure(NSError(domain: "PogoMap", code: httpResp.statusCode, userInfo: [NSLocalizedDescriptionKey: serverMessage]))
                }

                return .failure(URLError(.badServerResponse))
            }

            return .failure(URLError(.unknown))
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Hundos

    private static let hundoGraphqlQuery = """
    query Pokemon($minLat: Float!, $minLon: Float!, $maxLat: Float!, $maxLon: Float!, $filters: JSON!) {
      pokemon(minLat: $minLat, minLon: $minLon, maxLat: $maxLat, maxLon: $maxLon, filters: $filters) {
        id pokemon_id iv expire_timestamp lat lon form costume gender atk_iv def_iv sta_iv level cp move_1 move_2 weight size weather first_seen_timestamp expire_timestamp_verified display_pokemon_id
      }
    }
    """

    static func fetchHundos(in region: MKCoordinateRegion, minIV: Double = 100.0) async -> Result<[PogoMapPokemon], Error> {
        let latDelta = min(region.span.latitudeDelta, 0.25)
        let lonDelta = min(region.span.longitudeDelta, 0.25)
        let minLat = region.center.latitude - latDelta / 2.0
        let maxLat = region.center.latitude + latDelta / 2.0
        let minLon = region.center.longitude - lonDelta / 2.0
        let maxLon = region.center.longitude + lonDelta / 2.0

        let ivInt = Int(minIV)
        let isHundoFilter = ivInt == 100

        let onlyIvOr: [String: Any] = [
            "all": false,
            "iv": [ivInt, 100], "atk_iv": [0, 15], "def_iv": [0, 15], "sta_iv": [0, 15],
            "level": [1, 55], "cp": [10, 10000],
            "great": [1, 100], "ultra": [1, 100], "little": [1, 100], "master": [1, 100],
            "gender": 0, "xxs": false, "xxl": false
        ]

        let zeroZero: [String: Any] = [
            "all": false,
            "iv": [0, 100], "atk_iv": [0, 15], "def_iv": [0, 15], "sta_iv": [0, 15],
            "level": [1, 55], "cp": [10, 10000],
            "great": [1, 100], "ultra": [1, 100], "little": [1, 100], "master": [1, 100],
            "gender": 0, "xxs": false, "xxl": false
        ]

        let filters: [String: Any] = [
            "onlyHundoIv": isHundoFilter,
            "onlyIvOr": onlyIvOr,
            "0-0": zeroZero
        ]

        let body: [String: Any] = [
            "operationName": "Pokemon",
            "variables": [
                "minLat": minLat, "minLon": minLon,
                "maxLat": maxLat, "maxLon": maxLon,
                "filters": filters
            ],
            "query": hundoGraphqlQuery
        ]

        do {
            let data: Data
            switch await performGraphQLRequest(body: body, timeout: 10) {
            case .success(let responseData):
                data = responseData
            case .failure(let error):
                return .failure(error)
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .failure(URLError(.cannotParseResponse))
            }

            if let errors = json["errors"] as? [[String: Any]], !errors.isEmpty {
                print("[HUNDOS] GraphQL Errors: \(errors)")
                return .failure(URLError(.cannotParseResponse))
            }

            guard let dataObj = json["data"] as? [String: Any],
                  let pokes = dataObj["pokemon"] as? [[String: Any]] else {
                return .failure(URLError(.cannotParseResponse))
            }

            var results: [PogoMapPokemon] = []
            for poke in pokes {
                if let id = poke["id"] as? String,
                   let pokeId = poke["pokemon_id"] as? Int,
                   let exp = poke["expire_timestamp"] as? Int,
                   let lat = poke["lat"] as? Double,
                   let lon = poke["lon"] as? Double {
                    let iv: Double
                    if let ivDouble = poke["iv"] as? Double {
                        iv = ivDouble
                    } else if let ivInt = poke["iv"] as? Int {
                        iv = Double(ivInt)
                    } else {
                        continue
                    }
                    var p = PogoMapPokemon(id: id, pokemonId: pokeId, iv: iv, expireTimestamp: exp, lat: lat, lon: lon)
                    p.form = poke["form"] as? Int
                    p.gender = poke["gender"] as? Int
                    p.costume = poke["costume"] as? Int
                    p.atkIv = poke["atk_iv"] as? Int
                    p.defIv = poke["def_iv"] as? Int
                    p.staIv = poke["sta_iv"] as? Int
                    p.level = poke["level"] as? Int
                    p.cp = poke["cp"] as? Int
                    p.move1 = poke["move_1"] as? Int
                    p.move2 = poke["move_2"] as? Int
                    p.weight = poke["weight"] as? Double
                    p.size = poke["size"] as? Double
                    p.weather = poke["weather"] as? Int
                    p.firstSeenTimestamp = poke["first_seen_timestamp"] as? Int
                    p.expireTimestampVerified = poke["expire_timestamp_verified"] as? Bool
                    p.displayPokemonId = poke["display_pokemon_id"] as? Int
                    results.append(p)
                }
            }
            return .success(results)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Gyms & Raids

    private static let graphqlQuery = """
    query GymsRaids($minLat:Float!,$minLon:Float!,$maxLat:Float!,$maxLon:Float!,$filters:JSON!){gyms(minLat:$minLat,minLon:$minLon,maxLat:$maxLat,maxLon:$maxLon,filters:$filters){id name url lat lon team_id available_slots total_cp guarding_pokemon_id defenders raid_level raid_battle_timestamp raid_end_timestamp raid_pokemon_id raid_pokemon_form raid_pokemon_move_1 raid_pokemon_move_2 raid_pokemon_cp raid_pokemon_gender raid_pokemon_evolution ex_raid_eligible in_battle}}
    """

    static func fetchAvailableGyms() async -> [String] {
        let query = "query AvailableGyms { availableGyms }"
        let body: [String: Any] = [
            "operationName": "AvailableGyms",
            "variables": [:] as [String: String],
            "query": query
        ]

        do {
            let data: Data
            switch await performGraphQLRequest(body: body, timeout: 10) {
            case .success(let responseData):
                data = responseData
            case .failure(let error):
                print("[AVAILABLE] Error: \(error)")
                return []
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataObj = json["data"] as? [String: Any],
                  let available = dataObj["availableGyms"] as? [String] else { return [] }
            print("[AVAILABLE] Got \(available.count) gym filter keys")
            return available
        } catch {
            print("[AVAILABLE] Error: \(error)")
            return []
        }
    }

    static func fetchGyms(in region: MKCoordinateRegion) async -> Result<[PogoMapGym], Error> {
        let latDelta = min(region.span.latitudeDelta, 0.25)
        let lonDelta = min(region.span.longitudeDelta, 0.25)
        let minLat = region.center.latitude - latDelta / 2
        let maxLat = region.center.latitude + latDelta / 2
        let minLon = region.center.longitude - lonDelta / 2
        let maxLon = region.center.longitude + lonDelta / 2

        let availableKeys: [String]
        if let cached = cachedAvailableKeys {
            availableKeys = cached
        } else {
            let fetched = await fetchAvailableGyms()
            cachedAvailableKeys = fetched
            availableKeys = fetched
        }

        var filters: [String: Any] = [
            "t0-0": ["enabled": true, "size": "md", "all": true, "adv": ""],
            "t1-0": ["enabled": true, "size": "md", "all": true, "adv": ""],
            "t2-0": ["enabled": true, "size": "md", "all": true, "adv": ""],
            "t3-0": ["enabled": true, "size": "md", "all": true, "adv": ""],
            "e1": ["enabled": true, "size": "md", "all": false, "adv": ""],
            "e3": ["enabled": true, "size": "md", "all": false, "adv": ""],
            "e5": ["enabled": true, "size": "md", "all": false, "adv": ""],
            "e6": ["enabled": true, "size": "md", "all": false, "adv": ""],
            "e7": ["enabled": true, "size": "md", "all": false, "adv": ""],
            "e8": ["enabled": true, "size": "md", "all": false, "adv": ""],
            "e9": ["enabled": true, "size": "md", "all": false, "adv": ""],
            "e10": ["enabled": true, "size": "md", "all": false, "adv": ""],
            "onlyAllGyms": true,
            "onlyRaids": true,
            "onlyRaidTier": "all",
            "onlyExEligible": false,
            "onlyInBattle": false,
            "onlyArEligible": false,
            "onlyGymBadges": false,
            "onlyBadge": "",
            "onlyLevels": "all",
            "onlyAreas": [] as [String]
        ]

        for key in availableKeys where filters[key] == nil {
            filters[key] = ["enabled": true, "size": "md", "all": true, "adv": ""]
        }

        let body: [String: Any] = [
            "operationName": "GymsRaids",
            "variables": [
                "minLat": minLat, "maxLat": maxLat,
                "minLon": minLon, "maxLon": maxLon,
                "filters": filters
            ],
            "query": graphqlQuery
        ]

        do {
            let data: Data
            switch await performGraphQLRequest(body: body, timeout: 15) {
            case .success(let responseData):
                data = responseData
            case .failure(let error):
                if let nsError = error as NSError?, nsError.domain == "PogoMap" {
                    print("[MAP] HTTP \(nsError.code): \(nsError.localizedDescription)")
                }
                return .failure(error)
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataObj = json["data"] as? [String: Any],
                  let gymsArray = dataObj["gyms"] as? [[String: Any]] else {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errors = json["errors"] as? [[String: Any]],
                   let msg = errors.first?["message"] as? String {
                    return .failure(NSError(domain: "PogoMap", code: -1, userInfo: [NSLocalizedDescriptionKey: msg]))
                }
                return .failure(URLError(.cannotParseResponse))
            }

            let gyms = gymsArray.compactMap { parseGym($0) }
            return .success(gyms)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Parsing

    private static func asInt(_ value: Any?) -> Int? {
        if let i = value as? Int { return i }
        if let d = value as? Double { return Int(d) }
        if let n = value as? NSNumber { return n.intValue }
        if let s = value as? String { return Int(s) }
        return nil
    }

    private static func parseGym(_ dict: [String: Any]) -> PogoMapGym? {
        guard let id = dict["id"] as? String,
              let lat = dict["lat"] as? Double,
              let lon = dict["lon"] as? Double else { return nil }

        var defenders: [PogoMapDefender]?
        if let defArray = dict["defenders"] as? [[String: Any]] {
            defenders = defArray.compactMap { d in
                guard let pokemonId = asInt(d["pokemon_id"]) else { return nil }
                return PogoMapDefender(
                    pokemonId: pokemonId,
                    cpNow: asInt(d["cp_now"]) ?? 0,
                    cpWhenDeployed: asInt(d["cp_when_deployed"]) ?? 0,
                    motivationNow: d["motivation_now"] as? Double
                )
            }
        } else if let defStr = dict["defenders"] as? String,
                  let defData = defStr.data(using: .utf8),
                  let defArray = try? JSONSerialization.jsonObject(with: defData) as? [[String: Any]] {
            defenders = defArray.compactMap { d in
                guard let pokemonId = asInt(d["pokemon_id"]) else { return nil }
                return PogoMapDefender(
                    pokemonId: pokemonId,
                    cpNow: asInt(d["cp_now"]) ?? 0,
                    cpWhenDeployed: asInt(d["cp_when_deployed"]) ?? 0,
                    motivationNow: d["motivation_now"] as? Double
                )
            }
        }

        return PogoMapGym(
            id: id,
            name: dict["name"] as? String,
            url: dict["url"] as? String,
            lat: lat, lon: lon,
            teamId: asInt(dict["team_id"]),
            availableSlots: asInt(dict["available_slots"]),
            totalCp: asInt(dict["total_cp"]),
            guardingPokemonId: asInt(dict["guarding_pokemon_id"]),
            defenders: defenders,
            raidLevel: asInt(dict["raid_level"]),
            raidBattleTimestamp: asInt(dict["raid_battle_timestamp"]),
            raidEndTimestamp: asInt(dict["raid_end_timestamp"]),
            raidPokemonId: asInt(dict["raid_pokemon_id"]),
            raidPokemonForm: asInt(dict["raid_pokemon_form"]),
            raidPokemonMove1: asInt(dict["raid_pokemon_move_1"]),
            raidPokemonMove2: asInt(dict["raid_pokemon_move_2"]),
            raidPokemonCp: asInt(dict["raid_pokemon_cp"]),
            raidPokemonGender: asInt(dict["raid_pokemon_gender"]),
            raidPokemonEvolution: asInt(dict["raid_pokemon_evolution"]),
            exRaidEligible: dict["ex_raid_eligible"] as? Bool,
            inBattle: dict["in_battle"] as? Bool
        )
    }
}
