//
//  Atmosphere.swift
//  divedave iOS
//
//  Created by David Durkin on 11/7/24.
//

import SpriteKit

/// Configuration describing one parallax / spawn layer (clouds, stars, birds, planes, UFOs, ...).
struct AtmosphereLayer {
    enum Kind {
        /// Multi-frame `AnimatedSprite` whose texture is picked at random from `frames` each (re)spawn.
        case randomFrameSprite(spritesheet: String, frameWidth: CGFloat, frameHeight: CGFloat)
        /// `AnimatedSprite` that plays a named animation.
        case animatedSprite(spritesheet: String, frameWidth: CGFloat, frameHeight: CGFloat,
                            animationName: String, frameIndices: [Int], timePerFrame: TimeInterval)
        /// Plain static sprite from an image asset.
        case staticSprite(imageName: String)
    }

    /// Horizontal drift behaviour for entities in this layer.
    enum Motion {
        /// Stationary — no velocity, recycles only via parallax repositioning.
        case stationary
        /// Drifts at a positive velocity (left-to-right), wraps off the right edge.
        case driftRight(minSpeed: CGFloat, maxSpeed: CGFloat)
        /// Drifts at a negative velocity (right-to-left), wraps off the left edge.
        case driftLeft(minSpeed: CGFloat, maxSpeed: CGFloat)
    }

    let name: String
    let kind: Kind
    let motion: Motion
    /// How many entities to spawn per `segmentSize` slab.
    let countRange: ClosedRange<Int>
    /// Vertical span in scene-space.
    let yRange: ClosedRange<CGFloat>
    /// Segment height used to distribute entities along `yRange`.
    let segmentSize: CGFloat
    /// Horizontal padding outside the screen used during spawn.
    let xPadding: CGFloat
    let zPosition: CGFloat
    /// Random scale multiplier applied on top of `GameState.shared.metrics.scaleFactorHeight`.
    let scaleRange: ClosedRange<CGFloat>
    /// Random delay (sec) before the looping animation starts. Ignored for non-animated kinds.
    let animationStartDelayRange: ClosedRange<TimeInterval>
    /// If true, the entity's `zRotation` is randomized at spawn.
    let randomRotation: Bool
    /// Differential parallax weight. 0 = static relative to camera (deepest distance),
    /// 1 = full world-space (moves with camera). Each frame Atmosphere applies
    /// (1 - parallaxFactor) * cameraDelta as a counter-offset on entity Y, so far
    /// layers appear to lag behind near ones.
    let parallaxFactor: CGFloat
    /// Hard cap on total entities ever alive in this layer. Procedural extension stops
    /// adding once this is reached and instead recycles low-Y entities upward.
    let maxCount: Int
    /// If true, the procedural-extension pass continues spawning/repositioning entities
    /// above the camera as it climbs (used for space-zone layers like stars/UFOs).
    /// False for layers that should stay inside their natural band (clouds in blue sky,
    /// birds in blue sky, planes in twilight).
    let extendsUpward: Bool
}

/// Per-entity bookkeeping for the generic recycle pass.
private final class AtmosphereEntity {
    let node: SKNode
    let layerIndex: Int
    let halfWidth: CGFloat
    /// World-space anchor. The entity's visible Y each frame is
    /// `anchorY + cameraDelta * (1 - parallaxFactor)`, clamped to the layer's yRange.
    /// Recycling (horizontal wrap, procedural extension) updates this.
    var anchorY: CGFloat

    init(node: SKNode, layerIndex: Int, halfWidth: CGFloat, anchorY: CGFloat) {
        self.node = node
        self.layerIndex = layerIndex
        self.halfWidth = halfWidth
        self.anchorY = anchorY
    }
}

@MainActor
final class Atmosphere {
    private let scene: SKScene
    private let sceneHeight: CGFloat
    private let startY: CGFloat
    private let middleY: CGFloat
    private let endY: CGFloat

    private var layers: [AtmosphereLayer] = []
    private var entitiesByLayer: [[AtmosphereEntity]] = []

    /// Camera Y at the moment update() first runs. All parallax offsets are
    /// computed relative to this anchor so the effect never accumulates.
    private var referenceCameraY: CGFloat?
    /// Highest Y already populated per layer. Procedural extension extends this upward.
    private var spawnedCeilingByLayer: [CGFloat] = []

