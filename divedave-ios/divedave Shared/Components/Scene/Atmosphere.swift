//
//  Atmosphere.swift
//  divedave iOS
//
//  Created by David Durkin on 11/7/24.
//

import SpriteKit

final class Atmosphere {
    private var clouds: [AnimatedSprite] = []
    private var birds: [AnimatedSprite] = []
    private var stars: [AnimatedSprite] = []
    private var planes: [SKSpriteNode] = []
    private var ufos: [SKSpriteNode] = []
    private let scene: SKScene
    private let sceneHeight: CGFloat
    private let cloudSegmentSize: CGFloat
    private let birdSegmentSize: CGFloat
    private let startY: CGFloat
    private let middleY: CGFloat
    private let endY: CGFloat
    
    init(scene: SKScene, sceneHeight: CGFloat, startY: CGFloat, middleY: CGFloat, endY: CGFloat) {
        self.scene = scene
        self.sceneHeight = sceneHeight
        self.cloudSegmentSize = 1000 * scaleFactorHeight
        self.birdSegmentSize = 1000 * scaleFactorHeight
        self.middleY = middleY
        self.endY = endY
        self.startY = startY
        
        spawnAtmosphereElements()
    }

    private func spawnAtmosphereElements() {
        spawnCloudsAndStars()
        spawnBirdsPlanesAndUFOs()
    }

    private func spawnCloudsAndStars() {
        for segment in stride(from: cloudSegmentSize + 500 * scaleFactorHeight, to: sceneHeight + cloudSegmentSize, by: cloudSegmentSize) {
            let cloudCount = Int.random(in: MIN_CLOUDS...MAX_CLOUDS)
            let yMin = segment - cloudSegmentSize
            let yMax = segment
            let starMult = 1
            
            for _ in 0..<cloudCount {
                let yPos = CGFloat.random(in: yMin...yMax)
                let xPos = CGFloat.random(in: -(256 * scaleFactorHeight)...(WIDTH + (256 * scaleFactorHeight)))
                
                if yPos <= middleY {
                    // Spawn cloud
                    let cloud = AnimatedSprite(spritesheetName: "clouds", frameWidth: 256, frameHeight: 256, scale: scaleFactorHeight * CGFloat.random(in: 1.0...2.0))
                    cloud.position = CGPoint(x: xPos, y: yPos)
                    cloud.zPosition = 0
                    cloud.physicsBody = SKPhysicsBody(rectangleOf: cloud.size)
                    cloud.physicsBody?.affectedByGravity = false
                    cloud.physicsBody?.linearDamping = 0.0
                    cloud.physicsBody?.velocity = CGVector(dx: CGFloat.random(in: CLOUD_MIN_SPEED...CLOUD_MAX_SPEED), dy: 0)
                    cloud.physicsBody?.collisionBitMask = 0
                    cloud.physicsBody?.categoryBitMask = 0
                    cloud.texture = cloud.frames.randomElement()
                    clouds.append(cloud)
                    scene.addChild(cloud)
                } else if yPos > endY {
                    for _ in (0...starMult) {
                        let starYPos = CGFloat.random(in: yMin...yMax)
                        let starXPos = CGFloat.random(in: 0...WIDTH)
                        // Spawn star with "sparkle" animation
                        let star = AnimatedSprite(spritesheetName: "star-spritesheet", frameWidth: 128, frameHeight: 128, scale: scaleFactorHeight)
                        star.defineAnimation(name: "sparkle", frameIndices: [0, 0, 0, 0, 0, 1, 2, 3], timePerFrame: 0.25)
                        star.position = CGPoint(x: starXPos, y: starYPos)
                        star.zPosition = 1

                        // Set random rotation
                        star.zRotation = CGFloat.random(in: 0...(2 * .pi))
                        
                        let delay = Double.random(in: 0.0...0.75)
                        star.run(SKAction.wait(forDuration: delay)) {
                            star.playAnimation(name: "sparkle")
                        }

                        stars.append(star)
                        scene.addChild(star)
                    }
                }
            }
        }
    }

