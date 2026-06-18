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
    /// Random scale multiplier applied on top of `scaleFactorHeight`.
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
}

/// Per-entity bookkeeping for the generic recycle pass.
private final class AtmosphereEntity {
    let node: SKNode
    let layerIndex: Int
    let halfWidth: CGFloat

    init(node: SKNode, layerIndex: Int, halfWidth: CGFloat) {
        self.node = node
        self.layerIndex = layerIndex
        self.halfWidth = halfWidth
    }
}

class Atmosphere {
    private let scene: SKScene
    private let sceneHeight: CGFloat
    private let startY: CGFloat
    private let middleY: CGFloat
    private let endY: CGFloat

    private var layers: [AtmosphereLayer] = []
    private var entitiesByLayer: [[AtmosphereEntity]] = []

    /// Last observed camera Y; used to compute frame-over-frame deltas for parallax.
    /// Initialised lazily on the first update() so the first frame doesn't snap.
    private var lastCameraY: CGFloat?
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
        let segment = 1000 * scaleFactorHeight
        // Vertical bands match the original stride semantics:
        //   clouds/stars stride: from (segment + 500*scale) to (sceneHeight + segment), step segment
        //     -> y slabs ⊂ [500*scale, sceneHeight + segment]
        //   birds/planes/ufos stride: from segment to (sceneHeight - 500*scale), step segment
        //     -> y slabs ⊂ [0, sceneHeight - 500*scale]
        let cloudBandStart: CGFloat = 500 * scaleFactorHeight
        let cloudBandEnd: CGFloat = sceneHeight + segment
        let birdBandStart: CGFloat = 0
        let birdBandEnd: CGFloat = sceneHeight - 500 * scaleFactorHeight

        return [
            // Stars (above endY). Stationary, twinkle animation. Spawned per cloud slab,
            // doubled to mimic the original `starMult=1` inner loop (0...starMult iterates twice).
            AtmosphereLayer(
                name: "stars",
                kind: .animatedSprite(spritesheet: "star-spritesheet",
                                      frameWidth: 128, frameHeight: 128,
                                      animationName: "sparkle",
                                      frameIndices: [0, 0, 0, 0, 0, 1, 2, 3],
                                      timePerFrame: 0.25),
                motion: .stationary,
                countRange: (MIN_CLOUDS * 2)...(MAX_CLOUDS * 2),
                yRange: max(endY, cloudBandStart)...cloudBandEnd,
                segmentSize: segment,
                xPadding: 0,
                zPosition: 1,
                scaleRange: 1.0...1.0,
                animationStartDelayRange: 0.0...0.75,
                randomRotation: true,
                parallaxFactor: 0.15,
                maxCount: 600
            ),
            // Clouds (below middleY). Random frame, drifts right.
            AtmosphereLayer(
                name: "clouds",
                kind: .randomFrameSprite(spritesheet: "clouds", frameWidth: 256, frameHeight: 256),
                motion: .driftRight(minSpeed: CLOUD_MIN_SPEED, maxSpeed: CLOUD_MAX_SPEED),
                countRange: MIN_CLOUDS...MAX_CLOUDS,
                yRange: cloudBandStart...min(middleY, cloudBandEnd),
                segmentSize: segment,
                xPadding: 256 * scaleFactorHeight,
                zPosition: 0,
                scaleRange: 1.0...2.0,
                animationStartDelayRange: 0.0...0.0,
                randomRotation: false,
                parallaxFactor: 0.5,
                maxCount: 200
            ),
            // Birds (below middleY). Drift left.
            AtmosphereLayer(
                name: "birds",
                kind: .animatedSprite(spritesheet: "bird",
                                      frameWidth: 128, frameHeight: 128,
                                      animationName: "fly",
                                      frameIndices: [0, 0, 0, 0, 1, 2, 3, 4, 3, 2, 1],
                                      timePerFrame: 0.83),
                motion: .driftLeft(minSpeed: BIRD_MIN_SPEED, maxSpeed: BIRD_MAX_SPEED),
                countRange: MIN_BIRDS...MAX_BIRDS,
                yRange: birdBandStart...min(middleY, birdBandEnd),
                segmentSize: segment,
                xPadding: 128 * scaleFactorHeight,
                zPosition: 0,
                scaleRange: 1.0...1.0,
                animationStartDelayRange: 0.0...0.75,
                randomRotation: false,
                parallaxFactor: 0.8,
                maxCount: 80
            ),
            // Planes (middleY..endY). Drift left.
            AtmosphereLayer(
                name: "planes",
                kind: .staticSprite(imageName: "plane"),
                motion: .driftLeft(minSpeed: BIRD_MIN_SPEED, maxSpeed: BIRD_MAX_SPEED),
                countRange: MIN_BIRDS...MAX_BIRDS,
                yRange: max(middleY, birdBandStart)...min(endY, birdBandEnd),
                segmentSize: segment,
                xPadding: 128 * scaleFactorHeight,
                zPosition: 1,
                scaleRange: 1.0...1.0,
                animationStartDelayRange: 0.0...0.0,
                randomRotation: false,
                parallaxFactor: 0.8,
                maxCount: 80
            ),
            // UFOs (above endY). Drift left.
            AtmosphereLayer(
                name: "ufos",
                kind: .staticSprite(imageName: "ufo"),
                motion: .driftLeft(minSpeed: BIRD_MIN_SPEED, maxSpeed: BIRD_MAX_SPEED),
                countRange: MIN_BIRDS...MAX_BIRDS,
                yRange: max(endY, birdBandStart)...cloudBandEnd,
                segmentSize: segment,
                xPadding: 128 * scaleFactorHeight,
                zPosition: 2,
                scaleRange: 1.0...1.0,
                animationStartDelayRange: 0.0...0.0,
                randomRotation: false,
                parallaxFactor: 1.0,
                maxCount: 80
            )
        ]
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
        let xHigh = WIDTH + layer.xPadding
        let xPos = CGFloat.random(in: xLow...xHigh)

