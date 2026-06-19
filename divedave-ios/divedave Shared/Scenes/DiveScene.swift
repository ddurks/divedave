//
//  DiveScene.swift
//  divedave iOS
//
//  Created by David Durkin on 10/29/24.
//

import SpriteKit
import os

private let logger = Logger(subsystem: "com.drawvid.divedave", category: "gameplay")

struct DiveStats {
    var height: Double = 0.0
    var angle: Double = 0.0
    var tucked: Bool = false
    var tuckCount: Int = 0
    var rotations: Double = 0.0
    var scores: [Int] = [0, 0, 0]
    var emotionFrame: Int = 2
}

final class DiveScene: SKScene, SKPhysicsContactDelegate {
    private var readyForReset = false
    var hud: HUD!
    var waterLevel: CGFloat = 0
    var diveComplete = false
    var springboard: AnimatedSprite!
    /// Forwards to `davePlayer.dave` so the many existing references can stay short.
    var dave: AnimatedSprite! { davePlayer?.dave }
    var water: AnimatedSprite!
    var splash: AnimatedSprite!
    var climbdave: AnimatedSprite!
    var gettingoutdave: AnimatedSprite!
    var platformTop: SKSpriteNode!
    var goalRotations: Double = 0.5
    var highScoreSession = false
    var info: InfoPanel!
    var highScorePanel: InfoPanel!
    private var atmosphere: Atmosphere!
    private var cameraController: CameraController!
    private var davePlayer: DavePlayer!
    private let boardContact = BoardContact()
    private let rotationTracker = RotationTracker()
    
    override func didMove(to view: SKView) {
        physicsWorld.gravity = CGVector(dx: 0, dy: -Game.gravity)
        physicsWorld.contactDelegate = self
        self.backgroundColor = SKColor(red: 0.74, green: 0.84, blue: 1.0, alpha: 1.0)
        diveComplete = false
        let buffer = GameState.shared.metrics.height/2
        if ((GameState.shared.platformHeight * GameState.shared.metrics.scaleFactorHeight) < GameState.shared.metrics.height - buffer) {
            GameState.shared.sceneHeight = GameState.shared.metrics.height
        } else {
            GameState.shared.sceneHeight = GameState.shared.platformHeight + buffer
        }
        setupScene()
        cameraController = CameraController(scene: self)
        setupHUD(view: view, camera: cameraController.node)
        setupInfoPanels()
        setupSpringboard()
        setupHeightLabels()
        davePlayer = DavePlayer(scene: self, springboard: springboard)
        setupSplash()
        calculateGameLogic()
        atmosphere = Atmosphere(scene: self, sceneHeight: GameState.shared.sceneHeight, startY: gettingoutdave.size.height, middleY: GameState.shared.metrics.height * 2, endY: GameState.shared.metrics.height * 4)
    }
    
    func setupHUD(view: SKView, camera: SKCameraNode) {
        logger.debug("self.size: \(self.size.debugDescription)")
        hud = HUD(view: view, camera: camera, sceneSize: self.size, scaleFactorHeight: GameState.shared.metrics.scaleFactorHeight)
        hud.onMenuPressed = self.prepareAndPresentMainMenuScene
    }
    
    func approximateFallTime(from height: CGFloat, to groundLevel: CGFloat, gravity: CGFloat, frameRate: Double = 60.0) -> Double {
        // Closed-form solution for free fall from rest: t = sqrt(2 * d / g)
        let distance = max(0, height - groundLevel)
        guard gravity > 0 else { return 0 }
        return sqrt(2 * Double(distance) / Double(gravity))
    }

    func calculateGameLogic() {
        let diveHeight = (GameState.shared.platformHeight * GameState.shared.metrics.scaleFactorHeight)
        let time = approximateFallTime(from: diveHeight, to: waterLevel, gravity: Game.gravity) / 10
        
        // Calculate maximum number of flips based on the total rotation in radians
        let totalRotation = time * (Game.maxSpinVelocity * 0.70)
        let maxFlips = totalRotation / (2 * Double.pi)
        
        // Generate a random goal rotation value in terms of half rotations
        let halfFlips = Int(maxFlips * 2)
        let randomHalfFlips = Double(Int.random(in: 1...halfFlips)) / 2.0
        
        // Set goal rotations to the selected half-flip value
        goalRotations = randomHalfFlips
        hud.setGoalFlips(flips: goalRotations)
        
        logger.debug("DiveHeight: \(diveHeight), Time (approximated): \(time), Total Rotation (radians): \(totalRotation), Max Flips: \(maxFlips), Half-Flips (integer): \(halfFlips), Random Half-Flips: \(randomHalfFlips), Goal Rotations: \(self.goalRotations)")
    }

