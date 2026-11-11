import Foundation
import RealityKit
import UIKit
import Combine
import simd

/// A decorative, self-contained stage LED. It never advances battle clocks.
/// Only the singleplayer view chooses its presentation cue.
final class StageRibbonManager {
    private weak var ring: Entity?
    private weak var brandLayer: Entity?
    private weak var versusLayer: Entity?
    private var countdownLayers: [Int: Entity] = [:]
    private var fightLayer: Entity?
    private var updateSubscription: (any Cancellable)?

    private var cue: StageRibbonCue = .ambient
    private var hasVersusText = false
    private var rotationElapsed: TimeInterval = 0
    private var ambientElapsed: TimeInterval = 0
    private var combatElapsed: TimeInterval = 0
    private var fightRemaining: TimeInterval = 0

    private let radiansPerSecond: Float = 2 * .pi / 48
    private let alternateMatchEveryCycles = 1

    func makeRing(radius: Float, stageHeight: Float) -> Entity {
        reset()
        let container = Entity()
        container.name = "DeckSpawnLEDStageRibbon"
        let height: Float = min(0.054, stageHeight * 0.70)
        let centerY: Float = stageHeight * 0.48
        let labelRadius = radius + 0.017

        let belt = ModelEntity(
            mesh: .generateCylinder(height: height, radius: radius + 0.005),
            materials: [UnlitMaterial(color: UIColor(red: 0.025, green: 0.045, blue: 0.095, alpha: 1))]
        )
        belt.position.y = centerY
        container.addChild(belt)

        // Edges stay subtly lit even when the moving text is in cooldown.
        for offset in [-height / 2, height / 2] {
            let edge = ModelEntity(
                mesh: .generateCylinder(height: 0.002, radius: radius + 0.009),
                materials: [UnlitMaterial(color: UIColor(red: 0.10, green: 0.70, blue: 0.93, alpha: 1))]
            )
            edge.position.y = centerY + offset
            container.addChild(edge)
        }

        let brand = Entity()
        brand.name = "DeckSpawnBrandRibbon"
        container.addChild(brand)
        addTextPanels("DECKSPAWN", to: brand, radius: labelRadius, y: centerY, height: height)
        brandLayer = brand

        let matchup = Entity()
        matchup.name = "DeckSpawnMatchupRibbon"
        matchup.isEnabled = false
        container.addChild(matchup)
        versusLayer = matchup

        // Pre-generate the four short critical messages, rather than creating
        // geometry on the AR render thread each time the clock ticks.
        for number in (1...3) {
            let layer = Entity()
            layer.name = "DeckSpawnCountdown_\(number)"
            layer.isEnabled = false
            container.addChild(layer)
            addTextPanels("\(number)", to: layer, radius: labelRadius, y: centerY, height: height, emphasis: true)
            countdownLayers[number] = layer
        }
        let fight = Entity()
        fight.name = "DeckSpawnFightRibbon"
        fight.isEnabled = false
        container.addChild(fight)
        addTextPanels("FIGHT!", to: fight, radius: labelRadius, y: centerY, height: height, emphasis: true)
        fightLayer = fight

        ring = container
        return container
    }

