import Foundation

struct GardenAttribute: Codable {
    struct Attributes: Codable {
        var growthForm: String
        var sunlight: String
        var moisture: String
        var climate: String
        var seasonAffinity: [String]
        var defaultSizeClass: String
        var placementTypes: [String]
    }
    var latin: String
    var gardenAttributes: Attributes
    var habitatScores: [String: Double]
    var recommendedZones: [String]
}

enum PlacementControl: String, Codable { case delegated, manual, central }
struct PlantPlacement: Codable, Equatable {
    var zoneID: String
    var spotID: String
    var control: PlacementControl
}
struct GardenMembership: Codable, Equatable {
    var assignedGardenID: String
    var placementAuthority: PlacementControl
    var isDisplayPinned = false
}
struct GardenLayout: Codable, Equatable {
    var memberships: [String: GardenMembership]? = nil
    var pendingUnlocks: [String]? = nil
    var eventHistory: [GardenNotice]? = nil
    var visitedGardens: Set<String>? = nil
    var version = 1
    var awaitingDelegation: Set<String> = []
    var placements: [String: PlantPlacement] = [:]
    var unlockedZones: Set<String> = []
    var lastUnlockBloomCount = 0
    var ambiguousUnlocked = false
    var pendingEvents: [GardenNotice] = []
}
struct GardenNotice: Codable, Identifiable, Equatable {
    var id: String
    var priority: Int // 3 important, 2 interaction, 1 garden, 0 idle
    var expression: String = "neutral"
    var pose: String = "stand"
    var createdAt: Date = Date()
    var duration: Double = 8
    var systemText: String // Status text, never authored character dialogue.
}

enum NoticeQueue {
    static func enqueue(_ notice: GardenNotice, into queue: inout [GardenNotice]) {
        if let index = queue.firstIndex(where: { $0.id == notice.id }) {
            if queue[index].priority < 3 { queue[index] = notice }
        } else { queue.append(notice) }
        queue.sort { $0.priority == $1.priority ? $0.createdAt < $1.createdAt : $0.priority > $1.priority }
        // Important one-shot events are never discarded to fit the ambient queue.
        let ambient = queue.filter { $0.priority < 3 }.prefix(8)
        queue = queue.filter { $0.priority == 3 } + Array(ambient)
    }
}

struct PlantingSpot: Codable, Identifiable, Equatable {
    var id: String
    var size: String
    var x: Double
    var y: Double
    var types: Set<String>
}
struct GardenArea: Identifiable, Equatable {
    var id: String
    var title: String
    var central: Bool
    var sizes: [String]
    var threshold: Int = 0
    var spots: [PlantingSpot] { Self.slotDefinitions[id] ?? [] }
    static let slotDefinitions: [String: [PlantingSpot]] = {
        guard let url = Bundle.main.url(forResource: "gardenSlots", withExtension: "json"),
              let data = try? Data(contentsOf: url), let values = try? JSONDecoder().decode([String: [PlantingSpot]].self, from: data) else { return [:] }
        return values
    }()
    static let centralAreas: [GardenArea] = [
        GardenArea(id: "favorite", title: "お気に入り花壇", central: true, sizes: ["L", "M", "M", "S", "S", "S"]),
        GardenArea(id: "seasonal", title: "季節花壇", central: true, sizes: ["L", "M", "M", "S", "S", "S"]),
        GardenArea(id: "central_water", title: "小さな水辺", central: true, sizes: ["L", "M", "S", "S"]),
        GardenArea(id: "display", title: "自由展示", central: true, sizes: ["L", "M", "M", "S", "S"]),
        GardenArea(id: "bench", title: "ベンチ周辺", central: true, sizes: ["M", "S", "S"]),
        GardenArea(id: "trees", title: "樹木スペース", central: true, sizes: ["XL", "XL"]),
        GardenArea(id: "plaza", title: "広場の縁", central: true, sizes: ["M", "S", "S", "S"])
    ]
    static let habitats: [GardenArea] = [
        GardenArea(id: "sunny_border", title: "日向花壇", central: false, sizes: [], threshold: 10),
        GardenArea(id: "meadow", title: "草原", central: false, sizes: [], threshold: 10),
        GardenArea(id: "woodland_edge", title: "林縁", central: false, sizes: [], threshold: 7),
        GardenArea(id: "woodland_shade", title: "木陰", central: false, sizes: [], threshold: 5),
        GardenArea(id: "waterside", title: "水辺", central: false, sizes: [], threshold: 4),
        GardenArea(id: "dry_rock", title: "岩場", central: false, sizes: [], threshold: 4),
        GardenArea(id: "grove", title: "木立", central: false, sizes: [], threshold: 7),
        GardenArea(id: "greenhouse", title: "温室", central: false, sizes: [], threshold: 5)
    ].map { area in
        var copy = area
        copy.threshold = Tuning.threshold(area.id, fallback: area.threshold)
        copy.sizes = area.id == "grove" ? ["XL", "XL", "XL", "L", "L", "M"] : ["L", "L", "L", "M", "M", "M", "S", "S", "S"]
        copy.sizes = Array(repeating: copy.sizes, count: 6).flatMap { $0 }
        return copy
    }
    static var all: [GardenArea] { centralAreas + habitats }
}