    func setupScene() {
        setupLandscapeAndPool()
        
        // Water level and height labels
        waterLevel = ((256 * GameState.shared.metrics.scaleFactorHeight)/2) + 1
        
        // Platform sections, scaled and adjusted to fit SpriteKit’s y-axis
        let platformTopPosition = CGPoint(x: GameState.shared.metrics.width/7, y: waterLevel + (GameState.shared.platformHeight * GameState.shared.metrics.scaleFactorHeight))
        platformTop = SKSpriteNode(imageNamed: "platformtop")
        platformTop.position = platformTopPosition
        platformTop.zPosition = 9
        platformTop.setScale(GameState.shared.metrics.scaleFactorHeight)
        addChild(platformTop)

        for i in stride(from: platformTop.position.y - platformTop.size.height, to: 200 * GameState.shared.metrics.scaleFactorHeight, by: -100 * GameState.shared.metrics.scaleFactorHeight) {
            let platformSection = SKSpriteNode(imageNamed: "platformsection")
            platformSection.position = CGPoint(x: platformTopPosition.x, y: i)
            platformSection.zPosition = 8
            platformSection.setScale(GameState.shared.metrics.scaleFactorHeight)
            addChild(platformSection)
        }
        
        let platformBase = SKSpriteNode(imageNamed: "platformbase")
        platformBase.position = CGPoint(x: platformTopPosition.x, y: 200 * GameState.shared.metrics.scaleFactorHeight)
        platformBase.zPosition = 9
        platformBase.setScale(GameState.shared.metrics.scaleFactorHeight)
        addChild(platformBase)
        
        setupClimbDave(x: platformBase.position.x, y: platformBase.position.y)
        
        // Set up the world bounds
        let offset = 100.0
        self.physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(x: platformTop.position.x - (platformTop.size.width/2), y: -offset, width: GameState.shared.metrics.width, height: GameState.shared.sceneHeight + 2*offset))
        self.physicsBody?.restitution = 0.0
        physicsWorld.contactDelegate = self
    }
    
    func setupInfoPanels() {
        info = InfoPanel(scene: self, depth: 20);
        highScorePanel = InfoPanel(scene: self, depth: 24)
    }
        
    func setupHeightLabels() {
        logger.debug("water level: \(self.waterLevel)")
        
        var y = waterLevel
        var currentMeter = 1  // Start at 0 meters from the water level
        let majorSpacing = 200.0 * GameState.shared.metrics.scaleFactorHeight
        let minorSpacing = 20.0 * GameState.shared.metrics.scaleFactorHeight
        let maxY = springboard.position.y
        
        // Initialize counters for major and minor spacing
        var majorCounter = 0.0
        var minorCounter = 0.0

        // Loop until y reaches the springboard position
        while y < maxY {
            // Set label color based on height
            var labelColor: SKColor = Game.customRed
            if currentMeter < 25 {
                labelColor = Game.customYellow
            }
            if currentMeter < 10 {
                labelColor = Game.customGreen
            }
            
            let labelPosition = CGPoint(x: 5*GameState.shared.metrics.width/6, y: CGFloat(y))
            let formattedHeight = String(currentMeter)

            // Check major spacing counter
            if majorCounter >= majorSpacing {
                let label = createLabel(text: "- \(formattedHeight)m", fontSize: 20, position: labelPosition, zPosition: 10, fontColor: labelColor, bold: true)
                label.isHidden = false
                addChild(label)
                majorCounter = 0.0  // Reset major counter
                currentMeter += 1   // Increment the meter label by 1
            }
            // Check minor spacing counter
            else if minorCounter >= minorSpacing {
                let marker = createLabel(text: "-", fontSize: 20, position: labelPosition, zPosition: 10, fontColor: labelColor)
                marker.isHidden = false
                addChild(marker)
                minorCounter = 0.0  // Reset minor counter
            }
            
            // Increment y by GameState.shared.metrics.scaleFactorHeight for each iteration
            y += GameState.shared.metrics.scaleFactorHeight
            
            // Increment the spacing counters by GameState.shared.metrics.scaleFactorHeight
            majorCounter += GameState.shared.metrics.scaleFactorHeight
            minorCounter += GameState.shared.metrics.scaleFactorHeight
        }
    }
    
    func resetScene() {
        if (self.diveComplete && self.readyForReset) {
            if (!GameState.shared.challengeMode) {
                GameState.shared.platformHeight = Double.random(in: 703...(GameState.shared.metrics.height * 25))
                restartScene()
            } else {
                if (GameState.shared.totalScore == 0) {
                    GameState.shared.platformHeight = 703
                    restartScene()
                } else {
                    let streakFactor = 2.0 * Double(GameState.shared.streak)
                    let denominator = streakFactor + 100.0
                    let streakMultiplier: Double = 1.0 + (streakFactor / denominator)

                    let randomHeightIncrease = Double.random(in: 0...500)
                    let newPlatformHeight = GameState.shared.platformHeight + randomHeightIncrease
                    GameState.shared.platformHeight = newPlatformHeight * streakMultiplier

                    restartScene()
                }
            }
        }
    }
    
    func restartScene() {
        // Restart the scene
        let newScene = DiveScene(size: self.size)
        newScene.scaleMode = self.scaleMode
        self.view?.presentScene(newScene, transition: SKTransition.fade(withDuration: 0.5))
    }
    
    func setupClimbDave(x: CGFloat, y: CGFloat) {
        climbdave = AnimatedSprite(spritesheetName: "climbdave",
                              frameWidth: Game.defaultDaveHeight,
                              frameHeight: Game.defaultDaveHeight,
                              scale: GameState.shared.metrics.scaleFactorHeight)
        climbdave.position = CGPoint(x: x - (5*climbdave.size.width/7), y: y + climbdave.size.height/3)
        climbdave.zPosition = 5
        
        climbdave.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 64 * GameState.shared.metrics.scaleFactorWidth, height: 256 * GameState.shared.metrics.scaleFactorHeight))
        climbdave.physicsBody?.isDynamic = true
        climbdave.physicsBody?.affectedByGravity = false
        climbdave.physicsBody?.linearDamping = 0
        climbdave.physicsBody?.collisionBitMask = 0
        climbdave.physicsBody?.contactTestBitMask = 0
        climbdave.isHidden = true
        
        addChild(climbdave)
        
        climbdave.defineAnimation(name: "climb", frameIndices: [0, 1, 2, 3], timePerFrame: 0.125)
    }
    
    func setupSpringboard() {
        // Initialize the AnimatedSprite for the springboard
        springboard = AnimatedSprite(spritesheetName: "board", frameWidth: 440, frameHeight: 64, scale: GameState.shared.metrics.scaleFactorHeight)
        springboard.position = CGPoint(x: platformTop.position.x + platformTop.size.width / 3, y: platformTop.position.y)
        springboard.zPosition = 10
        
        // Define animations if needed (e.g., "bounce" or other)
        springboard.defineAnimation(name: "flex", frameIndices: [0, 1, 0], timePerFrame: 0.25, repeatForever: false)

        // Add physics body to springboard
        springboard.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: springboard.size.width, height: springboard.size.height))
        springboard.physicsBody?.isDynamic = false
        springboard.physicsBody?.affectedByGravity = false
        springboard.physicsBody?.restitution = 0.0
        springboard.physicsBody?.friction = 0.0
        springboard.physicsBody?.categoryBitMask = PhysicsCategory.springboard.rawValue

        addChild(springboard)
    }
    
    func setupSplash() {
        splash = AnimatedSprite(spritesheetName: "splash", frameWidth: 256, frameHeight: 256, scale: GameState.shared.metrics.scaleFactorHeight)
        splash.zPosition = 7
        
        // Define animations if needed (e.g., "bounce" or other)
        splash.defineAnimation(name: "splash", frameIndices: [0, 1, 2, 3, 4, 5, 6, 7], timePerFrame: 0.125, repeatForever: false)
        addChild(splash)
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        let bodies = (contact.bodyA.categoryBitMask, contact.bodyB.categoryBitMask)
        
        // Check if the contact is between `dave` and `springboard`
        if (bodies == (PhysicsCategory.dave.rawValue, PhysicsCategory.springboard.rawValue)) ||
           (bodies == (PhysicsCategory.springboard.rawValue, PhysicsCategory.dave.rawValue)) {
            Haptics.impact(.light)
            boardContact.didBegin(daveDidContactBoard: true)
            if davePlayer.landedAt == 0 {
                davePlayer.landedAt = CACurrentMediaTime()
                dave.playAnimation(name: "idle")
                logger.debug("LANDED AT \(self.davePlayer.landedAt)")
                pulseSpringboardBoostWindow()

                // Input buffer: if the player released the jump button SHORTLY
                // BEFORE landing (within ~175 ms — same as the OK window), fire
                // the jump automatically. Makes "tap slightly early" launch you
                // instead of being swallowed because the button wasn't held on
                // landing.
                let timeSinceRelease = (davePlayer.landedAt - GameState.shared.jumpReleasedAt) * 1000
                if GameState.shared.jumpReleasedAt > 0,
                   timeSinceRelease > 0,
                   timeSinceRelease < 175 {
                    triggerJump()
                }
            }
        }
    }

    /// Wraps DavePlayer.jump with the standard shake-on-launch + timing-
    /// feedback hooks. Used by playerMobileMovementHandler (jump button on
    /// the board) and didBegin (buffered early release).
    private func triggerJump() {
        davePlayer.jump(
            springboard: springboard,
            onJumpStarted: { [weak self] in
                self?.cameraController.shake(intensity: 4 * GameState.shared.metrics.scaleFactorHeight, duration: 0.15)
            },
            onJumpCompleted: { [weak self] timing in
                self?.showBoostTimingFeedback(timing)
            }
        )
    }

    /// Visual cue that the boost window has just opened: pulse the springboard
    /// from green (perfect, 50 ms) through yellow (good, +50 ms) to red (ok,
    /// +75 ms) then fades the tint out. Mirrors the thresholds in
    /// DavePlayer.calculateBoost so the rhythm reads the same as the scoring.
    private func pulseSpringboardBoostWindow() {
        springboard.removeAction(forKey: "boostWindowPulse")
        springboard.color = Game.customGreen
        springboard.colorBlendFactor = 0.6
        let pulse = SKAction.sequence([
            // perfect window: green, 50ms
            SKAction.wait(forDuration: 0.05),
            SKAction.run { [weak self] in self?.springboard.color = Game.customYellow },
            // good window: yellow, 50ms
            SKAction.wait(forDuration: 0.05),
            SKAction.run { [weak self] in self?.springboard.color = Game.customRed },
            // ok window: red fading out, 75ms
            SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.075)
        ])
        springboard.run(pulse, withKey: "boostWindowPulse")
    }
    
    func didEnd(_ contact: SKPhysicsContact) {
        let bodies = (contact.bodyA.categoryBitMask, contact.bodyB.categoryBitMask)
        
        if (bodies == (PhysicsCategory.dave.rawValue, PhysicsCategory.springboard.rawValue)) ||
           (bodies == (PhysicsCategory.springboard.rawValue, PhysicsCategory.dave.rawValue)) {
                boardContact.didEnd(daveDidContactBoard: true)
        }
    }
    
    func setupLandscapeAndPool() {
        // Landscape background image scaled and positioned
        let landscape = SKSpriteNode(imageNamed: "landscape")
        let aspectRatio = landscape.size.width / landscape.size.height
        
        // Scale landscape width to match viewport and adjust height based on aspect ratio
        landscape.size = CGSize(width: GameState.shared.metrics.width, height: GameState.shared.metrics.width / aspectRatio)
        landscape.position = CGPoint(x: GameState.shared.metrics.width / 2, y: landscape.size.height / 2)
        landscape.zPosition = 1
        addChild(landscape)
        
        water = AnimatedSprite(
            spritesheetName: "water",
            frameWidth: 1250,
            frameHeight: 200,
            margin: 0,
            spacing: 0,
            scale: 1.0
        )

        water.defineAnimation(name: "idle", frameIndices: [0, 1, 2, 3], timePerFrame: 0.25)

        let waterAspectRatio = water.size.width / water.size.height
        water.size = CGSize(width: GameState.shared.metrics.width, height: GameState.shared.metrics.width / waterAspectRatio)
        water.position = CGPoint(x: GameState.shared.metrics.width / 2, y: water.size.height / 2)
        water.zPosition = 6
        addChild(water)
        water.playAnimation(name: "idle")
        
        gettingoutdave = AnimatedSprite(
            spritesheetName: "getting-out-spritesheet",
            frameWidth: 1250,
            frameHeight: 500,
            margin: 0,
            spacing: 0,
            scale: 1.0
        )

        gettingoutdave.defineAnimation(name: "getOut", frameIndices: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27], timePerFrame: 0.125, repeatForever: false)

        gettingoutdave.size = CGSize(width: GameState.shared.metrics.width, height: GameState.shared.metrics.width / aspectRatio)
        gettingoutdave.position = CGPoint(x: GameState.shared.metrics.width / 2, y: landscape.size.height / 2)
        gettingoutdave.zPosition = 7
        gettingoutdave.isHidden = true
        addChild(gettingoutdave)
    }

    
    func daveIsAboveBoard(tolerance: CGFloat = 1.0) -> Bool {
        guard let dave = dave else { return false }
        let result = BoardContact.isAbove(dave: dave, board: springboard, tolerance: tolerance)
        if result {
            rotationTracker.reset()
        }
        return result
    }

    func daveIsTucked() -> Bool {
        return davePlayer.daveIsTucked(rotationTrackerTucked: rotationTracker.tucked)
    }

    func playerHandler() {
        guard davePlayer != nil else { return }

        davePlayer.applyDamping()
        checkForReset()
        if !davePlayer.jumping {
            playerMobileMovementHandler()
            davePlayer.updateFrame(
                aboveBoard: daveIsAboveBoard(),
                isTouching: boardContact.isTouching,
                tucked: rotationTracker.tucked
            )
        }
    }


    func playerMobileMovementHandler() {
        if !diveComplete {
            if daveIsAboveBoard() {
                hud?.jumpControls()
            } else {
                hud?.flipControls()
            }
        }
        
        // Check mobile control button states and handle movement
        if hud?.leftButton.isDown == true || hud?.rightButton.isDown == true ||
           hud?.jumpButton.isDown == true || hud?.flipButton.isDown == true {
            
            if !diveComplete {
                if hud?.leftButton.isDown == true {
                    dave.physicsBody?.velocity.dx = -Game.daveSpeed
                    
                }
                if hud?.rightButton.isDown == true {
                    dave.physicsBody?.velocity.dx = Game.daveSpeed
                }
                if daveIsAboveBoard() {
                    if hud?.jumpButton.isDown == true && boardContact.isTouching {
                        triggerJump()
                    }
                } else if (hud?.jumpButton.isDown == true || hud?.flipButton.isDown == true) {
                    if !daveIsTucked() {
                        rotationTracker.beginTuck()
                    } else {
                        rotationTracker.incrementSpin()
                    }
                    dave.physicsBody?.angularVelocity = -rotationTracker.currentVelocity
                }
            }
        } else {
            rotationTracker.resetTuck()
        }
    }
    
    func checkForReset() {
        // Ensure dive is not already marked as complete
        if !diveComplete && !daveIsAboveBoard() {
            // Check if Dave has reached the water level
            if dave.position.y < waterLevel {
                Haptics.impact(.heavy)
                diveComplete = true
                splash.position = CGPoint(x: dave.position.x, y: waterLevel + 100*GameState.shared.metrics.scaleFactorHeight)
                splash.isHidden = false
                splash.playAnimation(name: "splash") {
                    self.splash.isHidden = true
                    self.splash.clearCurrentAnimation()
                }
                // Splash impact: pronounced shake.
                cameraController.shake(intensity: 14 * GameState.shared.metrics.scaleFactorHeight, duration: 0.3)

                // Calculate height, angle, and other stats
                GameState.shared.stats.height = calculateHeightFromWater()
                GameState.shared.stats.angle = round(dave.zRotation * (180.0 / .pi) * 10.0) / 10
                GameState.shared.stats.tucked = daveIsTucked()
                GameState.shared.stats.tuckCount = rotationTracker.tuckCount
                GameState.shared.stats.rotations = round(rotationTracker.totalRotations * 10) / 10

                logger.debug("stats: \(String(describing: GameState.shared.stats))")

                let result = scoreDive()
                Haptics.notify(result == "FAILED DIVE" ? .error : .success)
                hud.setRunningStreak(streak: GameState.shared.streak)
                hud.setRunningScore(score: GameState.shared.totalScore)
                let displayStrings = [
                    "height: \(GameState.shared.stats.height)m",
                    "entry angle: \(GameState.shared.stats.angle)",
                    "rotations: \(GameState.shared.stats.rotations)"
                ]

                // 200ms beat before the score panel — lets the splash + shake land
                // before the camera attention shifts to the overlay.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.info.display(result: result, strings: displayStrings, frame: GameState.shared.stats.emotionFrame, scores: GameState.shared.stats.scores)
                    self.hud.setVisible(false)
                }
                
                // Set a delay to allow for scene reset readiness
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.readyForReset = true
                    
                    self.gettingoutdave.isHidden = false
                    self.gettingoutdave.playAnimation(name: "getOut") {
                        self.climbdave.physicsBody?.velocity.dy = 50
                        self.gettingoutdave.isHidden = true
                        self.climbdave.playAnimation(name: "climb")
                        self.climbdave.isHidden = false
                    }
                }
            }
            
            // Track rotations while in the air
            countRotations()
        }
    }
    
    func calculateHeightFromWater() -> Double {
        return DiveScorer.heightInMeters(
            springboardY: springboard.position.y,
            waterY: waterLevel,
            scaleFactorHeight: GameState.shared.metrics.scaleFactorHeight
        )
    }

    /// Pop a PERFECT / GOOD / OK feedback label near Dave when the jump
    /// completes. Reveals the otherwise-invisible boost-window mechanic
    /// so players can learn to release jump quickly after landing.
    private func showBoostTimingFeedback(_ timing: BoostTiming) {
        let text: String
        let color: SKColor
        switch timing {
        case .perfect: text = "PERFECT!"; color = Game.customGreen
        case .good:    text = "GOOD";     color = Game.customYellow
        case .ok:      text = "OK";       color = Game.customRed
        case .miss:    return // Don't punish the player with a "MISS" label.
        }

        // Anchor the feedback right above the springboard so it reads as
        // "this is about the timing of your push off the board".
        let container = SKNode()
        container.position = CGPoint(
            x: springboard.position.x,
            y: springboard.position.y + (springboard.size.height / 2) + (10 * GameState.shared.metrics.scaleFactorHeight)
        )
        container.zPosition = 4
        container.alpha = 0
        container.setScale(0.3)

        let shadow = SKLabelNode(text: text)
        shadow.fontName = "Arial-BoldMT"
        shadow.fontSize = 25
        shadow.fontColor = .black
        shadow.position = CGPoint(x: 2, y: -2)
        container.addChild(shadow)

        let main = SKLabelNode(text: text)
        main.fontName = "Arial-BoldMT"
        main.fontSize = 25
        main.fontColor = color
        container.addChild(main)

        addChild(container)

        container.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.4, duration: 0.12),
                SKAction.fadeIn(withDuration: 0.08)
            ]),
            SKAction.scale(to: 1.0, duration: 0.08),
            SKAction.wait(forDuration: 0.5),
            SKAction.group([
                SKAction.moveBy(x: 0, y: 20, duration: 0.4),
                SKAction.fadeOut(withDuration: 0.4)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    func countRotations() {
        guard let completed = rotationTracker.countRotations(daveRotation: dave.zRotation) else { return }
        Haptics.impact(.light)

        let fontColor: SKColor = completed > Double(goalRotations) ? Game.customRed : Game.customGreen
        let text = "\(Int(completed))"

        // Parent container so we can scale/fade/translate the whole stack
        // as one unit. SKNode propagates alpha visually to its children.
        let container = SKNode()
        container.position = dave.position
        container.zPosition = 4
        container.alpha = 0
        container.setScale(0.3)

        // Drop shadow: a black copy offset down-right for legibility against
        // bright sky / cloud frames.
        let shadow = SKLabelNode(text: text)
        shadow.fontName = "Arial-BoldMT"
        shadow.fontSize = 60
        shadow.fontColor = .black
        shadow.position = CGPoint(x: 4, y: -4)
        container.addChild(shadow)

        // Main label
        let main = SKLabelNode(text: text)
        main.fontName = "Arial-BoldMT"
        main.fontSize = 60
        main.fontColor = fontColor
        container.addChild(main)

        addChild(container)

        // Pop-in: scale 0.3 -> 1.4 -> 1.0 while fading in, then hold, then
        // drift up + fade out + remove.
        container.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.4, duration: 0.12),
                SKAction.fadeIn(withDuration: 0.08)
            ]),
            SKAction.scale(to: 1.0, duration: 0.08),
            SKAction.wait(forDuration: 0.55),
            SKAction.group([
                SKAction.moveBy(x: 0, y: 50, duration: 0.4),
                SKAction.fadeOut(withDuration: 0.4)
            ]),
            SKAction.removeFromParent()
        ]))
    }


    func scoreDive() -> String {
        // Persist per-dive meta-progression (every dive, success or fail)
        StatsStore.totalDives += 1
        StatsStore.totalFlips += Int(GameState.shared.stats.rotations)
        StatsStore.maxHeightReached = max(StatsStore.maxHeightReached, Int(GameState.shared.platformHeight))

        let outcome = DiveScorer.score(
            goalRotations: goalRotations,
            rotations: GameState.shared.stats.rotations,
            angle: GameState.shared.stats.angle,
            tuckCount: rotationTracker.tuckCount
        )

        GameState.shared.stats.emotionFrame = outcome.emotionFrame
        GameState.shared.stats.scores = outcome.scores

        switch outcome.result {
        case .success:
            GameState.shared.streak += 1
            GameState.shared.totalScore += outcome.scores.reduce(0, +)

            // Track longest streak across runs
            StatsStore.longestStreak = max(StatsStore.longestStreak, GameState.shared.streak)

            // Per-mode high score
            if GameState.shared.challengeMode {
                StatsStore.challengeHigh = max(StatsStore.challengeHigh, GameState.shared.totalScore)
            } else {
                StatsStore.arcadeHigh = max(StatsStore.arcadeHigh, GameState.shared.totalScore)
            }

            if GameState.shared.challengeMode && GameState.shared.totalScore > GameState.shared.highScore {
                // GameState.shared.highScore's setter persists to UserDefaults synchronously.
                GameState.shared.highScore = GameState.shared.totalScore
                highScoreSession = true

                // Display high score text briefly
                hud.highScoreLabel.isHidden = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    self.hud.highScoreLabel.isHidden = true
                }
            }

            return "SUCCESS"

        case .failure:
            if highScoreSession {
                highScorePanel.display(result: "GAME OVER",  strings: [
                    "",
                    "NEW HIGH SCORE: \(GameState.shared.totalScore)",
                    "",
                    "final height: \(GameState.shared.stats.height)m",
                    "streak: \(GameState.shared.streak) dives",
                ], frame: 3, scores: nil)
            }

            // Reset streak and total score
            GameState.shared.streak = 0
            GameState.shared.totalScore = 0

            return "FAILED DIVE"
        }
    }


    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if (self.diveComplete) {
            Haptics.impact(.light)
            resetScene()
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {

    }
    
    override func update(_ currentTime: TimeInterval) {
        playerHandler()
        applyPhaserStyleAngularDrag(currentTime: currentTime)
        updateClimbDave()
        if let davePos = dave?.position {
            cameraController.follow(targetY: davePos.y)
            atmosphere.updateBackgroundColor(for: cameraController.node.position.y)
        }
        atmosphere.update()
    }
    
    func applyPhaserStyleAngularDrag(currentTime: TimeInterval) {
        guard let body = dave.physicsBody else { return }
        rotationTracker.applyAngularDrag(to: body, currentTime: currentTime)
    }
    
    func updateClimbDave() {
        if (diveComplete && climbdave != nil && platformTop != nil) {
            if (climbdave.position.y > platformTop.position.y) {
                climbdave.physicsBody?.velocity.dy = 0
                climbdave.stopAnimation()
                climbdave.texture = climbdave.frames[0]
            }
        }
    }

    func prepareAndPresentMainMenuScene() {
        let mainMenuScene = MainMenuScene(size: self.view!.bounds.size)
        mainMenuScene.backgroundColor = SKColor(red: 0.74, green: 0.84, blue: 1.0, alpha: 1.0)
        mainMenuScene.scaleMode = .aspectFill
        mainMenuScene.setupMenu()
        self.diveComplete = true
        self.readyForReset = true
        GameState.shared.totalScore = 0
        GameState.shared.platformHeight = 703
        // Note: previously also called self.restartScene() here, which created
        // a fresh DiveScene and presented it — followed immediately by this
        // presentScene(mainMenuScene). Two back-to-back presentScene calls
        // raced; the menu always won but the wasted DiveScene leaked briefly.
        self.view!.presentScene(mainMenuScene, transition: SKTransition.crossFade(withDuration: 0.5))
    }
}
