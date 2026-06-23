import SpriteKit

struct AtmosphereLayer {
    enum Kind {
        case randomFrameSprite(spritesheet: String, frameWidth: CGFloat, frameHeight: CGFloat)
        case animatedSprite(spritesheet: String, frameWidth: CGFloat, frameHeight: CGFloat,
                            animationName: String, frameIndices: [Int], timePerFrame: TimeInterval)
        case staticSprite(imageName: String)
    }

    enum Motion {
        case stationary
        case driftRight(minSpeed: CGFloat, maxSpeed: CGFloat)
        case driftLeft(minSpeed: CGFloat, maxSpeed: CGFloat)
    }

    let name: String
    let kind: Kind
    let motion: Motion
    let countRange: ClosedRange<Int>
    let yRange: ClosedRange<CGFloat>
    let segmentSize: CGFloat
    let xPadding: CGFloat
    let zPosition: CGFloat
    let scaleRange: ClosedRange<CGFloat>
    let animationStartDelayRange: ClosedRange<TimeInterval>
    let randomRotation: Bool
    // 0 = static relative to camera (deepest distance), 1 = full world-space.
    let parallaxFactor: CGFloat
    let maxCount: Int
}

private final class AtmosphereEntity {
    let node: SKNode
    let layerIndex: Int
    let halfWidth: CGFloat
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
    private static let startColor = SKColor(red: 0.74, green: 0.84, blue: 1.0, alpha: 1.0)
    private static let middleColor = SKColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
    private static let endColor = SKColor.black

    private let scene: SKScene
    private let sceneHeight: CGFloat
    private let startY: CGFloat
    private let middleY: CGFloat
    private let endY: CGFloat

    private var layers: [AtmosphereLayer] = []
    private var entitiesByLayer: [[AtmosphereEntity]] = []

    private var referenceCameraY: CGFloat?

    init(scene: SKScene, sceneHeight: CGFloat, startY: CGFloat, middleY: CGFloat, endY: CGFloat) {
        self.scene = scene
        self.sceneHeight = sceneHeight
        self.middleY = middleY
        self.endY = endY
        self.startY = startY

        self.layers = Atmosphere.defaultLayers(sceneHeight: sceneHeight, middleY: middleY, endY: endY)
        self.entitiesByLayer = Array(repeating: [], count: layers.count)

        for (idx, layer) in layers.enumerated() {
            spawn(layer: layer, layerIndex: idx)
        }
    }