    private func spawnBirdsPlanesAndUFOs() {
        for segment in stride(from: birdSegmentSize, to: sceneHeight - 500 * scaleFactorHeight, by: birdSegmentSize) {
            let birdCount = Int.random(in: MIN_BIRDS...MAX_BIRDS)
            let yMin = segment - birdSegmentSize
            let yMax = segment
            
            for _ in 0..<birdCount {
                let yPos = CGFloat.random(in: yMin...yMax)
                let xPos = CGFloat.random(in: -(128 * scaleFactorHeight)...(HEIGHT + (128 * scaleFactorHeight)))
                
                if yPos <= middleY {
                    // Spawn bird
                    let bird = AnimatedSprite(spritesheetName: "bird", frameWidth: 128, frameHeight: 128, scale: scaleFactorHeight)
                    bird.defineAnimation(name: "fly", frameIndices: [0, 0, 0, 0, 1, 2, 3, 4, 3, 2, 1], timePerFrame: 0.83)
                    bird.position = CGPoint(x: xPos, y: yPos)
                    bird.zPosition = 0
                    bird.physicsBody = SKPhysicsBody(rectangleOf: bird.size)
                    bird.physicsBody?.affectedByGravity = false
                    bird.physicsBody?.linearDamping = 0.0
                    bird.physicsBody?.velocity = CGVector(dx: -CGFloat.random(in: BIRD_MIN_SPEED...BIRD_MAX_SPEED), dy: 0)
                    bird.physicsBody?.collisionBitMask = 0
                    bird.physicsBody?.categoryBitMask = 0

                    // Add delayed animation
                    let delay = CGFloat.random(in: 0...0.75)
                    bird.run(SKAction.wait(forDuration: TimeInterval(delay))) {
                        bird.playAnimation(name: "fly")
                    }
                    birds.append(bird)
                    scene.addChild(bird)
                } else if yPos <= endY {
                    // Spawn plane
                    let plane = SKSpriteNode(imageNamed: "plane")
                    plane.position = CGPoint(x: xPos, y: yPos)
                    plane.zPosition = 1
                    plane.setScale(scaleFactorHeight)
                    plane.physicsBody = SKPhysicsBody(rectangleOf: plane.size)
                    plane.physicsBody?.affectedByGravity = false
                    plane.physicsBody?.linearDamping = 0.0
                    plane.physicsBody?.velocity = CGVector(dx: -CGFloat.random(in: BIRD_MIN_SPEED...BIRD_MAX_SPEED), dy: 0)
                    plane.physicsBody?.collisionBitMask = 0
                    plane.physicsBody?.categoryBitMask = 0
                    planes.append(plane)
                    scene.addChild(plane)
                } else {
                    // Spawn UFO
                    let ufo = SKSpriteNode(imageNamed: "ufo")
                    ufo.position = CGPoint(x: xPos, y: yPos)
                    ufo.zPosition = 2
                    ufo.setScale(scaleFactorHeight)
                    ufo.physicsBody = SKPhysicsBody(rectangleOf: ufo.size)
                    ufo.physicsBody?.affectedByGravity = false
                    ufo.physicsBody?.linearDamping = 0.0
                    ufo.physicsBody?.velocity = CGVector(dx: -CGFloat.random(in: BIRD_MIN_SPEED...BIRD_MAX_SPEED), dy: 0)
                    ufo.physicsBody?.collisionBitMask = 0
                    ufo.physicsBody?.categoryBitMask = 0
                    ufos.append(ufo)
                    scene.addChild(ufo)
                }
            }
        }
    }

    func update() {
        // Update clouds and stars
        for cloud in clouds {
            if cloud.position.x >= WIDTH + cloud.size.width / 2 {
                let yPos = CGFloat.random(in: 0...middleY)
                cloud.position = CGPoint(x: -cloud.size.width * 2, y: yPos)
                cloud.physicsBody?.velocity = CGVector(dx: CGFloat.random(in: CLOUD_MIN_SPEED...CLOUD_MAX_SPEED), dy: 0)
                cloud.texture = cloud.frames.randomElement()
            }
        }
        
        // Update birds, planes, and UFOs
        for bird in birds {
            if bird.position.x + bird.size.width / 2 < 0 {
                let yPos = CGFloat.random(in: 0...middleY)
                bird.position = CGPoint(x: WIDTH + bird.size.width * 2, y: yPos)
                bird.physicsBody?.velocity = CGVector(dx: -CGFloat.random(in: BIRD_MIN_SPEED...BIRD_MAX_SPEED), dy: 0)
            }
        }
        
        for plane in planes {
            if plane.position.x + plane.size.width / 2 < 0 {
                let yPos = CGFloat.random(in: middleY...endY)
                plane.position = CGPoint(x: WIDTH + plane.size.width * 2, y: yPos)
                plane.physicsBody?.velocity = CGVector(dx: -CGFloat.random(in: BIRD_MIN_SPEED...BIRD_MAX_SPEED), dy: 0)
            }
        }
        
        for ufo in ufos {
            if ufo.position.x + ufo.size.width / 2 < 0 {
                let yPos = CGFloat.random(in: endY...sceneHeight)
                ufo.position = CGPoint(x: WIDTH + ufo.size.width * 2, y: yPos)
                ufo.physicsBody?.velocity = CGVector(dx: -CGFloat.random(in: BIRD_MIN_SPEED...BIRD_MAX_SPEED), dy: 0)
            }
        }
    }
    
    func updateBackgroundColor(for cameraY: CGFloat) {
        // Determine the current color based on camera y position
        let color: SKColor
        if cameraY <= startY {
            color = startColor
        } else if cameraY > startY && cameraY <= middleY {
            // Interpolate between startColor and middleColor
            let t = (cameraY - startY) / (middleY - startY)
            color = interpolateColor(from: startColor, to: middleColor, fraction: t)
        } else if cameraY > middleY && cameraY <= endY {
            // Interpolate between middleColor and endColor
            let t = (cameraY - middleY) / (endY - middleY)
            color = interpolateColor(from: middleColor, to: endColor, fraction: t)
        } else {
            color = endColor
        }
        
        // Set the background color
        self.scene.backgroundColor = color
    }

    // Helper function to interpolate between two colors
    func interpolateColor(from color1: SKColor, to color2: SKColor, fraction: CGFloat) -> SKColor {
        let clampedFraction = max(0, min(1, fraction))
        
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        color1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let r = r1 + (r2 - r1) * clampedFraction
        let g = g1 + (g2 - g1) * clampedFraction
        let b = b1 + (b2 - b1) * clampedFraction
        let a = a1 + (a2 - a1) * clampedFraction
        
        return SKColor(red: r, green: g, blue: b, alpha: a)
    }

}
