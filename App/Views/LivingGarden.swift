import SwiftUI
import SpriteKit
import CoreImage

/// Scene input is explicit: appreciation never shares navigation/edit hit targets.
enum GardenInputMode { case home, appreciation, observation, editing }
struct CharacterAnchor: Codable {
    var anchorID: String
    var zoneID: String
    var x: Double
    var y: Double
    var actionID: String
    var minDwellTime: Double
    var depth: Double?
    var facingDirection: String?
    var allowedActions: [String]?
    var minimumClearance: Double?
    var uiAvoidanceArea: [Double]?
    var maxDwellTime: Double?
    var expressionID: String?
}
struct SceneZone: Codable {
    var id: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}
struct SceneLayoutDefinition: Codable {
    var zones: [SceneZone]
    var anchors: [CharacterAnchor]
    static let standard: Self = {
        guard let u = Bundle.main.url(forResource: "gardenScene", withExtension: "json"),
              let d = try? Data(contentsOf: u), let value = try? JSONDecoder().decode(Self.self, from: d) else { return Self(zones: [], anchors: []) }
        return value
    }()
}
final class LivingGardenScene: SKScene {
    var mode: GardenInputMode = .home
    var onZone: (String) -> Void = { _ in }
    var onPlant: (String?) -> Void = { _ in }
    var onDrop: (String, PlantingSpot) -> Bool = { _, _ in false }
    var onAppreciationTap: () -> Void = {}
    var area: GardenArea?
    var selectedID: String?
    var reduceMotion = false
    private let world = SKNode()
    private let eye = SKCameraNode()
    private var character = SKNode()
    private var signature = ""
    private var lastTime: TimeInterval = 0
    private var nextAnchorTime: TimeInterval = 0
    private var anchorIndex = 0
    private var plantNodes: [SKNode] = []
    private var dragged: SKNode?
    private var dragOrigin = CGPoint.zero
    var diagnosticFPS: Double = 0
    var redraw: (@MainActor () -> Void)?
    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = UIColor(red: 0.88, green: 0.90, blue: 0.80, alpha: 1)
        addChild(world); addChild(eye); camera = eye
    }
    required init?(coder: NSCoder) { fatalError("Use init(size:)") }
    override func didChangeSize(_ oldSize: CGSize) {
        eye.position = CGPoint(x: size.width / 2, y: size.height / 2)
        signature = ""
        DispatchQueue.main.async { [weak self] in self?.redraw?() }
    }
    @MainActor
    func refresh(store: AppStore, layout: GardenLayout, area: GardenArea?, selected: String?, mode: GardenInputMode, reduced: Bool, spike: Bool) {
        self.mode = mode; self.area = area; self.selectedID = selected; self.reduceMotion = reduced
        let visible = layout.placements.filter { entry in area.map { entry.value.zoneID == $0.id } ?? GardenArea.centralAreas.contains { $0.id == entry.value.zoneID } }
        let ids = spike ? Array(store.plants.prefix(15).map(\.id)) : Array(visible.keys.sorted().prefix(Tuning.visibleLimit))
        let stamp = "\(size)-\(area?.id ?? "home")-\(mode)-\(selected ?? "")-\(reduced)-" + ids.map { "\($0):\(visible[$0]?.spotID ?? ""):\(Int(ReviewEngine.freshness(store.state.records[$0] ?? StudyRecord(), at: Date()) * 100))" }.joined(separator: ";")
        guard signature != stamp else { return }; signature = stamp
        let previousCharacterPosition = character.parent == nil ? nil : character.position
        world.removeAllChildren(); plantNodes.removeAll()
        drawLandscape()
        for (index, id) in ids.enumerated() {
            let node = plant(store.renderDefinition(for: id))
            node.name = "plant:\(id)"
            let placement = visible[id]
            if let area, let spot = area.spots.first(where: { $0.id == placement?.spotID }) {
                node.position = point(spot.x, 1 - spot.y)
            } else if let placement, let zone = SceneLayoutDefinition.standard.zones.first(where: { $0.id == placement.zoneID }),
                      let localArea = GardenArea.all.first(where: { $0.id == placement.zoneID }), let spot = localArea.spots.first(where: { $0.id == placement.spotID }) {
                node.position = point(zone.x + (spot.x - 0.5) * zone.width, zone.y + (0.5 - spot.y) * zone.height)
            } else { node.position = point(0.15 + Double(index % 5) * 0.17, 0.25 + Double(index / 5) * 0.2) }
            node.setScale(area == nil ? 0.55 : 0.85)
            node.zPosition = 1000 - node.position.y
            let freshness = spike ? 1 : ReviewEngine.freshness(store.state.records[id] ?? StudyRecord(), at: Date())
            let state = MemoryAppearance.of(freshness)
            if state == .translucent { node.alpha = 0.38 }
            if selected != nil && selected != id { node.alpha *= Tuning.rangeMidpoint("garden", "plant_selection_nonselected_presence_range", fallback: 0.2) }
            if freshness < 0.8 {
                let effect = SKEffectNode(); effect.shouldRasterize = true
                if state == .monochrome { effect.filter = CIFilter(name: "CISepiaTone", parameters: [kCIInputIntensityKey: 0.65]) }
                else { effect.filter = CIFilter(name: "CIColorControls", parameters: [kCIInputSaturationKey: state == .translucent ? 0.0 : 0.7]) }
                for child in node.children { child.removeFromParent(); effect.addChild(child) }
                node.addChild(effect)
            }
            world.addChild(node); plantNodes.append(node)
        }
        if mode == .editing, let area {
            for spot in area.spots.filter({ spot in Array(area.spots.prefix(Tuning.visibleLimit)).contains(spot) || visible.values.contains(where: { $0.spotID == spot.id }) }) {
                let ring = SKShapeNode(ellipseOf: CGSize(width: 52, height: 24))
                ring.strokeColor = .brown; ring.lineWidth = 1; ring.name = "slot:\(spot.id)"
                ring.position = point(spot.x, 1 - spot.y); ring.zPosition = 1100
                let text = SKLabelNode(text: spot.size); text.fontSize = 12; text.fontColor = .darkGray; ring.addChild(text)
                world.addChild(ring)
            }
        }
        character = placeholderPerson()
        let anchors = SceneLayoutDefinition.standard.anchors
        let anchor = anchors.first { $0.actionID == (mode == .editing ? "guide" : "idleStand") }
        character.position = previousCharacterPosition ?? point(anchor?.x ?? 0.5, anchor?.y ?? 0.32)
        character.zPosition = 1000 - character.position.y
        world.addChild(character)
        if previousCharacterPosition == nil && area != nil && !reduced {
            let destination = character.position; character.position.x = -30
            character.run(.sequence([.wait(forDuration: 0.3), .move(to: destination, duration: 1)]))
        }
        if mode == .editing { character.run(.move(to: point(0.88, 0.13), duration: reduced ? 0 : 0.3)); pose("guide") }
        if mode == .home { eye.setScale(1); eye.position = point(0.5, 0.5) }
    }
    private func point(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: size.width * x, y: size.height * y) }
    private func oval(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: UIColor, name: String? = nil) {
        let n = SKShapeNode(ellipseOf: CGSize(width: size.width * w, height: size.height * h))
        n.fillColor = color; n.strokeColor = color; n.position = point(x, y); n.name = name; world.addChild(n)
    }
    private func drawLandscape() {
        let green = UIColor(red: 0.38, green: 0.48, blue: 0.32, alpha: 1)
        // Background clusters are non-interactive aggregate vegetation, never 307 live nodes.
        for i in 0..<12 { oval(Double(i) / 11, 0.9 + Double(i % 2) * 0.025, 0.23, 0.14, green.withAlphaComponent(0.35)) }
        let path = CGMutablePath(); path.move(to: point(0.48, 0)); path.addCurve(to: point(0.53, 0.96), control1: point(0.74, 0.36), control2: point(0.32, 0.68))
        let trail = SKShapeNode(path: path); trail.strokeColor = UIColor(red: 0.81, green: 0.77, blue: 0.64, alpha: 1); trail.lineWidth = size.width * 0.12; world.addChild(trail)
        if area == nil {
            for zone in SceneLayoutDefinition.standard.zones {
                let water = zone.id == "central_water"
                oval(zone.x, zone.y, zone.width, zone.height, water ? UIColor(red: 0.48, green: 0.65, blue: 0.66, alpha: 1) : UIColor(red: 0.64, green: 0.64, blue: 0.45, alpha: 0.6), name: "zone:\(zone.id)")
            }
        } else { oval(0.5, 0.48, 0.93, 0.78, area?.id.contains("water") == true ? .systemTeal.withAlphaComponent(0.25) : green.withAlphaComponent(0.16)) }
        let bench = SKShapeNode(rectOf: CGSize(width: 46, height: 12), cornerRadius: 3)
        bench.fillColor = .brown; bench.strokeColor = .brown; bench.position = point(0.25, 0.77); bench.name = "zone:bench"; world.addChild(bench)
        for i in 0..<6 { oval(0.10 + Double(i % 3) * 0.06, 0.12 + Double(i / 3) * 0.045, 0.035, 0.03, .brown, name: "zone:nursery") }
    }
    private func plant(_ d: PlantRenderDefinition) -> SKNode {
        let node = SKNode()
        func layer(_ name: String, size: CGSize, at: CGPoint) {
            guard name != "none" else { return }
            let sprite = SKSpriteNode(imageNamed: name); sprite.size = size; sprite.position = at; node.addChild(sprite)
        }
        layer(d.skeleton, size: CGSize(width: 90, height: 110), at: CGPoint(x: 0, y: 35))
        layer(d.leaf, size: CGSize(width: 42, height: 42), at: CGPoint(x: -12, y: 35))
        layer(d.flower, size: CGSize(width: 40, height: 40), at: CGPoint(x: 0, y: 70))
        return node
    }
    private func placeholderPerson() -> SKNode {
        let node = SKNode()
        let head = SKShapeNode(circleOfRadius: 7); head.position.y = 65; head.fillColor = .init(red: 0.79, green: 0.73, blue: 0.60, alpha: 1); head.strokeColor = .clear; node.addChild(head)
        let body = SKShapeNode(rectOf: CGSize(width: 19, height: 30), cornerRadius: 4); body.position.y = 41; body.fillColor = .darkGray; body.strokeColor = .clear; body.name = "body"; node.addChild(body)
        for side in [-1.0, 1.0] {
            let leg = SKShapeNode(rectOf: CGSize(width: 6, height: 24), cornerRadius: 2); leg.position = CGPoint(x: side * 5, y: 14); leg.fillColor = .brown; leg.strokeColor = .clear; leg.name = "leg-\(side)"; node.addChild(leg)
            let arm = SKShapeNode(rectOf: CGSize(width: 5, height: 26), cornerRadius: 2); arm.position = CGPoint(x: side * 13, y: 39); arm.fillColor = .gray; arm.strokeColor = .clear; arm.name = "arm-\(side)"; node.addChild(arm)
        }
        return node
    }
    private func pose(_ action: String) {
        character.childNode(withName: "body")?.zRotation = action == "gardening" ? -0.25 : 0
        for child in character.children {
            if child.name?.hasPrefix("leg-") == true {
                child.removeAllActions()
                child.zRotation = action == "sitting" ? .pi / 2 : 0
                if action == "walking" && !reduceMotion {
                    child.run(.repeatForever(.sequence([.rotate(toAngle: 0.24, duration: 0.25), .rotate(toAngle: -0.24, duration: 0.25)])))
                }
            }
            if child.name?.hasPrefix("arm-") == true { child.zRotation = action == "guide" || action == "gardening" ? 0.65 : 0 }
        }
    }
    func tap(_ point: CGPoint) {
        if mode == .appreciation { onAppreciationTap(); return }
        let hit = nodes(at: point).sorted { $0.zPosition > $1.zPosition }
        if mode == .home {
            // Plant taps navigate to the containing zone, never select an individual on home.
            if let zone = SceneLayoutDefinition.standard.zones.first(where: { abs(point.x / size.width - $0.x) <= $0.width / 2 && abs(point.y / size.height - $0.y) <= $0.height / 2 }) { onZone(zone.id) }
            else if point.y < size.height * 0.22 && point.x < size.width * 0.35 { onZone("nursery") }
            return
        }
        for node in hit {
            var current: SKNode? = node
            while let n = current {
                if let name = n.name, name.hasPrefix("plant:") { onPlant(String(name.dropFirst(6))); return }
                if mode == .editing, let name = n.name, name.hasPrefix("slot:"), let id = selectedID,
                   let spot = area?.spots.first(where: { $0.id == String(name.dropFirst(5)) }) { _ = onDrop(id, spot); return }
                current = n.parent
            }
        }
        onPlant(nil)
    }
    func zoom(_ scale: CGFloat) {
        guard mode != .home else { return }
        eye.setScale(max(1 / 2.5, min(1, eye.xScale / scale))); clampCamera()
    }
    func pan(_ delta: CGPoint) {
        guard mode != .home, dragged == nil else { return }
        eye.position.x -= delta.x * eye.xScale; eye.position.y += delta.y * eye.yScale; clampCamera()
    }
    private func clampCamera() {
        let hw = size.width * eye.xScale / 2, hh = size.height * eye.yScale / 2
        eye.position.x = min(size.width - hw, max(hw, eye.position.x)); eye.position.y = min(size.height - hh, max(hh, eye.position.y))
    }
    func beginDrag(_ point: CGPoint) -> Bool {
        guard mode == .editing else { return false }
        dragged = plantNodes.min(by: { hypot($0.position.x-point.x,$0.position.y-point.y) < hypot($1.position.x-point.x,$1.position.y-point.y) })
        guard let n = dragged, hypot(n.position.x-point.x,n.position.y-point.y) < 70 else { dragged = nil; return false }
        dragOrigin = n.position; return true
    }
    func drag(_ point: CGPoint, ended: Bool, cancelled: Bool = false) {
        guard let n = dragged else { return }; n.position = point
        if ended {
            if !cancelled, let name = n.name { _ = drop(String(name.dropFirst(6)), at: point) }
            n.position = dragOrigin; dragged = nil
        }
    }
    func drop(_ id: String, at p: CGPoint) -> Bool {
        guard mode == .editing, let spot = area?.spots.prefix(Tuning.visibleLimit).min(by: {
            let a = point($0.x, 1-$0.y), b = point($1.x, 1-$1.y)
            return hypot(a.x-p.x,a.y-p.y) < hypot(b.x-p.x,b.y-p.y)
        }), hypot(point(spot.x,1-spot.y).x-p.x,point(spot.x,1-spot.y).y-p.y) < 80 else { return false }
        return onDrop(id, spot)
    }
    override func update(_ currentTime: TimeInterval) {
        if lastTime > 0 && currentTime > lastTime { diagnosticFPS = 1 / (currentTime - lastTime) }; lastTime = currentTime
        guard !reduceMotion else { return }
        for (i, node) in plantNodes.enumerated() where node !== dragged { node.zRotation = sin(currentTime * 0.8 + Double(i)) * 0.012 }
        if mode == .home || mode == .appreciation, currentTime > nextAnchorTime {
            let anchors = SceneLayoutDefinition.standard.anchors.filter { $0.actionID != "guide" }
            if !anchors.isEmpty {
                anchorIndex = (anchorIndex + 1) % anchors.count
                let a = anchors[anchorIndex]
                let destination = point(a.x, a.y)
                character.xScale = destination.x < character.position.x ? -1 : 1
                pose("walking")
                character.run(.sequence([.move(to: destination, duration: 3), .run { [weak self] in self?.pose(a.actionID) }]))
                nextAnchorTime = currentTime + a.minDwellTime
            }
        }
        character.zPosition = 1000 - character.position.y
    }
}
struct LivingGarden: UIViewRepresentable {
    @EnvironmentObject var store: AppStore
    var layout: GardenLayout
    var area: GardenArea? = nil
    var selected: String? = nil
    var mode: GardenInputMode = .home
    var spike = false
    var onZone: (String) -> Void = { _ in }
    var onPlant: (String?) -> Void = { _ in }
    var onDrop: (String, PlantingSpot) -> Bool = { _,_ in false }
    var appreciationTap: () -> Void = {}
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> SKView {
        let view = SKView(); view.preferredFramesPerSecond = 60; view.ignoresSiblingOrder = true
        let scene = LivingGardenScene(size: CGSize(width: 390, height: 650)); view.presentScene(scene); context.coordinator.scene = scene
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:))))
        view.addGestureRecognizer(UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pinch(_:))))
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pan(_:))); pan.minimumNumberOfTouches = 2; view.addGestureRecognizer(pan)
        let hold = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.hold(_:))); hold.minimumPressDuration = Tuning.rangeMidpoint("animation", "edit_long_press_seconds_range", fallback: 0.5); view.addGestureRecognizer(hold)
        view.addInteraction(UIDropInteraction(delegate: context.coordinator))
        return view
    }
    func updateUIView(_ view: SKView, context: Context) {
        guard let scene = context.coordinator.scene else { return }
        scene.onZone = onZone; scene.onPlant = onPlant; scene.onDrop = onDrop; scene.onAppreciationTap = appreciationTap
        context.coordinator.haptics = store.preferences.haptics
        scene.redraw = { [weak scene, weak store] in
            guard let scene, let store else { return }
            scene.refresh(store: store, layout: layout, area: area, selected: selected, mode: mode, reduced: store.preferences.reduceMotion || UIAccessibility.isReduceMotionEnabled, spike: spike)
        }
        scene.redraw?()
        view.showsFPS = spike; view.showsNodeCount = spike
    }
    @MainActor
    final class Coordinator: NSObject, UIDropInteractionDelegate {
        var scene: LivingGardenScene?
        var haptics = true
        func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
            scene?.mode == .editing && session.canLoadObjects(ofClass: NSString.self)
        }
        func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
            UIDropProposal(operation: scene?.mode == .editing ? .copy : .forbidden)
        }
        func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
            guard let scene, let view = interaction.view, scene.mode == .editing else { return }
            let position = scene.convertPoint(fromView: session.location(in: view))
            session.loadObjects(ofClass: NSString.self) { objects in
                guard let id = objects.first as? String else { return }
                Task { @MainActor [weak scene] in _ = scene?.drop(id, at: position) }
            }
        }
        @objc func tap(_ g: UITapGestureRecognizer) { guard let s = scene, let v = g.view else { return }; s.tap(s.convertPoint(fromView: g.location(in: v))) }
        @objc func pinch(_ g: UIPinchGestureRecognizer) { scene?.zoom(g.scale); g.scale = 1 }
        @objc func pan(_ g: UIPanGestureRecognizer) { scene?.pan(g.translation(in: g.view)); g.setTranslation(.zero, in: g.view) }
        @objc func hold(_ g: UILongPressGestureRecognizer) {
            guard let s = scene, let v = g.view else { return }; let p = s.convertPoint(fromView: g.location(in: v))
            if g.state == .began { if s.beginDrag(p), haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() } }
            else { s.drag(p, ended: g.state == .ended || g.state == .cancelled, cancelled: g.state == .cancelled) }
        }
    }
}
struct GardenSpikeView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        LivingGarden(layout: store.state.garden.layout ?? GardenLayout(), mode: .appreciation, spike: true)
            .overlay(alignment: .top) { Text("仮人型・15植物・背景クラスター\nピンチ / 2本指パン · 左下に実測FPS").font(.caption).padding().background(.regularMaterial) }
            .navigationTitle("描画検証")
    }
}