    private static func defaultLayers(sceneHeight: CGFloat, middleY: CGFloat, endY: CGFloat) -> [AtmosphereLayer] {
        let segment: CGFloat = 1000
        let cloudBandStart: CGFloat = 500
        let cloudBandEnd: CGFloat = sceneHeight + segment
        let birdBandStart: CGFloat = 0
        let birdBandEnd: CGFloat = sceneHeight - 500

        // Skip any layer whose computed yRange is empty — for short scenes some
        // (lower, upper) pairs invert, which would crash ClosedRange.
        var layers: [AtmosphereLayer] = []
        func add(_ lower: CGFloat, _ upper: CGFloat, _ build: (ClosedRange<CGFloat>) -> AtmosphereLayer) {
            guard lower < upper else { return }
            layers.append(build(lower...upper))
        }

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
                parallaxFactor: Game.starParallax,
                maxCount: 600
            )
        }

        add(cloudBandStart, min(middleY, cloudBandEnd)) { range in
            AtmosphereLayer(
                name: "clouds",
                kind: .randomFrameSprite(spritesheet: "clouds", frameWidth: 256, frameHeight: 256),
                motion: .driftRight(minSpeed: Game.cloudMinSpeed, maxSpeed: Game.cloudMaxSpeed),
                countRange: Game.minClouds...Game.maxClouds,
                yRange: range,
                segmentSize: segment,
                xPadding: 256,
                zPosition: 0,
                scaleRange: 0.75...1.5,
                animationStartDelayRange: 0.0...0.0,
                randomRotation: false,
                parallaxFactor: Game.cloudParallax,
                maxCount: 200
            )
        }

        add(birdBandStart, min(middleY, birdBandEnd)) { range in
            AtmosphereLayer(
                name: "birds",
                kind: .animatedSprite(spritesheet: "bird",
                                      frameWidth: 128, frameHeight: 128,
                                      animationName: "fly",
                                      frameIndices: [0, 0, 0, 0, 1, 2, 3, 4, 3, 2, 1],
                                      timePerFrame: 0.083),
                motion: .driftLeft(minSpeed: Game.birdMinSpeed, maxSpeed: Game.birdMaxSpeed),
                countRange: Game.minBirds...Game.maxBirds,
                yRange: range,
                segmentSize: segment,
                xPadding: 128,
                zPosition: 0,
                scaleRange: 1.0...1.0,
                animationStartDelayRange: 0.0...0.75,
                randomRotation: false,
                parallaxFactor: Game.birdParallax,
                maxCount: 80
            )
        }

        add(max(middleY, birdBandStart), min(endY, birdBandEnd)) { range in
            AtmosphereLayer(
                name: "planes",
                kind: .staticSprite(imageName: "plane"),
                motion: .driftLeft(minSpeed: Game.birdMinSpeed, maxSpeed: Game.birdMaxSpeed),
                countRange: Game.minBirds...Game.maxBirds,
                yRange: range,
                segmentSize: segment,
                xPadding: 128,
                zPosition: 1,
                scaleRange: 1.0...1.0,
                animationStartDelayRange: 0.0...0.0,
                randomRotation: false,
                parallaxFactor: Game.planeParallax,
                maxCount: 80
            )
        }

        add(max(endY, birdBandStart), cloudBandEnd) { range in
            AtmosphereLayer(
                name: "ufos",
                kind: .staticSprite(imageName: "ufo"),
                motion: .driftLeft(minSpeed: Game.birdMinSpeed, maxSpeed: Game.birdMaxSpeed),
                countRange: Game.minBirds...Game.maxBirds,
                yRange: range,
                segmentSize: segment,
                xPadding: 128,
                zPosition: 2,
                scaleRange: 1.0...1.0,
                animationStartDelayRange: 0.0...0.0,
                randomRotation: false,
                parallaxFactor: Game.ufoParallax,
                maxCount: 80
            )
        }

        return layers
    }

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

    private func spawnEntity(in layer: AtmosphereLayer, layerIndex: Int, atY yPos: CGFloat) {
        let xLow = -layer.xPadding
        let xHigh = GameState.shared.metrics.width + layer.xPadding
        let xPos = CGFloat.random(in: xLow...xHigh)

        let node: SKSpriteNode
        switch layer.kind {
        case let .randomFrameSprite(sheet, fw, fh):
            let scale = CGFloat.random(in: layer.scaleRange)
            let s = AnimatedSprite(spritesheetName: sheet, frameWidth: fw, frameHeight: fh, scale: scale)
            s.texture = s.frames.randomElement()
            attachDriftPhysics(to: s, motion: layer.motion)
            node = s

        case let .animatedSprite(sheet, fw, fh, animName, frameIndices, tpf):
            let scale = CGFloat.random(in: layer.scaleRange)
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
            s.setScale(CGFloat.random(in: layer.scaleRange))
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

    func update() {
        let cameraY = scene.camera?.position.y ?? referenceCameraY ?? 0
        if referenceCameraY == nil {
            referenceCameraY = cameraY
        }
        let cameraDelta = cameraY - referenceCameraY!

        for (layerIndex, layer) in layers.enumerated() {
            let trackingFactor = 1.0 - layer.parallaxFactor
            let offset = cameraDelta * trackingFactor

            for entity in entitiesByLayer[layerIndex] {
                entity.node.position.y = Atmosphere.wrap(entity.anchorY + offset, in: layer.yRange)
                recycle(entity: entity, layer: layer, offset: offset)
            }
        }
    }

    private static func wrap(_ y: CGFloat, in range: ClosedRange<CGFloat>) -> CGFloat {
        let height = range.upperBound - range.lowerBound
        guard height > 0 else { return range.lowerBound }
        let raw = y - range.lowerBound
        let r = raw.truncatingRemainder(dividingBy: height)
        return range.lowerBound + (r < 0 ? r + height : r)
    }

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
        let color: SKColor
        if cameraY <= startY {
            color = Atmosphere.startColor
        } else if cameraY <= middleY {
            let t = (cameraY - startY) / (middleY - startY)
            color = Atmosphere.interpolateColor(from: Atmosphere.startColor, to: Atmosphere.middleColor, fraction: t)
        } else if cameraY <= endY {
            let t = (cameraY - middleY) / (endY - middleY)
            color = Atmosphere.interpolateColor(from: Atmosphere.middleColor, to: Atmosphere.endColor, fraction: t)
        } else {
            color = Atmosphere.endColor
        }

        self.scene.backgroundColor = color
    }

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

    private static func simdComponents(_ color: SKColor) -> SIMD4<Float> {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD4<Float>(Float(r), Float(g), Float(b), Float(a))
    }
}