    init(scene: SKScene, sceneHeight: CGFloat, startY: CGFloat, middleY: CGFloat, endY: CGFloat) {
        self.scene = scene
        self.sceneHeight = sceneHeight
        self.middleY = middleY
        self.endY = endY
        self.startY = startY

        self.layers = Atmosphere.defaultLayers(sceneHeight: sceneHeight, middleY: middleY, endY: endY)
        self.entitiesByLayer = Array(repeating: [], count: layers.count)
        self.spawnedCeilingByLayer = layers.map { $0.yRange.upperBound }

        for (idx, layer) in layers.enumerated() {
            spawn(layer: layer, layerIndex: idx)
        }
    }

    // MARK: - Layer config

    private static func defaultLayers(sceneHeight: CGFloat, middleY: CGFloat, endY: CGFloat) -> [AtmosphereLayer] {
        let segment = 1000 * GameState.shared.metrics.scaleFactorHeight
        // Vertical bands match the original stride semantics:
        //   clouds/stars stride: from (segment + 500*scale) to (sceneHeight + segment), step segment
        //     -> y slabs ⊂ [500*scale, sceneHeight + segment]
        //   birds/planes/ufos stride: from segment to (sceneHeight - 500*scale), step segment
        //     -> y slabs ⊂ [0, sceneHeight - 500*scale]
        let cloudBandStart: CGFloat = 500 * GameState.shared.metrics.scaleFactorHeight
        let cloudBandEnd: CGFloat = sceneHeight + segment
        let birdBandStart: CGFloat = 0
        let birdBandEnd: CGFloat = sceneHeight - 500 * GameState.shared.metrics.scaleFactorHeight

        // Each (lower, upper) pair below comes from `max/min` clamps against
        // middleY/endY/the band bounds. For short scenes (low platform), some
        // pairs can invert (lower >= upper) which would crash ClosedRange.
        // Skip any layer whose computed yRange is empty.
        var layers: [AtmosphereLayer] = []
        func add(_ lower: CGFloat, _ upper: CGFloat, _ build: (ClosedRange<CGFloat>) -> AtmosphereLayer) {
            guard lower < upper else { return }
            layers.append(build(lower...upper))
        }

        // Stars (above endY). Stationary, twinkle animation. Spawned per cloud slab,
        // doubled to mimic the original `starMult=1` inner loop (0...starMult iterates twice).
        add(max(endY, cloudBandStart), cloudBandEnd) { range in
            AtmosphereLayer(
                name: "stars",
                kind: .animatedSprite(spritesheet: "star-spritesheet",
                                      frameWidth: 128, frameHeight: 128,
                                      animationName: "sparkle",
                                      frameIndices: [0, 0, 0, 0, 0, 1, 2, 3],
                                      timePerFrame: 0.25),
                motion: .stationary,
                countRange: (Game.minClouds * 2)...(Game.maxClouds * 2),
                yRange: range,
                segmentSize: segment,
                xPadding: 0,
                zPosition: 1,
                scaleRange: 1.0...1.0,
                animationStartDelayRange: 0.0...0.75,
                randomRotation: true,
                parallaxFactor: 0.3,
                maxCount: 600,
                extendsUpward: true
            )
        }

        // Clouds (below middleY). Random frame, drifts right.
        add(cloudBandStart, min(middleY, cloudBandEnd)) { range in
            AtmosphereLayer(
                name: "clouds",
                kind: .randomFrameSprite(spritesheet: "clouds", frameWidth: 256, frameHeight: 256),
                motion: .driftRight(minSpeed: Game.cloudMinSpeed, maxSpeed: Game.cloudMaxSpeed),
                countRange: Game.minClouds...Game.maxClouds,
                yRange: range,
                segmentSize: segment,
                xPadding: 256 * GameState.shared.metrics.scaleFactorHeight,
                zPosition: 0,
                scaleRange: 0.75...1.5,
                animationStartDelayRange: 0.0...0.0,
                randomRotation: false,
                parallaxFactor: 0.6,
                maxCount: 200,
                extendsUpward: false
            )
        }

        // Birds (below middleY). Drift left.
        add(birdBandStart, min(middleY, birdBandEnd)) { range in
            AtmosphereLayer(
                name: "birds",
                kind: .animatedSprite(spritesheet: "bird",
                                      frameWidth: 128, frameHeight: 128,
                                      animationName: "fly",
                                      frameIndices: [0, 0, 0, 0, 1, 2, 3, 4, 3, 2, 1],
                                      timePerFrame: 0.83),
                motion: .driftLeft(minSpeed: Game.birdMinSpeed, maxSpeed: Game.birdMaxSpeed),
                countRange: Game.minBirds...Game.maxBirds,
                yRange: range,
                segmentSize: segment,
                xPadding: 128 * GameState.shared.metrics.scaleFactorHeight,
                zPosition: 0,
                scaleRange: 1.0...1.0,
                animationStartDelayRange: 0.0...0.75,
                randomRotation: false,
                parallaxFactor: 0.8,
                maxCount: 80,
                extendsUpward: false
            )
        }

        // Planes (middleY..endY). Drift left.
        add(max(middleY, birdBandStart), min(endY, birdBandEnd)) { range in
            AtmosphereLayer(
                name: "planes",
                kind: .staticSprite(imageName: "plane"),
                motion: .driftLeft(minSpeed: Game.birdMinSpeed, maxSpeed: Game.birdMaxSpeed),
                countRange: Game.minBirds...Game.maxBirds,
                yRange: range,
                segmentSize: segment,
                xPadding: 128 * GameState.shared.metrics.scaleFactorHeight,
                zPosition: 1,
                scaleRange: 1.0...1.0,
                animationStartDelayRange: 0.0...0.0,
                randomRotation: false,
                parallaxFactor: 0.8,
                maxCount: 80,
                extendsUpward: false
            )
        }

        // UFOs (above endY). Drift left.
        add(max(endY, birdBandStart), cloudBandEnd) { range in
            AtmosphereLayer(
                name: "ufos",
                kind: .staticSprite(imageName: "ufo"),
                motion: .driftLeft(minSpeed: Game.birdMinSpeed, maxSpeed: Game.birdMaxSpeed),
                countRange: Game.minBirds...Game.maxBirds,
                yRange: range,
                segmentSize: segment,
                xPadding: 128 * GameState.shared.metrics.scaleFactorHeight,
                zPosition: 2,
                scaleRange: 1.0...1.0,
                animationStartDelayRange: 0.0...0.0,
                randomRotation: false,
                parallaxFactor: 1.0,
                maxCount: 80,
                extendsUpward: true
            )
        }

        return layers
    }

