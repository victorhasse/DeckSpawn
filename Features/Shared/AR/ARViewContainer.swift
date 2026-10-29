import SwiftUI

import RealityKit

import ARKit

import UIKit

import simd

import QuartzCore



struct ARViewContainer: UIViewRepresentable {



    @ObservedObject var state: GameARState



    func makeCoordinator() -> Coordinator {

        Coordinator(

            state: state

        )

    }



    func makeUIView(context: Context) -> ARView {



        let arView = ARView(

            frame: .zero,

            cameraMode: .ar,

            automaticallyConfigureSession: false

        )



        context.coordinator.arView = arView
        arView.session.delegate = context.coordinator
        state.attachARCoordinator(context.coordinator.identifier)



        state.onRemoveCharacter = { [weak coordinator = context.coordinator] in

            coordinator?.removeCurrentCharacter()

        }



        state.onPrepareBattle = { [weak coordinator = context.coordinator] enemy in

            coordinator?.prepareBattle(

                with: enemy

            )

        }

        state.onPrepareRematch = { [weak coordinator = context.coordinator] in
            coordinator?.prepareSameCharacterRematch() ?? false
        }



        state.onBattleTurnAnimation = {
            [weak coordinator = context.coordinator]
            playerMove,
            enemyMove,
            result,
            winner,
            damage in

            coordinator?.playBattleTurnAnimations(
                playerMove: playerMove,
                enemyMove: enemyMove,
                result: result,
                winner: winner,
                damage: damage
            )
        }



        guard let referenceImages = ARReferenceImage.referenceImages(

            inGroupNamed: "AR Resources",

            bundle: nil

        ) else {

            print("❌ AR Resources não encontrado")

            return arView

        }



        print(

            "🃏 Cartas cadastradas:",

            referenceImages.compactMap { $0.name }

        )



        let configuration = ARWorldTrackingConfiguration()

        configuration.worldAlignment = .gravity

        configuration.detectionImages = referenceImages

        configuration.maximumNumberOfTrackedImages = 1

        configuration.planeDetection = [.horizontal]



        arView.session.run(

            configuration,

            options: [

                .resetTracking,

                .removeExistingAnchors

            ]

        )



        DispatchQueue.main.async {

            context.coordinator.startSearching()

        }



        return arView

    }



    func updateUIView(

        _ uiView: ARView,

        context: Context

    ) {}



    static func dismantleUIView(

        _ uiView: ARView,

        coordinator: Coordinator

    ) {

        uiView.session.pause()

        coordinator.detach()

    }

}



extension ARViewContainer {



    final class Coordinator: NSObject, ARSessionDelegate {



        weak var arView: ARView?



        private let state: GameARState



        private let holdDuration: TimeInterval = 1.0

        private let scanDuration: TimeInterval = 1.8



        private let stageDistance: Float = 1.20

        private let stageRadius: Float = 0.42

        private let stageHeight: Float = 0.025

        private let summonPreDelay: TimeInterval = 0.80



        private let battleCharacterOffset: Float = 0.28

        private let battleFacingDelay: TimeInterval = 0.30

        private let battleTurnDuration: TimeInterval = 0.75



        private var stableSince: TimeInterval?

        private var lastCardPoint: CGPoint?



        private var currentImageAnchorID: UUID?

        private var latestCardTransform: simd_float4x4?

        private var selectedCard: CardDefinition?



        private var isScanning = false

        private var interactionLocked = false

        private var waitingForCardClear = false

        private var removalInProgress = false



        private var scanGeneration = 0

        private var searchGeneration = 0

        // ARKit can briefly lose an image even when the card has not moved.
        // Ignore short tracking/centering glitches instead of restarting a scan.
        private let scanTrackingGrace: TimeInterval = 0.80
        private var lastValidScanSample: TimeInterval?
        private var scanCardName: String?

        // Somente a tela AR atualmente montada pode modificar GameARState.
        let identifier = UUID()
        private var isDetached = false
        private var isCurrentSession: Bool {
            !isDetached && state.isCurrentARCoordinator(identifier)
        }



        private var arenaAnchorID: UUID?

        private var arenaRendered = false

        // Descarta resultados de carregamentos que terminaram apos o reset.
        private var assetLoadGeneration = 0



        private var currentArenaAnchor: ARAnchor?

        private var currentArenaEntity: AnchorEntity?

        private var currentCharacterEntity: Entity?

        private var currentEnemyEntity: Entity?

        private var characterAnimatedModels:

            [ObjectIdentifier: Entity] = [:]



        private var characterAnimations:

            [ObjectIdentifier: [CharacterAnimationKind: AnimationResource]] = [:]



        private var animationResourceCache:

            [String: AnimationResource] = [:]



        private var missingAnimationResourceFiles:

            Set<String> = []



        private var animationGeneration:

            [ObjectIdentifier: Int] = [:]

        // Invalida callbacks de rodadas anteriores ao iniciar ou limpar uma batalha.
        private var battleAudioGeneration = 0
        // Invalidates projection ticks when a hit ends or the player leaves.
        private var floatingDamageGeneration = 0

        #if DEBUG
        // Diagnostico leve: registre tempos de carga no console do Xcode.
        // O codigo e removido em builds Release.
        private func logLoadingDuration(
            _ operation: String,
            startedAt: TimeInterval
        ) {
            let durationMilliseconds =
                (CACurrentMediaTime() - startedAt) * 1_000
            let thread = Thread.isMainThread ? "main" : "background"
            print(
                String(
                    format: "[DeckSpawn][Perf] %@ | %.1f ms WALL | callback=%@",
                    operation,
                    durationMilliseconds,
                    thread
                )
            )
        }
        #endif



        init(

            state: GameARState

        ) {

            self.state = state

        }



