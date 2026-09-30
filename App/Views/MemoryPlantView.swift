import SwiftUI

/// Compose normal-state modules; memory affects the whole projection, never the source art.
struct MemoryPlantView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let definition: PlantRenderDefinition
    let freshness: Double
    private var appearance: MemoryAppearance { .of(freshness) }
    private var saturation: Double {
        switch appearance {
        case .vivid: return 1
        case .fading: return 0.55
        case .sepia: return 0.1
        case .monochrome, .translucent: return 0
        }
    }
    private var leaves: [CGPoint] {
        if definition.skeleton.hasPrefix("S07") { return [CGPoint(x: 85, y: 100), CGPoint(x: 172, y: 93)] }
        if definition.skeleton.hasPrefix("S10") { return [] }
        if definition.skeleton.hasPrefix("S12") { return [CGPoint(x: 93, y: 120), CGPoint(x: 166, y: 120), CGPoint(x: 116, y: 153), CGPoint(x: 143, y: 153)] }
        return [CGPoint(x: 100, y: 178), CGPoint(x: 158, y: 150)]
    }
    private var flowerSlots: [CGPoint] {
        switch String(definition.inflorescence.prefix(3)) {
        case "I02", "I06", "I08": return [CGPoint(x: 90, y: 74), CGPoint(x: 128, y: 57), CGPoint(x: 166, y: 74)]
        case "I03", "I04", "I09": return [CGPoint(x: 118, y: 60), CGPoint(x: 147, y: 93), CGPoint(x: 113, y: 119)]
        case "I05": return [CGPoint(x: 128, y: 50), CGPoint(x: 98, y: 85), CGPoint(x: 160, y: 94)]
        case "I10": return [CGPoint(x: 95, y: 100), CGPoint(x: 163, y: 140)]
        default: return [CGPoint(x: 128, y: 74)]
        }
    }
    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width, proxy.size.height) / 256
            ZStack {
                Image(definition.skeleton).resizable().frame(width: 230, height: 230).position(x: 128, y: 140)
                ForEach(Array(leaves.enumerated()), id: \.offset) { index, point in
                    Image(definition.leaf).resizable().frame(width: 90, height: 90)
                        .rotationEffect(.degrees(index == 0 ? -35 : 35)).position(point)
                }
                if definition.inflorescence != "none" {
                    Image(definition.inflorescence).resizable().frame(width: 100, height: 130).position(x: 128, y: 110)
                }
                if definition.flower != "none" {
                    ForEach(Array(flowerSlots.enumerated()), id: \.offset) { _, point in
                        Image(definition.flower).resizable().frame(width: flowerSlots.count == 1 ? 98 : 65, height: flowerSlots.count == 1 ? 98 : 65).position(point)
                    }
                }
                if definition.accent == "fruit" {
                    Circle().fill(.orange).frame(width: 15, height: 15).position(x: 85, y: 155)
                    Circle().fill(.red).frame(width: 12, height: 12).position(x: 170, y: 171)
                } else if definition.accent == "tendril" {
                    Path { p in p.move(to: CGPoint(x: 170, y: 155)); p.addCurve(to: CGPoint(x: 200, y: 137), control1: CGPoint(x: 222, y: 158), control2: CGPoint(x: 210, y: 98)) }.stroke(.green, lineWidth: 3)
                } else if definition.accent == "veins" {
                    Path { p in p.move(to: CGPoint(x: 91, y: 164)); p.addLine(to: CGPoint(x: 106, y: 188)) }.stroke(.yellow.opacity(0.7), lineWidth: 4)
                }
            }
            .frame(width: 256, height: 256)
            .compositingGroup()
            .saturation(saturation)
            .colorMultiply(appearance == .sepia ? Color(red: 1, green: 0.85, blue: 0.63) : .white)
            .opacity(appearance == .translucent ? 0.38 : 1)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: appearance)
            .scaleEffect(scale)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }.accessibilityHidden(true)
    }
}

struct BloomCelebration: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let plant: Plant
    let definition: PlantRenderDefinition
    @State private var appeared = false
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            MemoryPlantView(definition: definition, freshness: 1)
                .frame(width: 230, height: 230)
                .scaleEffect(appeared ? 1 : 0.35).opacity(appeared ? 1 : 0)
            Text("はじめての開花").font(.largeTitle.bold())
            Text(plant.latin).font(.title2)
            Text("3つの形式を正解しました。\n中央庭園に新しい植物像が加わりました。\n明日から、記憶の手入れが始まります。")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Text("開花の実績は、記憶が薄れても残ります。").font(.footnote)
            Button("続ける") { dismiss() }.buttonStyle(.borderedProminent).controlSize(.large)
            Spacer()
        }.padding(24)
        .onAppear { withAnimation(reduceMotion ? nil : .spring(duration: 0.7)) { appeared = true } }
    }
}