    // MARK: - Spawning

    /// Generic spawn entry. Distributes `count` entities per `segmentSize` slab across `layer.yRange`.
    private func spawn(layer: AtmosphereLayer, layerIndex: Int) {
        let yRange = layer.yRange
        guard yRange.lowerBound < yRange.upperBound, layer.segmentSize > 0 else { return }

        let first = yRange.lowerBound + layer.segmentSize
        let last = yRange.upperBound + layer.segmentSize
        guard first <= last else { return }

        for segment in stride(from: first, to: last, by: layer.segmentSize) {
            let count = Int.random(in: layer.countRange)
            let yMin = max(yRange.lowerBound, segment - layer.segmentSize)
            let yMax = min(yRange.upperBound, segment)
            guard yMin < yMax else { continue }

            for _ in 0..<count {
                if entitiesByLayer[layerIndex].count >= layer.maxCount { return }
                let yPos = CGFloat.random(in: yMin...yMax)
                spawnEntity(in: layer, layerIndex: layerIndex, atY: yPos)
            }
        }
    }

    /// Spawn a single entity at the given Y. Shared by initial spawn and (later) procedural extension.
    private func spawnEntity(in layer: AtmosphereLayer, layerIndex: Int, atY yPos: CGFloat) {
        let xLow = -layer.xPadding
        let xHigh = GameState.shared.metrics.width + layer.xPadding
        let xPos = CGFloat.random(in: xLow...xHigh)

        let node: SKSpriteNode
        switch layer.kind {
        case let .randomFrameSprite(sheet, fw, fh):
            let scale = GameState.shared.metrics.scaleFactorHeight * CGFloat.random(in: layer.scaleRange)
            let s = AnimatedSprite(spritesheetName: sheet, frameWidth: fw, frameHeight: fh, scale: scale)
            s.texture = s.frames.randomElement()
            attachDriftPhysics(to: s, motion: layer.motion)
            node = s

        case let .animatedSprite(sheet, fw, fh, animName, frameIndices, tpf):
            let scale = GameState.shared.metrics.scaleFactorHeight * CGFloat.random(in: layer.scaleRange)
            let s = AnimatedSprite(spritesheetName: sheet, frameWidth: fw, frameHeight: fh, scale: scale)
            s.defineAnimation(name: animName, frameIndices: frameIndices, timePerFrame: tpf)
            let delay = Double.random(in: layer.animationStartDelayRange)
            if delay > 0 {
                s.run(SKAction.wait(forDuration: delay)) {
                    s.playAnimation(name: animName, timePerFrame: tpf, repeatForever: true)
                }
            } else {
                s.playAnimation(name: animName, timePerFrame: tpf, repeatForever: true)
            }
            attachDriftPhysics(to: s, motion: layer.motion)
            node = s

        case let .staticSprite(imageName):
            let s = SKSpriteNode(imageNamed: imageName)
            s.setScale(GameState.shared.metrics.scaleFactorHeight * CGFloat.random(in: layer.scaleRange))
            attachDriftPhysics(to: s, motion: layer.motion)
            node = s
        }

        node.position = CGPoint(x: xPos, y: yPos)
        node.zPosition = layer.zPosition
        if layer.randomRotation {
            node.zRotation = CGFloat.random(in: 0...(2 * .pi))
        }

        scene.addChild(node)
        entitiesByLayer[layerIndex].append(
            AtmosphereEntity(node: node, layerIndex: layerIndex, halfWidth: node.size.width / 2, anchorY: yPos)
        )
    }