        let node: SKSpriteNode
        switch layer.kind {
        case let .randomFrameSprite(sheet, fw, fh):
            let scale = scaleFactorHeight * CGFloat.random(in: layer.scaleRange)
            let s = AnimatedSprite(spritesheetName: sheet, frameWidth: fw, frameHeight: fh, scale: scale)
            s.texture = s.frames.randomElement()
            attachDriftPhysics(to: s, motion: layer.motion)
            node = s

        case let .animatedSprite(sheet, fw, fh, animName, frameIndices, tpf):
            let scale = scaleFactorHeight * CGFloat.random(in: layer.scaleRange)
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
            s.setScale(scaleFactorHeight * CGFloat.random(in: layer.scaleRange))
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
            AtmosphereEntity(node: node, layerIndex: layerIndex, halfWidth: node.size.width / 2)
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
        // Compute parallax delta. On first frame we have no previous camera Y; treat delta as 0.
        let cameraY = scene.camera?.position.y ?? lastCameraY ?? 0
        let cameraDelta = (lastCameraY.map { cameraY - $0 }) ?? 0
        lastCameraY = cameraY

        for (layerIndex, layer) in layers.enumerated() {
            // Layers with parallaxFactor < 1 lag behind world motion. Counter-offset Y by
            // (1 - parallaxFactor) * cameraDelta so the sprite "drifts" with the camera.
            let parallaxOffset = (1.0 - layer.parallaxFactor) * cameraDelta
            for entity in entitiesByLayer[layerIndex] {
                if parallaxOffset != 0 {
                    entity.node.position.y += parallaxOffset
                }
                recycle(entity: entity, layer: layer)
            }

            // Procedural extension: as camera nears top of populated band, push the
            // ceiling upward by one segment so high-altitude layers keep populated.
            extendIfNeeded(layerIndex: layerIndex, layer: layer, cameraY: cameraY)
        }
    }

    /// When camera approaches `spawnedCeilingByLayer[i]`, spawn (or recycle) a new
    /// segment-sized batch above it. Hard cap honoured per `layer.maxCount`.
    private func extendIfNeeded(layerIndex: Int, layer: AtmosphereLayer, cameraY: CGFloat) {
        let ceiling = spawnedCeilingByLayer[layerIndex]
        // Trigger when camera is within ~1.5 screen heights of the ceiling.
        guard cameraY + HEIGHT * 1.5 >= ceiling else { return }

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
                let xHigh = WIDTH + layer.xPadding
                entity.node.position = CGPoint(x: CGFloat.random(in: xLow...xHigh), y: yPos)
                recycled += 1
            }
        }

        spawnedCeilingByLayer[layerIndex] = newSlabTop
    }

    /// Wrap entity horizontally based on its layer motion, or do nothing for stationary layers.
    private func recycle(entity: AtmosphereEntity, layer: AtmosphereLayer) {
        let node = entity.node
        switch layer.motion {
        case .stationary:
            return
        case let .driftRight(minSpeed, maxSpeed):
            guard node.position.x >= WIDTH + entity.halfWidth else { return }
            let yMin = layer.yRange.lowerBound
            let yMax = min(layer.yRange.upperBound, middleY)
            let yPos = CGFloat.random(in: yMin...max(yMin, yMax))
            node.position = CGPoint(x: -entity.halfWidth * 4, y: yPos)
            node.physicsBody?.velocity = CGVector(dx: CGFloat.random(in: minSpeed...maxSpeed), dy: 0)
            if let sprite = node as? AnimatedSprite {
                sprite.texture = sprite.frames.randomElement()
            }
        case let .driftLeft(minSpeed, maxSpeed):
            guard node.position.x + entity.halfWidth < 0 else { return }
            let yMin = layer.yRange.lowerBound
            let yMax = layer.yRange.upperBound
            let yPos = CGFloat.random(in: yMin...max(yMin, yMax))
            node.position = CGPoint(x: WIDTH + entity.halfWidth * 4, y: yPos)
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
