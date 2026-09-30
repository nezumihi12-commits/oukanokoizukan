import Foundation

struct GardenZone: Codable, Identifiable {
    var id: String
    var title: String
    var unlocked: Bool
    var habitat: HabitatDefinition?
    static let central = GardenZone(id: "central", title: "中央庭園", unlocked: true, habitat: nil)
}
struct HabitatDefinition: Codable {
    var sunlight: ClosedRange<Double>
    var moisture: ClosedRange<Double>
    var temperatureCelsius: ClosedRange<Double>
    func suitability(sun: Double, water: Double, temperature: Double) -> Double {
        Double([sunlight.contains(sun), moisture.contains(water), temperatureCelsius.contains(temperature)].filter { $0 }.count) / 3
    }
}
struct Observation: Codable, Identifiable {
    var id: UUID
    var plantID: String
    var photoID: UUID?
    var capturedAt: Date?
    var location: GeoPoint?
    var note: String
}
struct CharacterEvent: Codable, Identifiable {
    var id: String
    var conditions: [EventCondition]
    var dialogueResourceID: String? // No dialogue text until the user authors it.
    var once: Bool
}
struct PlantRenderDefinition: Codable {
    var skeleton: String
    var leaf: String
    var flower: String
    var inflorescence: String
    var accent: String
    var hue: Double
}
struct PlantRenderCatalog: Codable {
    var version: Int
    var isPlaceholder: Bool
    var definitions: [String: PlantRenderDefinition]
    static let fallback = PlantRenderDefinition(skeleton: "S01_upright_herb", leaf: "L11_standard_broad", flower: "F14_five_star", inflorescence: "I01_single", accent: "none", hue: 0)
}