    private func attachDriftPhysics(to node: SKSpriteNode, motion: AtmosphereLayer.Motion) {
        switch motion {
        case .stationary:
            return
        case let .driftRight(minSpeed, maxSpeed):
            let body = SKPhysicsBody(rectangleOf: node.size)
            body.affectedByGravity = false
            body.linearDamping = 0.0
            body.velocity = CGVector(dx: CGFloat.random(in: minSpeed...maxSpeed), dy: 0)
            body.collisionBitMask = 0
            body.categoryBitMask = 0
            node.physicsBody = body
        case let .driftLeft(minSpeed, maxSpeed):
            let body = SKPhysicsBody(rectangleOf: node.size)
            body.affectedByGravity = false
            body.linearDamping = 0.0
            body.velocity = CGVector(dx: -CGFloat.random(in: minSpeed...maxSpeed), dy: 0)
            body.collisionBitMask = 0
            body.categoryBitMask = 0
            node.physicsBody = body
        }
    }

    // MARK: - Update / recycle

    func update() {
        let cameraY = scene.camera?.position.y ?? referenceCameraY ?? 0
        if referenceCameraY == nil {
            referenceCameraY = cameraY
        }
        let cameraDelta = cameraY - referenceCameraY!

        for (layerIndex, layer) in layers.enumerated() {
            // Anchored parallax: each entity's visible Y is anchor + cameraDelta * tracking,
            // then WRAPPED modulo the layer's band height. Wrapping (instead of clamping)
            // keeps entities evenly distributed during long dives — no pile-up at the
            // band edge, and the layer reads as a continuous "river" of objects flowing
            // past the camera.
            let trackingFactor = 1.0 - layer.parallaxFactor
            let offset = cameraDelta * trackingFactor

            for entity in entitiesByLayer[layerIndex] {
                entity.node.position.y = Atmosphere.wrap(entity.anchorY + offset, in: layer.yRange)
                recycle(entity: entity, layer: layer, offset: offset)
            }

            // Procedural extension: as camera nears top of populated band, push the
            // ceiling upward by one segment so high-altitude layers keep populated.
            extendIfNeeded(layerIndex: layerIndex, layer: layer, cameraY: cameraY)
        }
    }

    /// Wrap `y` into `range` using modulo so values cycle through the band rather
    /// than pile up at its edges. Returns `range.lowerBound` if the band has zero height.
    private static func wrap(_ y: CGFloat, in range: ClosedRange<CGFloat>) -> CGFloat {
        let height = range.upperBound - range.lowerBound
        guard height > 0 else { return range.lowerBound }
        let raw = y - range.lowerBound
        let r = raw.truncatingRemainder(dividingBy: height)
        return range.lowerBound + (r < 0 ? r + height : r)
    }