enum GardenEngine {
    static func migrateMembership(_ state: inout AppState) {
        guard var layout = state.garden.layout, layout.memberships == nil else { return }
        layout.memberships = [:]
        var count: [String: Int] = [:]
        // User-controlled displays have priority. Original placement file remains in migration backup.
        for id in layout.placements.keys.sorted(by: { a, b in
            let x = layout.placements[a]!.control != .delegated, y = layout.placements[b]!.control != .delegated
            return x == y ? a < b : x
        }) {
            let place = layout.placements[id]!
            let garden = GardenArea.centralAreas.contains { $0.id == place.zoneID } ? "central" : place.zoneID
            layout.memberships?[id] = GardenMembership(assignedGardenID: garden, placementAuthority: place.control, isDisplayPinned: place.control != .delegated)
            if count[garden, default: 0] >= Tuning.visibleLimit { layout.placements.removeValue(forKey: id) }
            else { count[garden, default: 0] += 1 }
        }
        state.garden.layout = layout
    }
    static func validate(_ layout: GardenLayout, records: [String: StudyRecord]) throws {
        guard layout.version == 1, layout.lastUnlockBloomCount >= 0,
              layout.unlockedZones.isSubset(of: Set(GardenArea.habitats.map(\.id))),
              layout.awaitingDelegation.allSatisfy({ records[$0]?.hasBloomed == true }) else { throw BackupError.invalid }
        if let memberships = layout.memberships {
            let allowed = layout.unlockedZones.union(["central"])
            guard memberships.allSatisfy({ records[$0.key]?.hasBloomed == true && allowed.contains($0.value.assignedGardenID) }) else { throw BackupError.invalid }
        }
        var used = Set<String>()
        for (id, placement) in layout.placements {
            guard records[id]?.hasBloomed == true,
                  let area = availableAreas(layout).first(where: { $0.id == placement.zoneID }),
                  area.spots.contains(where: { $0.id == placement.spotID }),
                  used.insert(placement.spotID).inserted else { throw BackupError.invalid }
        }
    }
    static func canPlace(_ attribute: GardenAttribute, in spot: PlantingSpot) -> Bool {
        let ranks = ["S": 0, "M": 1, "L": 2, "XL": 3]
        return (ranks[attribute.gardenAttributes.defaultSizeClass] ?? 1) <= (ranks[spot.size] ?? 1)
            && !spot.types.isDisjoint(with: attribute.gardenAttributes.placementTypes)
    }
    static func availableAreas(_ layout: GardenLayout) -> [GardenArea] {
        GardenArea.all.filter { $0.central || layout.unlockedZones.contains($0.id) }
    }
    static func place(_ id: String, area: GardenArea, spot: PlantingSpot, control: PlacementControl,
                      attributes: [String: GardenAttribute], layout: inout GardenLayout) -> Bool {
        let gardenID = area.central ? "central" : area.id
        let displayed = layout.placements.filter { key, value in key != id && (GardenArea.centralAreas.contains { $0.id == value.zoneID } ? "central" : value.zoneID) == gardenID }.count
        guard displayed < Tuning.visibleLimit else { return false }
        guard availableAreas(layout).contains(where: { $0.id == area.id }), area.spots.contains(spot),
              let attribute = attributes[id], canPlace(attribute, in: spot),
              !layout.placements.contains(where: { $0.key != id && $0.value.spotID == spot.id }) else { return false }
        layout.awaitingDelegation.remove(id)
        if layout.memberships == nil { layout.memberships = [:] }
        layout.memberships?[id] = GardenMembership(assignedGardenID: area.central ? "central" : area.id, placementAuthority: control, isDisplayPinned: control != .delegated)
        layout.placements[id] = PlantPlacement(zoneID: area.id, spotID: spot.id, control: control)
        return true
    }
    static func autoPlace(_ id: String, attributes: [String: GardenAttribute], layout: inout GardenLayout, centralOnly: Bool = false) -> Bool {
        guard let attribute = attributes[id] else { return false }
        let candidates = availableAreas(layout).filter { !centralOnly || $0.central }.sorted { a, b in
            let sa = a.central ? 0.25 : attribute.habitatScores[a.id, default: 0]
            let sb = b.central ? 0.25 : attribute.habitatScores[b.id, default: 0]
            return sa == sb ? a.id < b.id : sa > sb
        }
        if layout.memberships == nil { layout.memberships = [:] }
        guard let best = candidates.first else { return false }
        let gardenID = best.central ? "central" : best.id
        layout.memberships?[id] = GardenMembership(assignedGardenID: gardenID, placementAuthority: centralOnly ? .central : .delegated)
        layout.awaitingDelegation.remove(id)
        for area in candidates where (area.central ? "central" : area.id) == gardenID {
            for spot in area.spots.prefix(Tuning.visibleLimit) {
                if place(id, area: area, spot: spot, control: centralOnly ? .central : .delegated, attributes: attributes, layout: &layout) { return true }
            }
        }
        // Full gardens still accept reserve plants, without evicting manual displays.
        layout.placements.removeValue(forKey: id)
        return true
    }
    static func reconcile(_ state: inout AppState, attributes: [String: GardenAttribute], at date: Date, safeBoundary: Bool = false) {
        let firstMigration = state.garden.layout == nil
        var layout = state.garden.layout ?? GardenLayout()
        let bloomed = state.records.filter { $0.value.hasBloomed }
        let count = bloomed.count
        if count >= Int(Tuning.number("garden_unlock", "minimum_total_blooms_before_first_unlock", fallback: 10)) {
            let ready = GardenArea.habitats.compactMap { area -> (GardenArea, Int)? in
                guard !layout.unlockedZones.contains(area.id) else { return nil }
                let n = bloomed.keys.filter { id in
                    guard let a = attributes[id] else { return false }
                    return a.recommendedZones.contains(area.id) && a.habitatScores[area.id, default: 0] >= 0.5
                }.count
                return n >= area.threshold ? (area, n) : nil
            }.sorted {
                let a = Double($0.1) / Double($0.0.threshold), b = Double($1.1) / Double($1.0.threshold)
                if a != b { return a > b }
                if $0.1 != $1.1 { return $0.1 > $1.1 }
                return $0.0.id < $1.0.id
            }
            if layout.pendingUnlocks == nil { layout.pendingUnlocks = [] }
            for candidate in ready where !(layout.pendingUnlocks ?? []).contains(candidate.0.id) { layout.pendingUnlocks?.append(candidate.0.id) }
            if safeBoundary, count - layout.lastUnlockBloomCount >= Int(Tuning.number("garden_unlock", "minimum_new_blooms_between_unlock_events", fallback: 8)),
               let id = layout.pendingUnlocks?.first, let area = GardenArea.habitats.first(where: { $0.id == id }) {
                let next = (area, 0)
                layout.pendingUnlocks?.removeFirst()
                layout.unlockedZones.insert(next.0.id); layout.lastUnlockBloomCount = count
                NoticeQueue.enqueue(GardenNotice(id: "zone-\(next.0.id)", priority: 3, expression: "surprised", pose: "guide", systemText: "\(next.0.title)が開きました"), into: &layout.pendingEvents)
            }
        }
        let thin = bloomed.values.filter { ReviewEngine.severity($0, at: date) >= Tuning.severity("very_ambiguous_min", fallback: 0.75) }.count
        let forgotten = bloomed.values.filter { ReviewEngine.severity($0, at: date) >= Tuning.severity("internal_forgotten_candidate_min", fallback: 1) }.count
        if safeBoundary && !layout.ambiguousUnlocked && (thin >= Int(Tuning.number("ambiguous_garden_unlock", "near_forgotten_simultaneous", fallback: 5)) || forgotten >= Int(Tuning.number("ambiguous_garden_unlock", "forgotten_simultaneous", fallback: 3))) {
            layout.ambiguousUnlocked = true
            NoticeQueue.enqueue(GardenNotice(id: "ambiguous-first", priority: 3, expression: "concerned", pose: "guide", systemText: "曖昧の庭が現れました"), into: &layout.pendingEvents)
        }
        if firstMigration {
            // v0.2 had no physical spots. Keep favorites in the central garden where possible.
            for id in bloomed.keys.sorted() {
                if !autoPlace(id, attributes: attributes, layout: &layout, centralOnly: bloomed[id]?.favorite == true) { layout.awaitingDelegation.insert(id) }
            }
        } else if safeBoundary {
            // Only explicitly delegated plants may move; favorites and manual placements stay put.
            let delegated = (layout.memberships ?? [:]).filter { $0.value.placementAuthority == .delegated && !$0.value.isDisplayPinned && bloomed[$0.key]?.favorite != true }.keys.sorted()
            var movedDisplays = 0
            for id in delegated {
                guard let current = layout.memberships?[id], let a = attributes[id] else { continue }
                let currentScore = a.habitatScores[current.assignedGardenID] ?? 0.25
                let better = layout.unlockedZones.contains { a.habitatScores[$0, default: 0] > currentScore + 0.1 }
                guard better else { continue }
                let wasDisplayed = layout.placements[id] != nil
                if wasDisplayed && movedDisplays >= 3 { continue }
                _ = autoPlace(id, attributes: attributes, layout: &layout)
                if wasDisplayed { movedDisplays += 1 }
            }
        }
        for id in layout.awaitingDelegation.sorted() where bloomed[id] != nil {
            _ = autoPlace(id, attributes: attributes, layout: &layout, centralOnly: bloomed[id]?.favorite == true)
        }
        if layout.eventHistory == nil { layout.eventHistory = [] }
        for notice in layout.pendingEvents where notice.priority >= 1 && !(layout.eventHistory ?? []).contains(where: { $0.id == notice.id }) { layout.eventHistory?.append(notice) }
        state.garden.layout = layout
    }
}