    func start(in scene: Scene) {
        updateSubscription?.cancel()
        updateSubscription = scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            self?.update(deltaTime: event.deltaTime)
        }
    }

    /// A cue is forwarded directly from the existing battle model.
    func setCue(_ next: StageRibbonCue) {
        guard cue != next else { return }
        let previous = cue
        cue = next
        if next == .versus {
            combatElapsed = 0
            fightRemaining = 0
        } else if StageRibbonTiming.isFightTransition(from: previous, to: next) {
            fightRemaining = StageRibbonTiming.fightSeconds
            combatElapsed = 0
        } else if next == .ambient || next == .result {
            fightRemaining = 0
        }
        renderCurrentCue()
    }

    /// Rebuilt when the opponent is summoned, not on each frame.
    func setMatchup(player: String, opponent: String, radius: Float, stageHeight: Float) {
        guard let versusLayer else { return }
        versusLayer.children.forEach { $0.removeFromParent() }
        let label = "\(player.uppercased()) VS \(opponent.uppercased())"
        addTextPanels(
            label,
            to: versusLayer,
            radius: radius + 0.017,
            y: stageHeight * 0.48,
            height: min(0.054, stageHeight * 0.70)
        )
        hasVersusText = true
        ambientElapsed = 0
    }

    func reset() {
        updateSubscription?.cancel()
        updateSubscription = nil
        ring?.removeFromParent()
        ring = nil
        brandLayer = nil
        versusLayer = nil
        countdownLayers.removeAll()
        fightLayer = nil
        cue = .ambient
        hasVersusText = false
        rotationElapsed = 0
        ambientElapsed = 0
        combatElapsed = 0
        fightRemaining = 0
    }

    private func update(deltaTime: TimeInterval) {
        guard let ring, ring.isAnchored else { return }
        // Cap large per-frame deltas to avoid huge visual jumps after interruptions.
        let dt = max(0, min(deltaTime, 0.10))
        let isCritical: Bool
        switch cue {
        case .countdown: isCritical = true
        case .battle, .action: isCritical = fightRemaining > 0
        default: isCritical = false
        }
        if !isCritical {
            rotationElapsed += dt
            ring.orientation = simd_quatf(
                angle: Float(rotationElapsed) * radiansPerSecond,
                axis: SIMD3<Float>(0, 1, 0)
            )
        }
        if cue == .ambient {
            ambientElapsed += dt
        }
        if cue == .battle || cue == .action {
            if fightRemaining > 0 {
                fightRemaining = max(0, fightRemaining - dt)
            } else {
                combatElapsed += dt
            }
        }
        renderCurrentCue()
    }

    private func renderCurrentCue() {
        guard let brandLayer, let versusLayer else { return }
        brandLayer.isEnabled = false
        versusLayer.isEnabled = false
        for layer in countdownLayers.values { layer.isEnabled = false }
        fightLayer?.isEnabled = false

        switch cue {
        case .ambient:
            // Keep the pre-existing name alternation for contexts such as
            // multiplayer, which is not being changed in this stage.
            let segment: TimeInterval = 6
            let portion = ambientElapsed.truncatingRemainder(dividingBy: segment)
            let showVersus = hasVersusText && !Int(ambientElapsed / segment).isMultiple(of: 2)
            let opacity = Float(max(0, min(1, portion / 0.55, (segment - portion) / 0.55)))
            show(showVersus ? versusLayer : brandLayer, opacity: opacity)
        case .versus:
            show(hasVersusText ? versusLayer : brandLayer, opacity: 1)
        case .countdown(let number):
            // A single large number repeated around the perimeter; rotation paused.
            if let layer = countdownLayers[number] {
                show(layer, opacity: 1)
            }
        case .action:
            // No text obscuring attack, shield or damage animations.
            break
        case .battle:
            if fightRemaining > 0 {
                show(fightLayer, opacity: 1)
            } else {
                let opacity = StageRibbonTiming.combatOpacity(at: combatElapsed)
                let cycle = Int(combatElapsed / StageRibbonTiming.fullCycleSeconds)
                let showMatchup = hasVersusText && (cycle / alternateMatchEveryCycles).isMultiple(of: 2) == false
                show(showMatchup ? versusLayer : brandLayer, opacity: opacity)
            }
        case .result:
            show(brandLayer, opacity: 1)
        }
    }

    private func show(_ entity: Entity?, opacity: Float) {
        guard let entity, opacity > 0.001 else { return }
        entity.isEnabled = true
        entity.components.set(OpacityComponent(opacity: opacity))
    }

    private func addTextPanels(
        _ label: String,
        to layer: Entity,
        radius: Float,
        y: Float,
        height: Float,
        emphasis: Bool = false
    ) {
        let count = 12
        let availableWidth = (2 * .pi * radius / Float(count)) * 0.88
        let availableHeight = height * (emphasis ? 0.85 : 0.64)
        let mesh = MeshResource.generateText(
            label,
            extrusionDepth: 0.0005,
            font: .systemFont(ofSize: 0.045, weight: .heavy),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byClipping
        )
        let prototype = ModelEntity(
            mesh: mesh,
            materials: [UnlitMaterial(color: emphasis
                ? UIColor(red: 0.94, green: 0.98, blue: 1, alpha: 1)
                : UIColor(red: 0.62, green: 0.95, blue: 1, alpha: 1))]
        )
        let bounds = prototype.visualBounds(relativeTo: prototype)
        let width = max(bounds.extents.x, 0.0001)
        let textHeight = max(bounds.extents.y, 0.0001)
        let factor = min(1.0, availableWidth / width, availableHeight / textHeight)

        for index in 0..<count {
            let angle = Float(index) * 2 * .pi / Float(count)
            let panel = Entity()
            panel.position = SIMD3<Float>(sin(angle) * radius, y, cos(angle) * radius)
            panel.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
            let letters = prototype.clone(recursive: true)
            letters.scale = SIMD3<Float>(repeating: factor)
            letters.position = SIMD3<Float>(-bounds.center.x * factor, -bounds.center.y * factor, 0)
            panel.addChild(letters)
            layer.addChild(panel)
        }
    }
}
