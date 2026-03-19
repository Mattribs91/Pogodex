import Foundation
import CoreLocation

struct PogoMapPokemon: Identifiable, Hashable {
    let id: String
    let pokemonId: Int
    let iv: Double
    let expireTimestamp: Int
    let lat: Double
    let lon: Double
    var form: Int?
    var gender: Int?
    var costume: Int?
    var atkIv: Int?
    var defIv: Int?
    var staIv: Int?
    var level: Int?
    var cp: Int?
    var move1: Int?
    var move2: Int?
    var weight: Double?
    var size: Double?
    var weather: Int?
    var firstSeenTimestamp: Int?
    var expireTimestampVerified: Bool?
    var displayPokemonId: Int?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var ivInt: Int { Int(iv.rounded()) }
}