        func detach() {
            isDetached = true
            scanGeneration += 1
            searchGeneration += 1
            battleAudioGeneration += 1
            floatingDamageGeneration += 1
            assetLoadGeneration += 1
            state.detachARCoordinator(identifier)
            arView = nil
        }



        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isCurrentSession else { return }
                for anchor in anchors {
                    if let image = anchor as? ARImageAnchor {
                        self.receiveImageAnchor(image)
                        continue
                    }
                    guard anchor.identifier == self.arenaAnchorID,
                          !self.arenaRendered else { continue }
                    self.arenaRendered = true
                    self.currentArenaAnchor = anchor
                    self.renderArena(on: anchor)
                }
            }
        }

        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isCurrentSession,
                      !self.interactionLocked else { return }
                for anchor in anchors {
                    if let image = anchor as? ARImageAnchor {
                        self.receiveImageAnchor(image)
                    }
                }
            }
        }

        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isCurrentSession else { return }
                for anchor in anchors {
                    guard anchor.identifier == self.currentImageAnchorID else {
                        continue
                    }
                    if self.waitingForCardClear {
                        self.finishWaitingForCardRemoval()
                    } else if !self.interactionLocked {
                        self.currentImageAnchorID = nil
                        self.handleTrackingLost()
                    }
                }
            }
        }

        // All scan state and anchor identifiers are owned by the main queue.
        // Only the first tracked image participates in this scan attempt.
        private func receiveImageAnchor(_ image: ARImageAnchor) {
            guard isCurrentSession else { return }
            if let currentImageAnchorID,
               currentImageAnchorID != image.identifier {
                return
            }
            if currentImageAnchorID == nil {
                currentImageAnchorID = image.identifier
                searchGeneration += 1
                print("🃏 Carta encontrada:",
                      image.referenceImage.name ?? "sem nome")
            }
            evaluateCard(transform: image.transform,
                         isTracked: image.isTracked,
                         cardName: image.referenceImage.name)
        }

        private func evaluateCard(

            transform: simd_float4x4,

            isTracked: Bool,

            cardName: String?

        ) {

            guard isCurrentSession, let arView else { return }

            if waitingForCardClear {



                state.phase = .waitingForCardRemoval



                if !isTracked {

                    finishWaitingForCardRemoval()

                }



                return

            }



            guard !interactionLocked else {

                return

            }



            guard let cardName,
                  let card = CardDatabase.card(named: cardName) else {
                // An unknown image must not leave a previous scan running.
                if isScanning { failScan(phase: .failed) }
                selectedCard = nil
                stableSince = nil
                lastCardPoint = nil
                state.recognizedCardName = cardName
                state.phase = .failed
                return
            }



            selectedCard = card

            latestCardTransform = transform

            state.recognizedCardName = cardName



            let worldPosition = SIMD3<Float>(

                transform.columns.3.x,

                transform.columns.3.y,

                transform.columns.3.z

            )



            guard let screenPoint = arView.project(worldPosition) else {

                return

            }



            let guideRect = ScanLayout

                .guideRect(in: arView.bounds.size)

                .insetBy(dx: 12, dy: 12)



            let centered = guideRect.contains(screenPoint)



            if isScanning {
                // Never switch characters in the middle of a scan.
                guard cardName == scanCardName else { return }
                if isTracked && centered {
                    lastValidScanSample = CACurrentMediaTime()
                    latestCardTransform = transform
                }
                // The scan clock checks the grace period even if ARKit stops
                // producing image updates completely.
                return
            }

            if !isTracked {
                stableSince = nil
                lastCardPoint = nil
                state.holdProgress = 0
                state.phase = .aligning
                return
            }

            guard centered else {

                stableSince = nil

                lastCardPoint = screenPoint

                state.holdProgress = 0

                state.phase = .aligning

                return

            }



            let now = CACurrentMediaTime()



            if let previous = lastCardPoint {

                let movement = hypot(

                    screenPoint.x - previous.x,

                    screenPoint.y - previous.y

                )



                if movement > 10 {

                    stableSince = now

                }

            }



            lastCardPoint = screenPoint



            if stableSince == nil {

                stableSince = now

            }



            guard let stableSince else {

                return

            }



            let elapsed = now - stableSince

            let progress = min(elapsed / holdDuration, 1)



            state.phase = .holding

            state.holdProgress = CGFloat(progress)



            if progress >= 1 {

                beginScan()

            }

        }



        func startSearching() {

            guard
                isCurrentSession,
                !interactionLocked,

                !waitingForCardClear

            else {

                return

            }

            SoundManager.shared.stopBattleResult()

            searchGeneration += 1

            let generation = searchGeneration
            stableSince = nil
            lastCardPoint = nil
            lastValidScanSample = nil
            scanCardName = nil

            selectedCard = nil

            latestCardTransform = nil



            state.phase = .searching

            state.holdProgress = 0

            state.scanProgress = 0

            state.scanSecondsRemaining = 0

            state.recognizedCardName = nil



            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                guard let self else { return }
                guard

                    generation == self.searchGeneration,
                    self.isCurrentSession,
                    !self.interactionLocked,

                    !self.waitingForCardClear,

                    self.currentImageAnchorID == nil

                else {

                    return

                }



                self.state.phase = .failed



                self.playImpactHaptic(.rigid)



                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    guard let self else { return }
                    guard

                        generation == self.searchGeneration,
                        self.isCurrentSession,
                        !self.waitingForCardClear

                    else {

                        return

                    }



                    self.startSearching()

                }

            }

        }



        private func handleTrackingLost() {



            if waitingForCardClear {

                finishWaitingForCardRemoval()

                return

            }



            guard !interactionLocked else {

                return

            }



            if isScanning {
                // Losing the anchor briefly is common in ARKit. The scan
                // tick will decide whether the grace period has expired.
                return
            }



            stableSince = nil

            lastCardPoint = nil



            state.holdProgress = 0

            state.phase = .lost



            let generation = searchGeneration + 1

            searchGeneration = generation



            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {



                guard

                    generation == self.searchGeneration,
                    self.isCurrentSession,
                    !self.interactionLocked
                else {

                    return

                }



                self.currentImageAnchorID = nil

                self.startSearching()

            }

        }



        private func beginScan() {

            guard

                !isScanning,

                !interactionLocked,

                selectedCard != nil,
                currentImageAnchorID != nil

            else {

                return

            }



            isScanning = true
            scanCardName = selectedCard?.referenceImageName
            lastValidScanSample = CACurrentMediaTime()

            scanGeneration += 1



            let generation = scanGeneration

            let startedAt = CACurrentMediaTime()



            state.phase = .scanning

            state.scanProgress = 0

            state.scanSecondsRemaining = scanDuration



            playImpactHaptic(.medium)



            updateScan(

                generation: generation,

                startedAt: startedAt

            )

        }



        private func updateScan(

            generation: Int,

            startedAt: TimeInterval

        ) {

            guard

                generation == scanGeneration,
                isScanning,
                isCurrentSession

            else {

                return

            }



            let now = CACurrentMediaTime()
            guard let lastValidScanSample,
                  now - lastValidScanSample <= scanTrackingGrace else {
                failScan(phase: .lost)
                return
            }

            let elapsed = now - startedAt
            let progress = min(elapsed / scanDuration, 1)



            state.scanProgress = CGFloat(progress)

            state.scanSecondsRemaining = max(scanDuration - elapsed, 0)



            if progress >= 1 {

                completeScan()

                return

            }



            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {

                self.updateScan(

                    generation: generation,

                    startedAt: startedAt

                )

            }

        }



        private func failScan(

            phase: CardScanPhase

        ) {

            scanGeneration += 1
            isScanning = false
            lastValidScanSample = nil
            scanCardName = nil

            stableSince = nil

            lastCardPoint = nil



            state.scanProgress = 0

            state.scanSecondsRemaining = 0

            state.holdProgress = 0

            state.phase = phase



            playImpactHaptic(.rigid)

        }



        private func completeScan() {
            guard
                isCurrentSession,
                let cardTransform = latestCardTransform,

                selectedCard != nil

            else {

                failScan(phase: .failed)

                return

            }



            isScanning = false
            lastValidScanSample = nil
            scanCardName = nil
            scanGeneration += 1
            interactionLocked = true
            let generation = scanGeneration

            state.scanProgress = 1

            state.scanSecondsRemaining = 0

            state.phase = .confirmed



            playNotificationHaptic(.success)



            SoundManager.shared.play(

                .scanSuccess,

                enabled: state.soundEnabled

            )



            DispatchQueue.main.asyncAfter(

                deadline: .now() + summonPreDelay
            ) { [weak self] in
                guard let self,
                      self.isCurrentSession,
                      self.scanGeneration == generation,
                      self.interactionLocked,
                      self.state.phase == .confirmed else { return }
                self.state.phase = .summoning



                self.playImpactHaptic(.heavy)



                SoundManager.shared.play(

                    .summonStart,

                    enabled: self.state.soundEnabled

                )



                self.createArenaAnchor(

                    cardTransform: cardTransform

                )

            }

        }



        private func recoverFromSummonFailure(_ reason: String) {
            guard isCurrentSession else { return }
            print("⚠️ Recovering scanner:", reason)
            clearCurrentArena()
            interactionLocked = false
            isScanning = false
            waitingForCardClear = false
            stableSince = nil
            lastCardPoint = nil
            lastValidScanSample = nil
            scanCardName = nil
            currentImageAnchorID = nil
            scanGeneration += 1
            state.phase = .failed

            // A session reset permits detection of the same physical card
            // after a failed invocation without requiring an app restart.
            if let arView,
               let config = arView.session.configuration {
                arView.session.run(config, options: [
                    .resetTracking, .removeExistingAnchors
                ])
            }
            startSearching()
        }

        private func createArenaAnchor(
            cardTransform: simd_float4x4
        ) {
            guard isCurrentSession, let arView,
                  let frame = arView.session.currentFrame else {
                recoverFromSummonFailure("AR frame unavailable")
                return
            }



            let cardPosition = SIMD3<Float>(

                cardTransform.columns.3.x,

                cardTransform.columns.3.y,

                cardTransform.columns.3.z

            )



            let cameraTransform = frame.camera.transform



            let cameraPosition = SIMD3<Float>(

                cameraTransform.columns.3.x,

                cameraTransform.columns.3.y,

                cameraTransform.columns.3.z

            )



            var direction = cardPosition - cameraPosition

            direction.y = 0



            if simd_length(direction) < 0.01 {

                direction = SIMD3<Float>(

                    -cameraTransform.columns.2.x,

                    0,

                    -cameraTransform.columns.2.z

                )

            }



            direction = simd_normalize(direction)



            var arenaPosition =

                cardPosition

                + direction

                * stageDistance



            arenaPosition.y = cardPosition.y



            var arenaTransform = matrix_identity_float4x4



            arenaTransform.columns.3 = SIMD4<Float>(

                arenaPosition.x,

                arenaPosition.y,

                arenaPosition.z,

                1

            )



            let arenaAnchor = ARAnchor(

                name: "CardArena",

                transform: arenaTransform

            )



            arenaAnchorID = arenaAnchor.identifier

            currentArenaAnchor = arenaAnchor



            arView.session.add(anchor: arenaAnchor)

            let expectedAnchorID = arenaAnchor.identifier
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
                guard let self, self.isCurrentSession,
                      self.arenaAnchorID == expectedAnchorID,
                      !self.arenaRendered else { return }
                self.recoverFromSummonFailure("Arena anchor was not delivered")
            }
        }



        private func renderArena(
            on arAnchor: ARAnchor
        ) {
            #if DEBUG
            let loadingStartedAt = CACurrentMediaTime()
            defer {
                logLoadingDuration(
                    "renderArena setup (async load started)",
                    startedAt: loadingStartedAt
                )
            }
            #endif
            guard isCurrentSession,
                  let arView, let selectedCard else {
                recoverFromSummonFailure("Missing AR view or selected card")
                return
            }



            let anchorEntity =

                AnchorEntity(

                    anchor: arAnchor

                )



            currentArenaEntity =

                anchorEntity



            let stage = makeStage()

            let aura = makeArenaAuraDisc()

            let smokeOuter = makeSmokeOuterEffect()

            let smokeInner = makeSmokeInnerEffect()

            let magic = makeMagicEffect()



            anchorEntity.addChild(stage)

            anchorEntity.addChild(aura)

            anchorEntity.addChild(smokeOuter)

            anchorEntity.addChild(smokeInner)

            anchorEntity.addChild(magic)



            // Apresenta o palco imediatamente; o download/processamento dos USDZ
            // nao pode bloquear a camera enquanto o personagem e preparado.
            arView.scene.addAnchor(anchorEntity)

            let expectedGeneration = assetLoadGeneration
            let expectedScan = scanGeneration
            let expectedAnchor = arAnchor.identifier
            let card = selectedCard

            Task { @MainActor [weak self] in
                guard let self else { return }
                let character = await self.makeCharacter(card)

                guard self.isCurrentSession,
                      self.assetLoadGeneration == expectedGeneration,
                      self.scanGeneration == expectedScan,
                      self.arenaAnchorID == expectedAnchor,
                      self.currentArenaEntity === anchorEntity,
                      self.state.phase == .summoning else {
                    self.clearAnimationState(for: character)
                    return
                }

                guard let character else {
                    self.recoverFromSummonFailure(
                        "Character model failed to load"
                    )
                    return
                }

                self.currentCharacterEntity = character
                self.orientCharacter(
                    character,
                    towardCameraFrom: arAnchor.transform,
                    yawOffset: card.yawOffset
                )
                character.position = SIMD3<Float>(
                    0, self.stageHeight, 0
                )
                character.scale = SIMD3<Float>(repeating: 0.90)

                print(
                    "👤 Invocando:", card.displayName,
                    "| carta:", card.referenceImageName, "→", card.modelName
                )

                self.runSummonAnimation(
                    character: character,
                    arenaAnchor: anchorEntity,
                    aura: aura,
                    smokeOuter: smokeOuter,
                    smokeInner: smokeInner,
                    magic: magic
                )
            }

        }



        /// Reuses the two RealityKit entities after a finished singleplayer duel.
        /// No AR session restart and no USDZ reload are performed here.
        func prepareSameCharacterRematch() -> Bool {
            guard isCurrentSession,
                  state.phase == .battleReady,
                  let arView,
                  let arena = currentArenaEntity,
                  currentArenaAnchor != nil,
                  arena.isAnchored,
                  let player = currentCharacterEntity,
                  let enemy = currentEnemyEntity,
                  player.parent != nil,
                  enemy.parent != nil,
                  let frame = arView.session.currentFrame,
                  case .normal = frame.camera.trackingState else {
                return false
            }

            // A final hit/death may be scheduled for later. Prevent it from
            // overriding the new duel's idle animations.
            battleAudioGeneration += 1
            floatingDamageGeneration += 1
            state.clearFloatingDamage()
            _ = playCharacterAnimation(.idle, on: player)
            _ = playCharacterAnimation(.idle, on: enemy)
            return true
        }

        func prepareBattle(
            with enemy: CardDefinition
        ) {
            #if DEBUG
            let loadingStartedAt = CACurrentMediaTime()
            defer {
                logLoadingDuration(
                    "prepareBattle \(enemy.referenceImageName) setup (async load started)",
                    startedAt: loadingStartedAt
                )
            }
            #endif
            guard isCurrentSession else { return }
            battleAudioGeneration += 1

            guard

                let arenaEntity =

                    currentArenaEntity,

                let arenaAnchor =

                    currentArenaAnchor,

                let player =

                    currentCharacterEntity

            else {
                recoverFromSummonFailure("Arena unavailable while preparing battle")
                state.reportBattlePreparationFailure(.arenaUnavailable)
                return
            }

            interactionLocked = true

            let generation = assetLoadGeneration
            Task { @MainActor [weak self] in
                guard let self else { return }
                let enemyEntity = await self.makeCharacter(enemy)

                // No enemy from a cancelled summon may enter a new battle.
                guard self.isCurrentSession,
                      self.assetLoadGeneration == generation,
                      self.currentArenaEntity === arenaEntity,
                      self.currentArenaAnchor === arenaAnchor,
                      self.currentCharacterEntity === player,
                      self.state.phase == .enemySummoning else {
                    self.clearAnimationState(for: enemyEntity)
                    return
                }

                guard let enemyEntity else {
                    self.interactionLocked = false
                    self.state.phase = .active
                    self.state.reportBattlePreparationFailure(.enemyModelUnavailable)
                    return
                }

                self.finishPrepareBattle(
                    with: enemy,
                    enemyEntity: enemyEntity,
                    arenaEntity: arenaEntity,
                    arenaAnchor: arenaAnchor,
                    player: player
                )
            }
        }

        @MainActor
        private func finishPrepareBattle(
            with enemy: CardDefinition,
            enemyEntity: Entity,
            arenaEntity: AnchorEntity,
            arenaAnchor: ARAnchor,
            player: Entity
        ) {
            var playerTarget =

                player.transform



            playerTarget.translation =

                SIMD3<Float>(

                    -self.battleCharacterOffset,

                    self.stageHeight,

                    0

                )



            player.move(

                to: playerTarget,

                relativeTo: arenaEntity,

                duration: 0.80,

                timingFunction: .easeInOut

            )



            currentEnemyEntity =

                enemyEntity



            orientCharacter(

                enemyEntity,

                towardCameraFrom:

                    arenaAnchor.transform,

                yawOffset:

                    enemy.yawOffset

            )



            enemyEntity.position =

                SIMD3<Float>(

                    self.battleCharacterOffset,

                    self.stageHeight,

                    0

                )



            enemyEntity.scale =

                SIMD3<Float>(

                    repeating: 0.90

                )



            let aura =

                makeSummonAuraDisc()



            let smokeOuter =

                makeSmokeOuterEffect()



            let smokeInner =

                makeSmokeInnerEffect()



            let magic =

                makeMagicEffect()



            aura.position.x +=

                self.battleCharacterOffset



            smokeOuter.position.x +=

                self.battleCharacterOffset



            smokeInner.position.x +=

                self.battleCharacterOffset



            magic.position.x +=

                self.battleCharacterOffset



            arenaEntity.addChild(

                aura

            )



            arenaEntity.addChild(

                smokeOuter

            )



            arenaEntity.addChild(

                smokeInner

            )



            arenaEntity.addChild(

                magic

            )



            SoundManager.shared.play(

                .summonStart,

                enabled:

                    state.soundEnabled

            )



            playImpactHaptic(

                .heavy

            )



            print(

                "🤖 CPU escolheu:",

                enemy.displayName,

                "→",

                enemy.modelName

            )



            runEnemySummonAnimation(

                enemy: enemyEntity,

                enemyCard: enemy,

                arenaAnchor: arenaEntity,

                aura: aura,

                smokeOuter: smokeOuter,

                smokeInner: smokeInner,

                magic: magic

            )

        }



        private func runEnemySummonAnimation(

            enemy: Entity,

            enemyCard: CardDefinition,

            arenaAnchor: AnchorEntity,

            aura: Entity,

            smokeOuter: Entity,

            smokeInner: Entity,

            magic: Entity

        ) {



            fadeIn(

                aura,

                duration: 0.40

            )



            let revealStart:

                TimeInterval = 1.80



            DispatchQueue.main.asyncAfter(

                deadline:

                    .now()

                    + revealStart
            ) { [weak self] in
                guard let self else { return }
                // Visual reveal only. The AR scan and battle timing are unchanged.
                guard self.isCurrentSession,
                      self.currentArenaEntity === arenaAnchor,
                      self.currentEnemyEntity === enemy else {
                    return
                }

                self.materializeCharacter(
                    enemy,
                    in: arenaAnchor,
                    at: SIMD3<Float>(
                        self.battleCharacterOffset,
                        self.stageHeight,
                        0
                    ),
                    duration: 1.00
                )

                SoundManager.shared.play(

                    .summonReveal,

                    enabled:

                        self.state.soundEnabled

                )



                self.playImpactHaptic(

                    .medium

                )

            }



            let smokeStopTime =

                revealStart

                + 1.00

                + 0.70



            DispatchQueue.main.asyncAfter(

                deadline:

                    .now()

                    + smokeStopTime
            ) { [weak self] in
                guard let self,
                      self.isCurrentSession,
                      self.currentArenaEntity === arenaAnchor,
                      self.currentEnemyEntity === enemy,
                      self.state.phase == .enemySummoning else { return }




                self.stopEmitter(

                    smokeOuter

                )



                self.stopEmitter(

                    smokeInner

                )



                self.stopEmitter(

                    magic

                )

            }



            let cleanupTime =

                smokeStopTime

                + 1.20



            DispatchQueue.main.asyncAfter(

                deadline:

                    .now()

                    + cleanupTime
            ) { [weak self] in
                guard let self,
                      self.isCurrentSession,
                      self.currentArenaEntity === arenaAnchor,
                      self.currentEnemyEntity === enemy,
                      self.state.phase == .enemySummoning else { return }




                smokeOuter.removeFromParent()

                smokeInner.removeFromParent()

                magic.removeFromParent()



                self.fadeOut(

                    aura,

                    duration: 0.40

                )

            }



            DispatchQueue.main.asyncAfter(

                deadline:

                    .now()

                    + cleanupTime
                    + 0.45
            ) { [weak self] in
                guard let self,
                      self.isCurrentSession,
                      self.currentArenaEntity === arenaAnchor,
                      self.currentEnemyEntity === enemy,
                      self.state.phase == .enemySummoning else { return }




                aura.removeFromParent()



                guard let player = self.currentCharacterEntity else {
                    self.recoverFromSummonFailure(
                        "Player entity unavailable during enemy summon"
                    )
                    self.state.reportBattlePreparationFailure(.arenaUnavailable)
                    return
                }



                DispatchQueue.main.asyncAfter(

                    deadline:

                        .now()

                        + self.battleFacingDelay
                ) { [weak self] in
                    guard let self,
                          self.isCurrentSession,
                          self.currentArenaEntity === arenaAnchor,
                          self.currentCharacterEntity === player,
                          self.currentEnemyEntity === enemy,
                          self.state.phase == .enemySummoning else { return }
                    self.moveCharactersToBattleStance(

                        player: player,

                        enemy: enemy,

                        playerYawOffset:

                            self.selectedCard?.yawOffset

                            ?? 0,

                        enemyYawOffset:

                            enemyCard.yawOffset

                    )

                }

            }

        }



        private func moveCharactersToBattleStance(
            player: Entity,
            enemy: Entity,
            playerYawOffset: Float,
            enemyYawOffset: Float
        ) {
            guard isCurrentSession,
                  state.phase == .enemySummoning,
                  currentCharacterEntity === player,
                  currentEnemyEntity === enemy,
                  let arenaEntity = currentArenaEntity
            else {

                return

            }



            var playerTarget =

                player.transform



            playerTarget.translation =

                SIMD3<Float>(

                    -battleCharacterOffset,

                    stageHeight,

                    0

                )



            playerTarget.rotation =

                simd_quatf(

                    angle:

                        (.pi / 2)

                        + playerYawOffset,

                    axis:

                        SIMD3<Float>(

                            0,

                            1,

                            0

                        )

                )



            var enemyTarget =

                enemy.transform



            enemyTarget.translation =

                SIMD3<Float>(

                    battleCharacterOffset,

                    stageHeight,

                    0

                )



            enemyTarget.rotation =

                simd_quatf(

                    angle:

                        (-.pi / 2)

                        + enemyYawOffset,

                    axis:

                        SIMD3<Float>(

                            0,

                            1,

                            0

                        )

                )



            player.move(

                to: playerTarget,

                relativeTo: arenaEntity,

                duration: battleTurnDuration,

                timingFunction: .easeInOut

            )



            enemy.move(

                to: enemyTarget,

                relativeTo: arenaEntity,

                duration: battleTurnDuration,

                timingFunction: .easeInOut

            )



            playImpactHaptic(

                .light

            )



            DispatchQueue.main.asyncAfter(

                deadline:
                    .now()
                    + battleTurnDuration
                    + 0.15
            ) { [weak self] in
                guard let self,
                      self.isCurrentSession,
                      self.state.phase == .enemySummoning,
                      self.currentArenaEntity === arenaEntity,
                      self.currentCharacterEntity === player,
                      self.currentEnemyEntity === enemy else { return }
                self.state.phase =
                    .battleReady



                self.playNotificationHaptic(

                    .success

                )

            }

        }



        func removeCurrentCharacter() {
            guard
                isCurrentSession,
                !removalInProgress,

                state.phase == .removing,

                let arenaEntity = currentArenaEntity,

                let character = currentCharacterEntity

            else {

                return

            }



            removalInProgress = true

            interactionLocked = true



            SoundManager.shared.play(

                .despawn,

                enabled: state.soundEnabled

            )



            let aura = makeArenaAuraDisc()

            let smokeOuter = makeDespawnSmokeOuterEffect()

            let smokeInner = makeDespawnSmokeInnerEffect()

            let magic = makeDespawnMagicEffect()



            arenaEntity.addChild(aura)

            arenaEntity.addChild(smokeOuter)

            arenaEntity.addChild(smokeInner)

            arenaEntity.addChild(magic)



            fadeIn(

                aura,

                duration: 0.45

            )



            playImpactHaptic(.medium)



            DispatchQueue.main.asyncAfter(

                deadline: .now() + 0.80
            ) { [weak self] in
                guard let self,
                      self.isCurrentSession,
                      self.currentArenaEntity === arenaEntity,
                      self.currentCharacterEntity === character,
                      self.state.phase == .removing else { return }




                var target =

                    character.transform



                target.translation.y =

                    max(

                        self.stageHeight,

                        target.translation.y - 0.10

                    )



                target.scale =

                    SIMD3<Float>(

                        repeating: 0.88

                    )



                character.move(

                    to: target,

                    relativeTo: character.parent,

                    duration: 1.00,

                    timingFunction: .easeInOut

                )



                self.fadeOut(

                    character,

                    duration: 1.00

                )

            }



            DispatchQueue.main.asyncAfter(

                deadline: .now() + 1.90
            ) { [weak self] in
                guard let self,
                      self.isCurrentSession,
                      self.currentArenaEntity === arenaEntity,
                      self.currentCharacterEntity === character,
                      self.state.phase == .removing else { return }




                character.removeFromParent()



                self.playImpactHaptic(.heavy)

            }



            DispatchQueue.main.asyncAfter(

                deadline: .now() + 2.50
            ) { [weak self] in
                guard let self,
                      self.isCurrentSession,
                      self.currentArenaEntity === arenaEntity,
                      self.currentCharacterEntity === character,
                      self.state.phase == .removing else { return }




                self.stopEmitter(

                    smokeOuter

                )



                self.stopEmitter(

                    smokeInner

                )



                self.stopEmitter(

                    magic

                )

            }



            DispatchQueue.main.asyncAfter(

                deadline: .now() + 3.30
            ) { [weak self] in
                guard let self,
                      self.isCurrentSession,
                      self.currentArenaEntity === arenaEntity,
                      self.currentCharacterEntity === character,
                      self.state.phase == .removing else { return }




                self.fadeOut(

                    aura,

                    duration: 0.50

                )

            }



            DispatchQueue.main.asyncAfter(

                deadline: .now() + 3.70
            ) { [weak self] in
                guard let self,
                      self.isCurrentSession,
                      self.currentArenaEntity === arenaEntity,
                      self.currentCharacterEntity === character,
                      self.state.phase == .removing else { return }




                smokeOuter.removeFromParent()

                smokeInner.removeFromParent()

                magic.removeFromParent()

                aura.removeFromParent()



                self.clearCurrentArena()



                self.waitingForCardClear = true

                self.interactionLocked = false

                self.removalInProgress = false



                self.stableSince = nil

                self.lastCardPoint = nil

                self.isScanning = false



                self.state.holdProgress = 0

                self.state.scanProgress = 0

                self.state.scanSecondsRemaining = 0

                self.state.phase = .waitingForCardRemoval



                self.playNotificationHaptic(.success)

            }

        }



        private func makeDespawnSmokeOuterEffect()

            -> Entity {



            let entity = Entity()



            var emitter =

                ParticleEmitterComponent

                    .Presets

                    .snow



            emitter.emitterShape = .box



            emitter.emitterShapeSize =

                SIMD3<Float>(

                    0.46,

                    0.58,

                    0.46

                )



            emitter.birthLocation = .volume

            emitter.birthDirection = .local



            emitter.emissionDirection =

                SIMD3<Float>(

                    0,

                    1,

                    0

                )



            emitter.speed = 0.028

            emitter.speedVariation = 0.014



            emitter.mainEmitter.birthRate = 360

            emitter.mainEmitter.size = 0.050

            emitter.mainEmitter.sizeVariation = 0.020

            emitter.mainEmitter.blendMode = .alpha

            emitter.mainEmitter.opacityCurve = .gradualFadeInOut



            typealias ParticleEmitter =

                ParticleEmitterComponent.ParticleEmitter



            let startColor =

                ParticleEmitter.Color(

                    red: 0.30,

                    green: 0.27,

                    blue: 0.36,

                    alpha: 0.72

                )



            let endColor =

                ParticleEmitter.Color(

                    red: 0.14,

                    green: 0.12,

                    blue: 0.18,

                    alpha: 0

                )



            emitter.mainEmitter.color =

                .evolving(

                    start:

                        .single(startColor),

                    end:

                        .single(endColor)

                )



            entity.components.set(

                emitter

            )



            entity.position =

                SIMD3<Float>(

                    0,

                    0.29,

                    0

                )



            return entity

        }



        private func makeDespawnSmokeInnerEffect()

            -> Entity {



            let entity = Entity()



            var emitter =

                ParticleEmitterComponent

                    .Presets

                    .snow



            emitter.emitterShape = .box



            emitter.emitterShapeSize =

                SIMD3<Float>(

                    0.30,

                    0.50,

                    0.30

                )



            emitter.birthLocation = .volume

            emitter.birthDirection = .local



            emitter.emissionDirection =

                SIMD3<Float>(

                    0,

                    1,

                    0

                )



            emitter.speed = 0.020

            emitter.speedVariation = 0.010



            emitter.mainEmitter.birthRate = 300

            emitter.mainEmitter.size = 0.040

            emitter.mainEmitter.sizeVariation = 0.016

            emitter.mainEmitter.blendMode = .alpha

            emitter.mainEmitter.opacityCurve = .gradualFadeInOut



            typealias ParticleEmitter =

                ParticleEmitterComponent.ParticleEmitter



            let smokeColor =

                ParticleEmitter.Color(

                    red: 0.24,

                    green: 0.21,

                    blue: 0.30,

                    alpha: 0.80

                )



            emitter.mainEmitter.color =

                .constant(

                    .single(

                        smokeColor

                    )

                )



            entity.components.set(

                emitter

            )



            entity.position =

                SIMD3<Float>(

                    0,

                    0.31,

                    0

                )



            return entity

        }



        private func makeDespawnMagicEffect()

            -> Entity {



            let entity = Entity()



            var emitter =

                ParticleEmitterComponent

                    .Presets

                    .magic



            emitter.emitterShape =

                .cylinder



            emitter.emitterShapeSize =

                SIMD3<Float>(

                    0.34,

                    0.03,

                    0.34

                )



            emitter.birthLocation =

                .volume



            emitter.mainEmitter.birthRate =

                45



            emitter.mainEmitter.size =

                0.010



            entity.components.set(

                emitter

            )



            entity.position =

                SIMD3<Float>(

                    0,

                    0.07,

                    0

                )



            return entity

        }



        private func clearCurrentArena() {

            floatingDamageGeneration += 1
            state.clearFloatingDamage()
            battleAudioGeneration += 1
            assetLoadGeneration += 1

            guard let arView else {

                return

            }



            if let arenaEntity =

                currentArenaEntity {



                arView.scene.removeAnchor(

                    arenaEntity

                )

            }



            if let arenaAnchor =

                currentArenaAnchor {



                arView.session.remove(

                    anchor: arenaAnchor

                )

            }



            clearAnimationState(for: currentCharacterEntity)
            clearAnimationState(for: currentEnemyEntity)

            currentArenaEntity = nil

            currentArenaAnchor = nil

            currentCharacterEntity = nil

            currentEnemyEntity = nil



            state.activeCard = nil



            arenaAnchorID = nil

            arenaRendered = false

        }



        private func finishWaitingForCardRemoval() {



            guard waitingForCardClear else {

                return

            }



            waitingForCardClear = false



            currentImageAnchorID = nil

            latestCardTransform = nil

            selectedCard = nil



            stableSince = nil

            lastCardPoint = nil



            state.recognizedCardName = nil

            state.holdProgress = 0

            state.scanProgress = 0

            state.scanSecondsRemaining = 0



            startSearching()

        }



        private func makeStage()

            -> ModelEntity {



            let mesh =

                MeshResource

                    .generateCylinder(

                        height: stageHeight,

                        radius: stageRadius

                    )



            let material =

                SimpleMaterial(

                    color:

                        UIColor.darkGray,

                    roughness: 0.55,

                    isMetallic: true

                )



            let stage =

                ModelEntity(

                    mesh: mesh,

                    materials: [material]

                )



            stage.position.y =

                stageHeight / 2



            return stage

        }



        private func makeArenaAuraDisc()

            -> ModelEntity {



            let mesh =

                MeshResource.generateCylinder(

                    height: 0.004,

                    radius:

                        stageRadius * 0.98

                )



            let material =

                SimpleMaterial(

                    color:

                        UIColor.systemPurple

                            .withAlphaComponent(

                                0.9

                            ),

                    roughness: 0.1,

                    isMetallic: false

                )



            let aura =

                ModelEntity(

                    mesh: mesh,

                    materials: [material]

                )



            aura.position.y =

                stageHeight + 0.003



            aura.components.set(

                OpacityComponent(

                    opacity: 0

                )

            )



            return aura

        }



        private func makeSummonAuraDisc()

            -> ModelEntity {



            let mesh =

                MeshResource.generateCylinder(

                    height: 0.004,

                    radius: 0.16

                )



            let material =

                SimpleMaterial(

                    color:

                        UIColor.systemPurple

                            .withAlphaComponent(

                                0.9

                            ),

                    roughness: 0.1,

                    isMetallic: false

                )



            let aura =

                ModelEntity(

                    mesh: mesh,

                    materials: [material]

                )



            aura.position.y =

                stageHeight + 0.003



            aura.components.set(

                OpacityComponent(

                    opacity: 0

                )

            )



            return aura

        }



        private func makeSmokeOuterEffect()

            -> Entity {



            let entity = Entity()



            var emitter =

                ParticleEmitterComponent

                    .Presets

                    .snow



            emitter.emitterShape = .box

            emitter.emitterShapeSize =

                SIMD3<Float>(

                    0.48,

                    0.55,

                    0.48

                )



            emitter.birthLocation = .volume

            emitter.birthDirection = .local



            emitter.emissionDirection =

                SIMD3<Float>(

                    0,

                    1,

                    0

                )



            emitter.speed = 0.025

            emitter.speedVariation = 0.012



            emitter.mainEmitter.birthRate = 320

            emitter.mainEmitter.size = 0.055

            emitter.mainEmitter.sizeVariation = 0.025

            emitter.mainEmitter.blendMode = .alpha

            emitter.mainEmitter.opacityCurve = .gradualFadeInOut



            typealias ParticleEmitter =

                ParticleEmitterComponent.ParticleEmitter



            let startColor =

                ParticleEmitter.Color(

                    red: 0.18,

                    green: 0.16,

                    blue: 0.22,

                    alpha: 0.75

                )



            let endColor =

                ParticleEmitter.Color(

                    red: 0.08,

                    green: 0.07,

                    blue: 0.10,

                    alpha: 0

                )



            emitter.mainEmitter.color =

                .evolving(

                    start:

                        .single(startColor),

                    end:

                        .single(endColor)

                )



            entity.components.set(

                emitter

            )



            entity.position =

                SIMD3<Float>(

                    0,

                    0.28,

                    0

                )



            return entity

        }



        private func makeSmokeInnerEffect()

            -> Entity {



            let entity = Entity()



            var emitter =

                ParticleEmitterComponent

                    .Presets

                    .snow



            emitter.emitterShape = .box



            emitter.emitterShapeSize =

                SIMD3<Float>(

                    0.30,

                    0.48,

                    0.30

                )



            emitter.birthLocation = .volume

            emitter.birthDirection = .local



            emitter.emissionDirection =

                SIMD3<Float>(

                    0,

                    1,

                    0

                )



            emitter.speed = 0.018

            emitter.speedVariation = 0.008



            emitter.mainEmitter.birthRate = 260

            emitter.mainEmitter.size = 0.045

            emitter.mainEmitter.sizeVariation = 0.018

            emitter.mainEmitter.blendMode = .alpha

            emitter.mainEmitter.opacityCurve = .gradualFadeInOut



            typealias ParticleEmitter =

                ParticleEmitterComponent.ParticleEmitter



            let smokeColor =

                ParticleEmitter.Color(

                    red: 0.12,

                    green: 0.10,

                    blue: 0.15,

                    alpha: 0.85

                )



            emitter.mainEmitter.color =

                .constant(

                    .single(

                        smokeColor

                    )

                )



            entity.components.set(

                emitter

            )



            entity.position =

                SIMD3<Float>(

                    0,

                    0.30,

                    0

                )



            return entity

        }



        private func makeMagicEffect()

            -> Entity {



            let entity = Entity()



            var emitter =

                ParticleEmitterComponent

                    .Presets

                    .magic



            emitter.emitterShape =

                .cylinder



            emitter.emitterShapeSize =

                SIMD3<Float>(

                    0.36,

                    0.03,

                    0.36

                )



            emitter.birthLocation =

                .volume



            emitter.mainEmitter.birthRate =

                35



            emitter.mainEmitter.size =

                0.012



            entity.components.set(

                emitter

            )



            entity.position =

                SIMD3<Float>(

                    0,

                    0.06,

                    0

                )



            return entity

        }



        // MARK: - Holographic character materialization (visual only)

        private func materializeCharacter(
            _ character: Entity,
            in arenaAnchor: AnchorEntity,
            at finalPosition: SIMD3<Float>,
            duration: TimeInterval
        ) {
            // Fade and scale the entire imported-model hierarchy without
            // changing its animations or the card-detection state machine.
            character.components.set(OpacityComponent(opacity: 0))
            character.position = finalPosition + SIMD3<Float>(0, 0.10, 0)
            character.scale = SIMD3<Float>(repeating: 0.70)
            arenaAnchor.addChild(character)

            var finalTransform = character.transform
            finalTransform.translation = finalPosition
            finalTransform.scale = SIMD3<Float>(repeating: 1.0)

            character.move(
                to: finalTransform,
                relativeTo: arenaAnchor,
                duration: duration,
                timingFunction: .easeInOut
            )

            fadeIn(character, duration: duration * 0.88)

            // Two short light pulses give a cyan/violet AR-style arrival,
            // using primitive meshes so no extra USDZ or textures are needed.
            playMaterializationPulse(
                in: arenaAnchor,
                at: finalPosition,
                color: .systemCyan,
                delay: 0
            )

            playMaterializationPulse(
                in: arenaAnchor,
                at: finalPosition,
                color: .systemPurple,
                delay: 0.16
            )
        }

        private func playMaterializationPulse(
            in arenaAnchor: AnchorEntity,
            at position: SIMD3<Float>,
            color: UIColor,
            delay: TimeInterval
        ) {
            let pulse = ModelEntity(
                mesh: MeshResource.generateCylinder(
                    height: 0.003,
                    radius: 0.18
                ),
                materials: [
                    SimpleMaterial(
                        color: color.withAlphaComponent(0.7),
                        roughness: 0.1,
                        isMetallic: false
                    )
                ]
            )

            pulse.position = SIMD3<Float>(
                position.x,
                stageHeight + 0.014,
                position.z
            )
            pulse.scale = SIMD3<Float>(repeating: 0.55)
            pulse.components.set(OpacityComponent(opacity: 0))
            arenaAnchor.addChild(pulse)

            let pulseDuration: TimeInterval = 0.72
            let steps = 12

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                [weak self] in
                guard let self,
                      self.isCurrentSession,
                      self.currentArenaEntity === arenaAnchor else {
                    pulse.removeFromParent()
                    return
                }

                pulse.components.set(
                    OpacityComponent(opacity: 0.42)
                )

                var expanded = pulse.transform
                expanded.scale = SIMD3<Float>(repeating: 2.30)

                pulse.move(
                    to: expanded,
                    relativeTo: arenaAnchor,
                    duration: pulseDuration,
                    timingFunction: .easeOut
                )

                for step in 1...steps {
                    let fraction = Float(step) / Float(steps)
                    let remainingOpacity: Float = 0.42 * (1 - fraction)
                    let stepDelay = pulseDuration * Double(step) / Double(steps)

                    DispatchQueue.main.asyncAfter(deadline: .now() + stepDelay) {
                        pulse.components.set(
                            OpacityComponent(opacity: remainingOpacity)
                        )
                    }
                }

                DispatchQueue.main.asyncAfter(
                    deadline: .now() + pulseDuration + 0.05
                ) {
                    pulse.removeFromParent()
                }
            }
        }

        private func runSummonAnimation(

            character: Entity,

            arenaAnchor: AnchorEntity,

            aura: Entity,

            smokeOuter: Entity,

            smokeInner: Entity,

            magic: Entity

        ) {



            fadeIn(

                aura,

                duration: 0.45

            )



            let revealStart:

                TimeInterval = 2.70



            DispatchQueue.main.asyncAfter(

                deadline:

                    .now()

                    + revealStart
            ) { [weak self] in
                guard let self else { return }
                // Visual reveal only. The AR scan and battle timing are unchanged.
                guard self.isCurrentSession,
                      self.currentArenaEntity === arenaAnchor,
                      self.currentCharacterEntity === character else {
                    return
                }

                self.materializeCharacter(
                    character,
                    in: arenaAnchor,
                    at: SIMD3<Float>(
                        0,
                        self.stageHeight,
                        0
                    ),
                    duration: 1.15
                )

                SoundManager.shared.play(

                    .summonReveal,

                    enabled: self.state.soundEnabled

                )



                self.playImpactHaptic(

                    .medium

                )

            }



            let revealFinished =

                revealStart + 1.15



            let smokeStopTime =

                revealFinished + 0.90



            DispatchQueue.main.asyncAfter(

                deadline:

                    .now()

                    + smokeStopTime
            ) { [weak self] in
                guard let self,
                      self.isCurrentSession,
                      self.currentArenaEntity === arenaAnchor,
                      self.currentCharacterEntity === character,
                      self.state.phase == .summoning else { return }




                self.stopEmitter(

                    smokeInner

                )



                self.stopEmitter(

                    smokeOuter

                )



                self.stopEmitter(

                    magic

                )

            }



            let cleanupTime =

                smokeStopTime + 1.40



            DispatchQueue.main.asyncAfter(

                deadline:

                    .now()

                    + cleanupTime
            ) { [weak self] in
                guard let self,
                      self.isCurrentSession,
                      self.currentArenaEntity === arenaAnchor,
                      self.currentCharacterEntity === character,
                      self.state.phase == .summoning else { return }




                smokeInner.removeFromParent()

                smokeOuter.removeFromParent()

                magic.removeFromParent()



                self.fadeOut(

                    aura,

                    duration: 0.40

                )



                self.playImpactHaptic(.heavy)

            }



            DispatchQueue.main.asyncAfter(

                deadline:

                    .now()

                    + cleanupTime
                    + 0.50
            ) { [weak self] in
                guard let self,
                      self.isCurrentSession,
                      self.currentArenaEntity === arenaAnchor,
                      self.currentCharacterEntity === character,
                      self.state.phase == .summoning else { return }




                aura.removeFromParent()



                self.state.activeCard =

                    self.selectedCard



                self.state.phase =

                    .active



                self.playNotificationHaptic(.success)

            }

        }



        private func stopEmitter(

            _ entity: Entity

        ) {



            guard var emitter =

                    entity.components[

                        ParticleEmitterComponent.self

                    ]

            else {

                return

            }



            emitter.mainEmitter.birthRate =

                0



            entity.components.set(

                emitter

            )

        }



        private func fadeIn(

            _ entity: Entity,

            duration: TimeInterval

        ) {



            let steps = 14



            for step in 1...steps {



                let delay =

                    duration

                    * Double(step)

                    / Double(steps)



                DispatchQueue.main.asyncAfter(

                    deadline:

                        .now() + delay

                ) {



                    entity.components.set(

                        OpacityComponent(

                            opacity:

                                Float(step)

                                / Float(steps)

                        )

                    )

                }

            }

        }



        private func fadeOut(

            _ entity: Entity,

            duration: TimeInterval

        ) {



            let steps = 14



            for step in 1...steps {



                let delay =

                    duration

                    * Double(step)

                    / Double(steps)



                DispatchQueue.main.asyncAfter(

                    deadline:

                        .now() + delay

                ) {



                    let opacity =

                        1

                        - Float(step)

                        / Float(steps)



                    entity.components.set(

                        OpacityComponent(

                            opacity:

                                max(

                                    opacity,

                                    0

                                )

                        )

                    )

                }

            }

        }



        private func playImpactHaptic(

            _ style: UIImpactFeedbackGenerator.FeedbackStyle

        ) {

            guard state.hapticsEnabled else {

                return

            }



            UIImpactFeedbackGenerator(

                style: style

            )

            .impactOccurred()

        }



        private func playNotificationHaptic(

            _ type: UINotificationFeedbackGenerator.FeedbackType

        ) {

            guard state.hapticsEnabled else {

                return

            }



            UINotificationFeedbackGenerator()

                .notificationOccurred(

                    type

                )

        }



        private func orientCharacter(

            _ character: Entity,

            towardCameraFrom

                arenaTransform:

                    simd_float4x4,

            yawOffset: Float

        ) {



            guard

                let arView,

                let frame =

                    arView.session.currentFrame

            else {

                return

            }



            let cameraTransform =

                frame.camera.transform



            let cameraPosition =

                SIMD3<Float>(

                    cameraTransform.columns.3.x,

                    cameraTransform.columns.3.y,

                    cameraTransform.columns.3.z

                )



            let arenaPosition =

                SIMD3<Float>(

                    arenaTransform.columns.3.x,

                    arenaTransform.columns.3.y,

                    arenaTransform.columns.3.z

                )



            var direction =

                cameraPosition

                - arenaPosition



            direction.y = 0



            guard

                simd_length(

                    direction

                ) > 0.001

            else {

                return

            }



            direction =

                simd_normalize(

                    direction

                )



            let angle =

                atan2(

                    direction.x,

                    direction.z

                )

                + yawOffset



            character.orientation =

                simd_quatf(

                    angle: angle,

                    axis:

                        SIMD3<Float>(

                            0,

                            1,

                            0

                        )

                )

        }



        // The async initializer accepts an asset base name (without .usdz).
        private func realityAssetBaseName(_ fileName: String) -> String {
            fileName.lowercased().hasSuffix(".usdz")
                ? String(fileName.dropLast(5))
                : fileName
        }

        // MARK: - Character animations

        @MainActor
        private func loadAnimationResource(
            named fileName: String,
            logFailure: Bool = true
        ) async -> AnimationResource? {

            if let cached =
                animationResourceCache[fileName] {

                return cached
            }

            if missingAnimationResourceFiles
                .contains(fileName) {

                return nil
            }

            #if DEBUG
            let loadingStartedAt = CACurrentMediaTime()
            defer {
                logLoadingDuration(
                    "animation \(fileName)",
                    startedAt: loadingStartedAt
                )
            }
            #endif

            do {

                let source =
                    try await Entity(
                        named: realityAssetBaseName(fileName)
                    )

                guard let animation =
                        source
                            .availableAnimations
                            .first
                else {

                    missingAnimationResourceFiles
                        .insert(fileName)

                    if logFailure {

                        print(
                            "⚠️ Animação não encontrada:",
                            fileName
                        )
                    }

                    return nil
                }

                animationResourceCache[fileName] =
                    animation

                print(
                    "🎬 Animação carregada:",
                    fileName
                )

                return animation

            } catch {

                missingAnimationResourceFiles
                    .insert(fileName)

                if logFailure {

                    print(
                        "⚠️ Arquivo de animação indisponível:",
                        fileName
                    )
                }

                return nil
            }
        }

        @MainActor
        private func loadAnimationResource(
            from source: CharacterAnimationSource,
            animatedModel: Entity
        ) async -> AnimationResource? {

            switch source {

            case .embedded:

                return animatedModel
                    .availableAnimations
                    .first

            case .file(let fileName):

                return await loadAnimationResource(
                    named: fileName
                )

            case .firstAvailable(
                let fileNames
            ):

                for fileName in fileNames {

                    if let animation =
                        await loadAnimationResource(
                            named: fileName,
                            logFailure: false
                        ) {

                        return animation
                    }
                }

                if let firstName =
                    fileNames.first {

                    print(
                        "⚠️ Nenhum arquivo de animação encontrado para:",
                        firstName
                    )
                }

                return nil
            }
        }

        // Os resultados de AnimationResource nao saem do MainActor.
        // Tarefas paralelas retornam Void e compartilham apenas este acumulador
        // isolado no mesmo ator, evitando transferencias non-Sendable.
        @MainActor
        private final class AnimationLoadResults {
            var loaded: [CharacterAnimationKind: AnimationResource] = [:]
        }

        // Carrega cada grupo sequencialmente, mantendo no maximo tres USDZ
        // em processamento ao mesmo tempo para limitar pressao de memoria.
        @MainActor
        private func loadAnimationLane(
            kinds: [CharacterAnimationKind],
            animationSet: CharacterAnimationSet,
            animatedModel: Entity,
            results: AnimationLoadResults,
            expectedLoadGeneration: Int
        ) async {
            for kind in kinds {
                guard isCurrentSession,
                      assetLoadGeneration == expectedLoadGeneration else {
                    return
                }
                guard let source = animationSet[kind] else { continue }
                if let resource = await loadAnimationResource(
                    from: source,
                    animatedModel: animatedModel
                ) {
                    results.loaded[kind] = resource
                }
            }
        }

        @MainActor
        private func registerAnimations(
            for card: CardDefinition,
            character: Entity,
            animatedModel: Entity,
            expectedLoadGeneration: Int
        ) async {
            guard isCurrentSession,
                  assetLoadGeneration == expectedLoadGeneration else { return }

            #if DEBUG
            let loadingStartedAt = CACurrentMediaTime()
            defer {
                logLoadingDuration(
                    "registerAnimations \(card.referenceImageName) total (3 lanes, progressive)",
                    startedAt: loadingStartedAt
                )
            }
            #endif

            let key = ObjectIdentifier(character)
            var animations: [CharacterAnimationKind: AnimationResource] = [:]

            if let animationSet = card.animations {
                let kinds = CharacterAnimationKind.allCases.filter {
                    animationSet[$0] != nil
                }
                let lane0 = kinds.enumerated().compactMap {
                    $0.offset % 3 == 0 ? $0.element : nil
                }
                let lane1 = kinds.enumerated().compactMap {
                    $0.offset % 3 == 1 ? $0.element : nil
                }
                let lane2 = kinds.enumerated().compactMap {
                    $0.offset % 3 == 2 ? $0.element : nil
                }

                let results = AnimationLoadResults()
                let generation = expectedLoadGeneration
                let task0 = Task { @MainActor in
                    await self.loadAnimationLane(
                        kinds: lane0,
                        animationSet: animationSet,
                        animatedModel: animatedModel,
                        results: results,
                        expectedLoadGeneration: generation
                    )
                }
                let task1 = Task { @MainActor in
                    await self.loadAnimationLane(
                        kinds: lane1,
                        animationSet: animationSet,
                        animatedModel: animatedModel,
                        results: results,
                        expectedLoadGeneration: generation
                    )
                }
                let task2 = Task { @MainActor in
                    await self.loadAnimationLane(
                        kinds: lane2,
                        animationSet: animationSet,
                        animatedModel: animatedModel,
                        results: results,
                        expectedLoadGeneration: generation
                    )
                }

                await task0.value
                await task1.value
                await task2.value
                animations = results.loaded
            } else if let idle = animatedModel.availableAnimations.first {
                animations[.idle] = idle
            }

            // O modelo já está visível e a animação Idle já está rodando.
            // Apenas acrescenta os recursos recebidos, sem reiniciar Idle
            // nem restaurar dados de um personagem removido.
            guard isCurrentSession,
                  assetLoadGeneration == expectedLoadGeneration,
                  characterAnimatedModels[key] === animatedModel,
                  var existingAnimations = characterAnimations[key] else {
                return
            }
            for (kind, animation) in animations {
                existingAnimations[kind] = animation
            }
            characterAnimations[key] = existingAnimations

            let loadedKinds = CharacterAnimationKind.allCases.filter {
                existingAnimations[$0] != nil
            }
            print(
                "🎭 Animações registradas:",
                card.displayName, "|", loadedKinds
            )
        }

        private func animationKind(
            for move: BattleMove
        ) -> CharacterAnimationKind {

            switch move {

            case .impact:
                return .impact

            case .technique:
                return .technique

            case .defense:
                return .defense
            }
        }

        private func resolvedAnimationKind(
            requested kind:
                CharacterAnimationKind,
            available animations:
                [
                    CharacterAnimationKind:
                        AnimationResource
                ]
        ) -> CharacterAnimationKind? {

            if animations[kind] != nil {
                return kind
            }

            if kind == .technique,
               animations[.impact] != nil {

                print(
                    "↪️ Técnica sem animação. Usando Impacto como fallback."
                )

                return .impact
            }

            if animations[.idle] != nil {

                print(
                    "↪️ Animação",
                    kind,
                    "indisponível. Usando Idle."
                )

                return .idle
            }

            return nil
        }

        func playBattleTurnAnimations(
            playerMove: BattleMove,
            enemyMove: BattleMove,
            result: BattleRoundResult,
            winner: BattleWinner?,
            damage: BattleDamage?
        ) {
            guard isCurrentSession else { return }
            // O som final e disparado por GameARState.animateBattleTurn.
            // Aqui mantemos somente as animacoes visuais dos personagens.

            guard
                let player =
                    currentCharacterEntity,
                let enemy =
                    currentEnemyEntity
            else {
                return
            }

            let playerDuration =
                playCharacterAnimation(
                    animationKind(
                        for: playerMove
                    ),
                    on: player
                ) ?? 0

            let enemyDuration =
                playCharacterAnimation(
                    animationKind(
                        for: enemyMove
                    ),
                    on: enemy
                ) ?? 0

            let reactionDelay =
                max(
                    max(
                        playerDuration,
                        enemyDuration
                    ),
                    0.35
                ) + 0.05

            let audioGeneration = battleAudioGeneration

            DispatchQueue.main
                .asyncAfter(
                    deadline:
                        .now()
                        + reactionDelay
                ) {
                    [weak self,
                     weak player,
                     weak enemy] in

                    guard
                        let self,
                        let player,
                        let enemy,
                        self.isCurrentSession,
                        self.battleAudioGeneration == audioGeneration,
                        self.currentCharacterEntity === player,
                        self.currentEnemyEntity === enemy
                    else {
                        return
                    }

                    // The hit number appears with the reaction, NOT when
                    // BattleEngine changes HP. Finishing blows synchronize
                    // with the defeat animation instead of Hit.
                    if let damage, damage.amount > 0 {
                        let victim = damage.target == .player ? player : enemy
                        self.beginProjectedDamage(amount: damage.amount, on: victim)
                    }

                    switch result {

                    case .draw:
                        break

                    case .playerWin:

                        if winner ==
                            .player {

                            self.playCharacterAnimation(
                                .victory,
                                on: player
                            )

                            self.playCharacterAnimation(
                                .defeat,
                                on: enemy
                            )

                        } else {

                            self.playCharacterAnimation(
                                .hit,
                                on: enemy
                            )
                        }

                    case .enemyWin:

                        if winner ==
                            .enemy {

                            self.playCharacterAnimation(
                                .defeat,
                                on: player
                            )

                            self.playCharacterAnimation(
                                .victory,
                                on: enemy
                            )

                        } else {

                            self.playCharacterAnimation(
                                .hit,
                                on: player
                            )
                        }
                    }

                }
        }

        /// Track the victim's visual bounds while the camera moves. This is
        /// only active for the ~0.9-second lifetime of a damage number.
        /// Uses a lightweight projection every 50 ms (not a per-frame HUD loop).
        private func beginProjectedDamage(amount: Int, on victim: Entity) {
            guard isCurrentSession, arView != nil, amount > 0 else { return }
            floatingDamageGeneration += 1
            let generation = floatingDamageGeneration
            let eventID = UUID()
            let bounds = victim.visualBounds(relativeTo: victim)
            let height = max(bounds.max.y - bounds.min.y, 0.01)
            let localPoint = SIMD3<Float>(
                (bounds.min.x + bounds.max.x) * 0.5,
                bounds.max.y + max(height * 0.15, 0.035),
                (bounds.min.z + bounds.max.z) * 0.5
            )

            let started = CACurrentMediaTime()
            state.showFloatingDamage(id: eventID, amount: amount, at: nil)

            refreshProjectedDamage(
                victim: victim, localPoint: localPoint,
                started: started, generation: generation, eventID: eventID
            )
        }

        private func refreshProjectedDamage(
            victim: Entity, localPoint: SIMD3<Float>, started: TimeInterval,
            generation: Int, eventID: UUID
        ) {
            guard isCurrentSession,
                  floatingDamageGeneration == generation,
                  currentCharacterEntity === victim || currentEnemyEntity === victim,
                  let arView else { return }

            guard CACurrentMediaTime() - started < 0.95 else {
                state.clearFloatingDamage(id: eventID)
                return
            }
            let world = victim.convert(position: localPoint, to: nil)
            let point = arView.project(world)
            let visible = point.flatMap { p -> CGPoint? in
                guard p.x.isFinite, p.y.isFinite,
                      p.x >= 0, p.y >= 0,
                      p.x <= arView.bounds.width,
                      p.y <= arView.bounds.height else { return nil }
                return p
            }
            state.updateFloatingDamagePosition(visible, id: eventID)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self, weak victim] in
                guard let self, let victim else { return }
                self.refreshProjectedDamage(
                    victim: victim, localPoint: localPoint,
                    started: started, generation: generation, eventID: eventID
                )
            }
        }

        @discardableResult
        private func playCharacterAnimation(
            _ requestedKind:
                CharacterAnimationKind,
            on character: Entity
        ) -> TimeInterval? {

            let key =
                ObjectIdentifier(
                    character
                )

            guard
                let animatedModel =
                    characterAnimatedModels[
                        key
                    ],
                let animations =
                    characterAnimations[
                        key
                    ],
                let resolvedKind =
                    resolvedAnimationKind(
                        requested:
                            requestedKind,
                        available:
                            animations
                    ),
                let animation =
                    animations[
                        resolvedKind
                    ]
            else {

                print(
                    "⚠️ Personagem sem animação disponível para:",
                    requestedKind
                )

                return nil
            }

            animationGeneration[
                key,
                default: 0
            ] += 1

            let generation =
                animationGeneration[
                    key
                ] ?? 0

            animatedModel
                .stopAllAnimations(
                    recursive: true
                )

            if resolvedKind ==
                .idle {

                animatedModel
                    .playAnimation(
                        animation.repeat(),
                        transitionDuration:
                            0.12,
                        startsPaused:
                            false
                    )

                return nil
            }

            let controller =
                animatedModel
                    .playAnimation(
                        animation,
                        transitionDuration:
                            0.12,
                        startsPaused:
                            false
                    )

            let duration =
                controller.duration

            if requestedKind ==
                    .defeat
                || requestedKind ==
                    .victory {

                return duration
            }

            DispatchQueue.main
                .asyncAfter(
                    deadline:
                        .now()
                        + duration
                ) {
                    [weak self,
                     weak character] in

                    guard
                        let self,
                        let character,
                        self.animationGeneration[
                            key
                        ] == generation
                    else {
                        return
                    }

                    self.playCharacterAnimation(
                        .idle,
                        on: character
                    )
                }

            return duration
        }

        private func clearAnimationState(
            for character: Entity?
        ) {

            guard let character else {
                return
            }

            let key =
                ObjectIdentifier(
                    character
                )

            characterAnimatedModels
                .removeValue(
                    forKey: key
                )

            characterAnimations
                .removeValue(
                    forKey: key
                )

            animationGeneration
                .removeValue(
                    forKey: key
                )
        }



        @MainActor
        private func makeCharacter(

            _ card: CardDefinition

        ) async -> Entity? {

            #if DEBUG
            let characterStartedAt = CACurrentMediaTime()
            defer {
                logLoadingDuration(
                    "makeCharacter \(card.referenceImageName) model ready (animations pending)",
                    startedAt: characterStartedAt
                )
            }
            let modelStartedAt = CACurrentMediaTime()
            #endif
            // Cancela o resultado se o jogador iniciou outra sessão.
            let expectedLoadGeneration = assetLoadGeneration
            guard isCurrentSession else { return nil }

            do {

                let importedModel =

                    try await Entity(

                        named: realityAssetBaseName(card.modelName)

                    )

                #if DEBUG
                logLoadingDuration(
                    "model \(card.modelName)",
                    startedAt: modelStartedAt
                )
                #endif

                guard isCurrentSession,
                      assetLoadGeneration == expectedLoadGeneration else {
                    return nil
                }

                let root = Entity()

                importedModel.position = .zero
                importedModel.scale = SIMD3<Float>(repeating: 1)

                root.addChild(importedModel)

                let bounds = importedModel.visualBounds(
                    recursive: true,
                    relativeTo: root
                )

                let height = bounds.extents.y

                guard height > 0.001 else {
                    return nil
                }

                let scale = card.modelHeight / height

                importedModel.scale = SIMD3<Float>(
                    repeating: scale
                )

                let scaledBounds = importedModel.visualBounds(
                    recursive: true,
                    relativeTo: root
                )

                importedModel.position += SIMD3<Float>(
                    -scaledBounds.center.x,
                    -scaledBounds.min.y,
                    -scaledBounds.center.z
                )
                
                // TESTE: deslocamento vertical exclusivo do Goku
                if card.referenceImageName == "goku_cardgame" {
                    importedModel.position.y -= 0.30
                }

                // A animação Idle já vem dentro de *_Idle.usdz. Inicie-a
                // imediatamente para não esperar as outras seis animações
                // antes de revelar o personagem na RA.
                let key = ObjectIdentifier(root)
                characterAnimatedModels[key] = importedModel
                var initialAnimations: [CharacterAnimationKind: AnimationResource] = [:]
                if let idle = importedModel.availableAnimations.first {
                    initialAnimations[.idle] = idle
                }
                characterAnimations[key] = initialAnimations
                if initialAnimations[.idle] != nil {
                    playCharacterAnimation(.idle, on: root)
                }

                // Carrega as outras animações durante os próprios efeitos
                // de invocação. A conclusão só atualiza uma sessão ativa.
                Task { @MainActor [weak self, weak root] in
                    guard let self, let root,
                          self.isCurrentSession,
                          self.assetLoadGeneration == expectedLoadGeneration,
                          self.characterAnimatedModels[ObjectIdentifier(root)] === importedModel else {
                        return
                    }
                    await self.registerAnimations(
                        for: card,
                        character: root,
                        animatedModel: importedModel,
                        expectedLoadGeneration: expectedLoadGeneration
                    )
                }

                return root



            } catch {

                #if DEBUG
                logLoadingDuration(
                    "model \(card.modelName) FAILED",
                    startedAt: modelStartedAt
                )
                #endif

                print(

                    "❌ Erro carregando \(card.modelName):",

                    error

                )



                return nil

            }

        }

    }

}