    /// When camera approaches `spawnedCeilingByLayer[i]`, spawn (or recycle) a new
    /// segment-sized batch above it. Hard cap honoured per `layer.maxCount`.
    private func extendIfNeeded(layerIndex: Int, layer: AtmosphereLayer, cameraY: CGFloat) {
        guard layer.extendsUpward else { return }
        let ceiling = spawnedCeilingByLayer[layerIndex]
        // Trigger when camera is within ~1.5 screen heights of the ceiling.
        guard cameraY + GameState.shared.metrics.height * 1.5 >= ceiling else { return }

        let newSlabBottom = ceiling
        let newSlabTop = ceiling + layer.segmentSize
        let count = Int.random(in: layer.countRange)

        if entitiesByLayer[layerIndex].count < layer.maxCount {
            // Headroom: spawn a fresh batch above the existing ceiling.
            for _ in 0..<count {
                if entitiesByLayer[layerIndex].count >= layer.maxCount { break }
                let yPos = CGFloat.random(in: newSlabBottom...newSlabTop)
                spawnEntity(in: layer, layerIndex: layerIndex, atY: yPos)
            }
        } else {
            // Cap reached: recycle the lowest entities upward into the new slab.
            let sortedByY = entitiesByLayer[layerIndex].sorted { $0.node.position.y < $1.node.position.y }
            let toRecycle = min(count, sortedByY.count)
            var recycled = 0
            for entity in sortedByY {
                if recycled >= toRecycle { break }
                if entity.node.position.y >= newSlabBottom { break } // already high enough
                let yPos = CGFloat.random(in: newSlabBottom...newSlabTop)
                let xLow = -layer.xPadding
                let xHigh = GameState.shared.metrics.width + layer.xPadding
                entity.anchorY = yPos
                entity.node.position = CGPoint(x: CGFloat.random(in: xLow...xHigh), y: yPos)
                recycled += 1
            }
        }

        spawnedCeilingByLayer[layerIndex] = newSlabTop
    }

    /// Wrap entity horizontally based on its layer motion, or do nothing for stationary layers.
    /// `offset` is the current parallax offset for this layer; we use it to place the recycled
    /// entity so it appears in the right visual spot immediately rather than snapping next frame.
    private func recycle(entity: AtmosphereEntity, layer: AtmosphereLayer, offset: CGFloat) {
        let node = entity.node

        switch layer.motion {
        case .stationary:
            return
        case let .driftRight(minSpeed, maxSpeed):
            guard node.position.x >= GameState.shared.metrics.width + entity.halfWidth else { return }
            let newAnchor = CGFloat.random(in: layer.yRange)
            entity.anchorY = newAnchor
            let visibleY = Atmosphere.wrap(newAnchor + offset, in: layer.yRange)
            node.position = CGPoint(x: -entity.halfWidth * 4, y: visibleY)
            node.physicsBody?.velocity = CGVector(dx: CGFloat.random(in: minSpeed...maxSpeed), dy: 0)
            if let sprite = node as? AnimatedSprite {
                sprite.texture = sprite.frames.randomElement()
            }
        case let .driftLeft(minSpeed, maxSpeed):
            guard node.position.x + entity.halfWidth < 0 else { return }
            let newAnchor = CGFloat.random(in: layer.yRange)
            entity.anchorY = newAnchor
            let visibleY = Atmosphere.wrap(newAnchor + offset, in: layer.yRange)
            node.position = CGPoint(x: GameState.shared.metrics.width + entity.halfWidth * 4, y: visibleY)
            node.physicsBody?.velocity = CGVector(dx: -CGFloat.random(in: minSpeed...maxSpeed), dy: 0)
        }
    }

    func updateBackgroundColor(for cameraY: CGFloat) {
        // Determine the current color based on camera y position
        let color: SKColor
        if cameraY <= startY {
            color = startColor
        } else if cameraY <= middleY {
            // Interpolate between startColor and middleColor
            let t = (cameraY - startY) / (middleY - startY)
            color = Atmosphere.interpolateColor(from: startColor, to: middleColor, fraction: t)
        } else if cameraY <= endY {
            // Interpolate between middleColor and endColor
            let t = (cameraY - middleY) / (endY - middleY)
            color = Atmosphere.interpolateColor(from: middleColor, to: endColor, fraction: t)
        } else {
            color = endColor
        }

        // Set the background color
        self.scene.backgroundColor = color
    }

    /// SIMD-based linear color interpolation. Replaces the previous version which
    /// allocated 8 CGFloat outparams per call. Static — no instance state used.
    static func interpolateColor(from color1: SKColor, to color2: SKColor, fraction: CGFloat) -> SKColor {
        let t = Float(max(0, min(1, fraction)))
        let a = simdComponents(color1)
        let b = simdComponents(color2)
        let mixed = a + (b - a) * SIMD4<Float>(repeating: t)
        return SKColor(red: CGFloat(mixed.x),
                       green: CGFloat(mixed.y),
                       blue: CGFloat(mixed.z),
                       alpha: CGFloat(mixed.w))
    }

    /// Extract RGBA components into a SIMD4<Float>. Hot path — kept tiny.
    private static func simdComponents(_ color: SKColor) -> SIMD4<Float> {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD4<Float>(Float(r), Float(g), Float(b), Float(a))
    }
}
