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

// Mirror of divedave-web GETTING_OUT, scaled to points by scaleFactorWidth.
private enum GetOut {
    static let ladderX: CGFloat = 937
    static let ladderYUp: CGFloat = 191
    static let ladderScale: CGFloat = 0.87
    static let emergeYUp: CGFloat = 207
    static let deckYUp: CGFloat = 325
    static let walkSpeed: CGFloat = 450
    static let turnFrameDuration: TimeInterval = 0.07
    static let climbX: CGFloat = 28
    static let climbXNudge: CGFloat = 3 // iOS-only: aligns the climb pose on the tower
    static let climbSpeed: CGFloat = 200
    static let ladderOverlapPx: CGFloat = 70
}

private enum GetOutState { case idle, emerge, turn1, walk, turn2, climb, done }

final class DiveScene: SKScene, SKPhysicsContactDelegate {
    private var readyForReset = false
    var onDuelComplete: ((Int) -> Void)?
    private var duelGoalRotations: Double?
    var hud: HUD!
    var waterLevel: CGFloat = 0
    var diveComplete = false
    var springboard: AnimatedSprite!
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
    private var poolLadder: SKSpriteNode!
    private var landscapeHeight: CGFloat = 0
    private var goState: GetOutState = .idle
    private var goTurnElapsed: TimeInterval = 0
    private var goTurnFrames: [Int] = []
    private var goTurnFlips: [Bool] = []
    private var goLastTime: TimeInterval = 0
    private var sfw: CGFloat { GameState.shared.metrics.scaleFactorWidth }

    override func didMove(to view: SKView) {
        physicsWorld.gravity = CGVector(dx: 0, dy: -Game.gravity)
        physicsWorld.contactDelegate = self
        self.backgroundColor = SKColor(red: 0.74, green: 0.84, blue: 1.0, alpha: 1.0)
        diveComplete = false
        if let seed = GameState.shared.duelSeed {
            let params = DiveScene.duelParams(seed: seed)
            GameState.shared.platformHeight = CGFloat(params.platformHeight)
            GameState.shared.totalScore = 0
            GameState.shared.streak = 0
            duelGoalRotations = params.goalRotations
        }
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
        atmosphere = Atmosphere(scene: self, sceneHeight: GameState.shared.sceneHeight, startY: landscapeHeight, middleY: GameState.shared.metrics.height * 2, endY: GameState.shared.metrics.height * 4)
    }

    func setupHUD(view: SKView, camera: SKCameraNode) {
        logger.debug("self.size: \(self.size.debugDescription)")
        hud = HUD(view: view, camera: camera, sceneSize: self.size, scaleFactorHeight: GameState.shared.metrics.scaleFactorHeight)
        hud.onMenuPressed = self.prepareAndPresentMainMenuScene
    }

    func approximateFallTime(from height: CGFloat, to groundLevel: CGFloat, gravity: CGFloat, frameRate: Double = 60.0) -> Double {
        let distance = max(0, height - groundLevel)
        guard gravity > 0 else { return 0 }
        return sqrt(2 * Double(distance) / Double(gravity))
    }

    func calculateGameLogic() {
        if let seeded = duelGoalRotations {
            goalRotations = seeded
            hud.setGoalFlips(flips: goalRotations)
            return
        }

        let diveHeight = (GameState.shared.platformHeight * GameState.shared.metrics.scaleFactorHeight)
        let time = approximateFallTime(from: diveHeight, to: waterLevel, gravity: Game.gravity) / 10

        let totalRotation = time * (Game.maxSpinVelocity * 0.70)
        let maxFlips = totalRotation / (2 * Double.pi)
        let halfFlips = Int(maxFlips * 2)

        guard halfFlips >= 1 else {
            goalRotations = 0.5
            hud.setGoalFlips(flips: goalRotations)
            return
        }

        let streak = GameState.shared.streak
        let streakFactor = min(0.7, Double(streak) / 30.0)
        let minHalfFlips = max(1, min(halfFlips, Int(Double(halfFlips) * streakFactor)))
        let randomHalfFlips = Double(Int.random(in: minHalfFlips...halfFlips)) / 2.0

        goalRotations = randomHalfFlips
        hud.setGoalFlips(flips: goalRotations)

        logger.debug("DiveHeight: \(diveHeight), Time: \(time), Total Rotation: \(totalRotation), Max Flips: \(maxFlips), Half-Flips: \(halfFlips), Streak: \(streak), Min Half-Flips: \(minHalfFlips), Goal Rotations: \(self.goalRotations)")
    }

    static func duelParams(seed: String) -> (platformHeight: Double, boardHeightMeters: Double, goalRotations: Double) {
        var rng = SeededRandom(seed: seed)
        let platformHeight = rng.nextDouble(in: 703...19000)
        let boardHeightMeters = round(platformHeight / 200.0 * 10) / 10

        let referenceScaleFactorHeight = 783.0 / Double(Game.defaultHeight)
        let diveHeight = platformHeight * referenceScaleFactorHeight
        let time = sqrt(2 * diveHeight / Double(Game.gravity)) / 10
        let totalRotation = time * (Double(Game.maxSpinVelocity) * 0.70)
        let halfFlips = Int((totalRotation / (2 * Double.pi)) * 2)
        let goal = halfFlips >= 1 ? Double(rng.nextInt(in: 1...halfFlips)) / 2.0 : 0.5
        return (platformHeight, boardHeightMeters, goal)
    }

    func setupScene() {
        setupLandscapeAndPool()

        waterLevel = ((256 * GameState.shared.metrics.scaleFactorHeight)/2) + 1

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

        setupClimbDave()

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
        var currentMeter = 1
        let majorSpacing = 200.0 * GameState.shared.metrics.scaleFactorHeight
        let minorSpacing = 20.0 * GameState.shared.metrics.scaleFactorHeight
        let maxY = springboard.position.y

        var majorCounter = 0.0
        var minorCounter = 0.0

        while y < maxY {
            var labelColor: SKColor = Game.customRed
            if currentMeter < 25 {
                labelColor = Game.customYellow
            }
            if currentMeter < 10 {
                labelColor = Game.customGreen
            }

            let labelPosition = CGPoint(x: 5*GameState.shared.metrics.width/6, y: CGFloat(y))
            let formattedHeight = String(currentMeter)

            if majorCounter >= majorSpacing {
                let label = createLabel(text: "- \(formattedHeight)m", fontSize: 20, position: labelPosition, zPosition: 10, fontColor: labelColor, bold: true)
                label.isHidden = false
                addChild(label)
                majorCounter = 0.0
                currentMeter += 1
            }
            else if minorCounter >= minorSpacing {
                let marker = createLabel(text: "-", fontSize: 20, position: labelPosition, zPosition: 10, fontColor: labelColor)
                marker.isHidden = false
                addChild(marker)
                minorCounter = 0.0
            }

            y += GameState.shared.metrics.scaleFactorHeight

            majorCounter += GameState.shared.metrics.scaleFactorHeight
            minorCounter += GameState.shared.metrics.scaleFactorHeight
        }
    }

    func resetScene() {
        if GameState.shared.duelSeed != nil { return }
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
        let newScene = DiveScene(size: self.size)
        newScene.scaleMode = self.scaleMode
        self.view?.presentScene(newScene, transition: SKTransition.fade(withDuration: 0.5))
    }

    func setupClimbDave() {
        climbdave = AnimatedSprite(spritesheetName: "divedave-spritesheet-extruded",
                              frameWidth: Game.defaultDaveHeight,
                              frameHeight: Game.defaultDaveHeight,
                              margin: 1,
                              spacing: 2,
                              scale: sfw)
        climbdave.position = CGPoint(x: GetOut.climbX * sfw, y: GetOut.deckYUp * sfw)
        climbdave.zPosition = 5
        climbdave.isHidden = true

        addChild(climbdave)

        climbdave.defineAnimation(name: "walk", frameIndices: [5, 6, 7, 8], timePerFrame: 0.125)
        climbdave.defineAnimation(name: "climb", frameIndices: [20, 21, 22, 23], timePerFrame: 0.125)
    }

    func setupSpringboard() {
        springboard = AnimatedSprite(spritesheetName: "board", frameWidth: 440, frameHeight: 64, scale: GameState.shared.metrics.scaleFactorHeight)
        springboard.position = CGPoint(x: platformTop.position.x + platformTop.size.width / 3, y: platformTop.position.y)
        springboard.zPosition = 10

        springboard.defineAnimation(name: "flex", frameIndices: [0, 1, 0], timePerFrame: 0.25, repeatForever: false)

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

        splash.defineAnimation(name: "splash", frameIndices: [0, 1, 2, 3, 4, 5, 6, 7], timePerFrame: 0.125, repeatForever: false)
        addChild(splash)
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let bodies = (contact.bodyA.categoryBitMask, contact.bodyB.categoryBitMask)
        let isDaveBoard =
            (bodies == (PhysicsCategory.dave.rawValue, PhysicsCategory.springboard.rawValue)) ||
            (bodies == (PhysicsCategory.springboard.rawValue, PhysicsCategory.dave.rawValue))
        guard isDaveBoard else { return }

        Haptics.impact(.light)
        boardContact.didBegin(daveDidContactBoard: true)

        guard davePlayer.state == .airborne, davePlayer.isCleanLanding() else { return }

        guard davePlayer.transition(to: .grounded) else { return }
        handleLanded()
    }

    private func handleLanded() {
        dave.zRotation = 0
        dave.physicsBody?.angularVelocity = 0

        rotationTracker.reset()

        davePlayer.landedAt = CACurrentMediaTime()
        dave.playAnimation(name: "idle")
        logger.debug("LANDED AT \(self.davePlayer.landedAt)")
        pulseSpringboardBoostWindow()

        // Input buffer: if jump was released SHORTLY BEFORE landing (within
        // ~265 ms — same as the relaxed OK window), fire the jump automatically.
        let timeSinceRelease = (davePlayer.landedAt - GameState.shared.jumpReleasedAt) * 1000
        if GameState.shared.jumpReleasedAt > 0,
           timeSinceRelease > 0,
           timeSinceRelease < 265 {
            triggerJump()
        }
    }

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

    // Pulse springboard green (perfect 50ms) -> yellow (good +50ms) -> red
    // (ok +75ms) -> fade. Thresholds mirror DavePlayer.calculateBoost.
    private func pulseSpringboardBoostWindow() {
        springboard.removeAction(forKey: "boostWindowPulse")
        springboard.color = Game.customGreen
        springboard.colorBlendFactor = 0.6
        let pulse = SKAction.sequence([
            SKAction.wait(forDuration: 0.05),
            SKAction.run { [weak self] in self?.springboard.color = Game.customYellow },
            SKAction.wait(forDuration: 0.05),
            SKAction.run { [weak self] in self?.springboard.color = Game.customRed },
            SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.075)
        ])
        springboard.run(pulse, withKey: "boostWindowPulse")
    }

    func didEnd(_ contact: SKPhysicsContact) {
        let bodies = (contact.bodyA.categoryBitMask, contact.bodyB.categoryBitMask)
        let isDaveBoard =
            (bodies == (PhysicsCategory.dave.rawValue, PhysicsCategory.springboard.rawValue)) ||
            (bodies == (PhysicsCategory.springboard.rawValue, PhysicsCategory.dave.rawValue))
        guard isDaveBoard else { return }

        boardContact.didEnd(daveDidContactBoard: true)

        if davePlayer.state == .grounded {
            davePlayer.transition(to: .airborne)
        }
    }

    func setupLandscapeAndPool() {
        let landscape = SKSpriteNode(imageNamed: "landscape")
        let aspectRatio = landscape.size.width / landscape.size.height

        landscape.size = CGSize(width: GameState.shared.metrics.width, height: GameState.shared.metrics.width / aspectRatio)
        landscape.position = CGPoint(x: GameState.shared.metrics.width / 2, y: landscape.size.height / 2)
        landscape.zPosition = 1
        addChild(landscape)
        landscapeHeight = landscape.size.height

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
            spritesheetName: "divedave-spritesheet_gettingout",
            frameWidth: 256,
            frameHeight: 256,
            margin: 0,
            spacing: 0,
            scale: sfw
        )

        gettingoutdave.defineAnimation(name: "getOut", frameIndices: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], timePerFrame: 0.1, repeatForever: false)

        gettingoutdave.position = CGPoint(x: GetOut.ladderX * sfw, y: GetOut.emergeYUp * sfw)
        gettingoutdave.zPosition = 7
        gettingoutdave.isHidden = true
        addChild(gettingoutdave)

        poolLadder = SKSpriteNode(imageNamed: "ladder")
        poolLadder.setScale(GetOut.ladderScale * sfw)
        poolLadder.position = CGPoint(x: GetOut.ladderX * sfw, y: GetOut.ladderYUp * sfw)
        poolLadder.zPosition = 8
        poolLadder.isHidden = true
        addChild(poolLadder)
    }


    func playerHandler(currentTime: TimeInterval) {
        guard davePlayer != nil else { return }

        davePlayer.applyDamping()
        checkForReset()
        if davePlayer.state != .launching {
            playerMobileMovementHandler()
            davePlayer.updateFrame(tucked: rotationTracker.tucked, currentTime: currentTime)
        }
    }


    func playerMobileMovementHandler() {
        if !diveComplete {
            // Jump stays enabled through .airborne so the early-release buffer
            // in handleLanded has a visually-tappable target.
            let jumpEnabled = davePlayer.state == .grounded || davePlayer.state == .airborne
            let flipEnabled = davePlayer.state == .airborne || davePlayer.state == .diving
            hud?.updateButtons(jumpEnabled: jumpEnabled, flipEnabled: flipEnabled)
        }

        let anyDown = hud?.leftButton.isDown == true || hud?.rightButton.isDown == true ||
                      hud?.jumpButton.isDown == true || hud?.flipButton.isDown == true

        guard anyDown else {
            rotationTracker.resetTuck()
            return
        }
        guard !diveComplete else { return }

        if hud?.leftButton.isDown == true {
            dave.physicsBody?.velocity.dx = -Game.daveSpeed
        }
        if hud?.rightButton.isDown == true {
            dave.physicsBody?.velocity.dx = Game.daveSpeed
        }

        switch davePlayer.state {
        case .grounded:
            if hud?.jumpButton.isDown == true && boardContact.isTouching {
                triggerJump()
            }
        case .airborne, .diving:
            if hud?.flipButton.isDown == true {
                if rotationTracker.tucked {
                    rotationTracker.incrementSpin()
                } else {
                    rotationTracker.beginTuck()
                    if davePlayer.state == .airborne {
                        davePlayer.transition(to: .diving)
                    }
                }
                dave.physicsBody?.angularVelocity = -rotationTracker.currentVelocity
            }
        case .launching, .splashed:
            break
        }
    }

    func checkForReset() {
        guard !diveComplete else { return }
        guard davePlayer.state == .airborne || davePlayer.state == .diving else { return }

        if dave.position.y < waterLevel {
            davePlayer.transition(to: .splashed)
            Haptics.impact(.heavy)
            diveComplete = true
                splash.position = CGPoint(x: dave.position.x, y: waterLevel + 100*GameState.shared.metrics.scaleFactorHeight)
                splash.isHidden = false
                splash.playAnimation(name: "splash") {
                    self.splash.isHidden = true
                    self.splash.clearCurrentAnimation()
                }
                cameraController.shake(intensity: 14 * GameState.shared.metrics.scaleFactorHeight, duration: 0.3)

                GameState.shared.stats.height = calculateHeightFromWater()
                GameState.shared.stats.angle = round(dave.zRotation * (180.0 / .pi) * 10.0) / 10
                GameState.shared.stats.tucked = rotationTracker.tucked
                GameState.shared.stats.tuckCount = rotationTracker.tuckCount
                GameState.shared.stats.rotations = round(rotationTracker.totalRotations * 10) / 10

                logger.debug("stats: \(String(describing: GameState.shared.stats))")

                let result = scoreDive()
                Haptics.notify(result == "FAILED DIVE" ? .error : .success)
                if GameState.shared.duelSeed != nil {
                    onDuelComplete?(GameState.shared.totalScore)
                }
                hud.setRunningStreak(streak: GameState.shared.streak)
                hud.setRunningScore(score: GameState.shared.totalScore)
                let displayStrings = [
                    "height: \(GameState.shared.stats.height)m",
                    "entry angle: \(GameState.shared.stats.angle)",
                    "rotations: \(GameState.shared.stats.rotations)"
                ]

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.info.display(result: result, strings: displayStrings, frame: GameState.shared.stats.emotionFrame, scores: GameState.shared.stats.scores)
                    self.hud.setVisible(false)
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.readyForReset = true
                    self.startGettingOut()
                }
        }

        countRotations()
    }

    func calculateHeightFromWater() -> Double {
        return DiveScorer.heightInMeters(
            springboardY: springboard.position.y,
            waterY: waterLevel,
            scaleFactorHeight: GameState.shared.metrics.scaleFactorHeight
        )
    }

    private func showBoostTimingFeedback(_ timing: BoostTiming) {
        let text: String
        let color: SKColor
        switch timing {
        case .perfect: text = "PERFECT!"; color = Game.customGreen
        case .good:    text = "GOOD";     color = Game.customYellow
        case .ok:      text = "OK";       color = Game.customRed
        case .miss:    return
        }

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

        let container = SKNode()
        container.position = dave.position
        container.zPosition = 4
        container.alpha = 0
        container.setScale(0.3)

        let shadow = SKLabelNode(text: text)
        shadow.fontName = "Arial-BoldMT"
        shadow.fontSize = 60
        shadow.fontColor = .black
        shadow.position = CGPoint(x: 4, y: -4)
        container.addChild(shadow)

        let main = SKLabelNode(text: text)
        main.fontName = "Arial-BoldMT"
        main.fontSize = 60
        main.fontColor = fontColor
        container.addChild(main)

        addChild(container)

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

            StatsStore.longestStreak = max(StatsStore.longestStreak, GameState.shared.streak)

            if GameState.shared.challengeMode {
                StatsStore.challengeHigh = max(StatsStore.challengeHigh, GameState.shared.totalScore)
            } else {
                StatsStore.arcadeHigh = max(StatsStore.arcadeHigh, GameState.shared.totalScore)
            }

            if GameState.shared.challengeMode && GameState.shared.totalScore > GameState.shared.highScore {
                GameState.shared.highScore = GameState.shared.totalScore
                highScoreSession = true

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
        playerHandler(currentTime: currentTime)
        applyPhaserStyleAngularDrag(currentTime: currentTime)
        updateGettingOut(currentTime: currentTime)
        updateBoardCollisionGuard()
        if let davePos = dave?.position {
            cameraController.follow(targetY: davePos.y)
            atmosphere.updateBackgroundColor(for: cameraController.node.position.y)
        }
        atmosphere.update()
    }

    // Once Dave has dropped past the board entirely, drop board collisions
    // so he can't walk off the side, drift back, and tip onto the board's
    // side or get pinned by it. Threshold is the board's *bottom* edge
    // (one full board-height of slack past the top) so floating-point
    // overlap during contact resolution at launch/landing doesn't
    // false-trigger.
    private func updateBoardCollisionGuard() {
        guard davePlayer?.state == .airborne else { return }
        guard let dave = dave, let board = springboard else { return }
        let daveBottom = dave.position.y - dave.size.height / 2
        let boardBottom = board.position.y - board.size.height / 2
        if daveBottom < boardBottom {
            dave.physicsBody?.collisionBitMask = 0
            dave.physicsBody?.contactTestBitMask = 0
        }
    }

    func applyPhaserStyleAngularDrag(currentTime: TimeInterval) {
        guard let body = dave.physicsBody else { return }
        rotationTracker.applyAngularDrag(to: body, currentTime: currentTime)
    }

    func startGettingOut() {
        goState = .emerge
        gettingoutdave.isHidden = false
        poolLadder.isHidden = true
        gettingoutdave.playAnimation(name: "getOut") { [weak self] in
            guard let self else { return }
            self.gettingoutdave.isHidden = true
            self.climbdave.position = CGPoint(x: GetOut.ladderX * self.sfw, y: GetOut.deckYUp * self.sfw)
            self.climbdave.xScale = -self.sfw
            self.climbdave.texture = self.climbdave.frames[4]
            self.climbdave.isHidden = false
            self.startTurn(.turn1)
        }
    }

    private func startTurn(_ which: GetOutState) {
        goState = which
        goTurnElapsed = 0
        if which == .turn1 {
            goTurnFrames = [4, 3, 2]
            goTurnFlips = [true, true, true]
        } else {
            goTurnFrames = [2, 1, 0, 1, 2]
            goTurnFlips = [true, true, false, false, false]
        }
    }

    func updateGettingOut(currentTime: TimeInterval) {
        if goLastTime == 0 { goLastTime = currentTime }
        let dt = currentTime - goLastTime
        goLastTime = currentTime
        switch goState {
        case .turn1, .turn2:
            advanceTurn(dt)
        case .walk:
            advanceWalk(dt)
        case .climb:
            advanceClimb(dt)
        default:
            break
        }
        updateLadderOverlay()
    }

    private func advanceTurn(_ dt: TimeInterval) {
        goTurnElapsed += dt
        let step = Int(goTurnElapsed / GetOut.turnFrameDuration)
        if step >= goTurnFrames.count {
            if goState == .turn1 {
                goState = .walk
                climbdave.xScale = -sfw
                climbdave.playAnimation(name: "walk")
            } else {
                goState = .climb
                climbdave.stopAnimation()
                climbdave.xScale = sfw
                climbdave.position.x = GetOut.climbX * sfw - GetOut.climbXNudge
                climbdave.playAnimation(name: "climb")
            }
            return
        }
        climbdave.texture = climbdave.frames[goTurnFrames[step]]
        climbdave.xScale = goTurnFlips[step] ? -sfw : sfw
    }

    private func advanceWalk(_ dt: TimeInterval) {
        climbdave.position.x -= GetOut.walkSpeed * sfw * CGFloat(dt)
        if climbdave.position.x <= GetOut.climbX * sfw {
            climbdave.position.x = GetOut.climbX * sfw
            climbdave.stopAnimation()
            startTurn(.turn2)
        }
    }

    private func advanceClimb(_ dt: TimeInterval) {
        guard platformTop != nil else { return }
        climbdave.position.y += GetOut.climbSpeed * sfw * CGFloat(dt)
        if climbdave.position.y >= platformTop.position.y {
            climbdave.position.y = platformTop.position.y
            climbdave.stopAnimation()
            climbdave.texture = climbdave.frames[20]
            goState = .done
        }
    }

    private func updateLadderOverlay() {
        switch goState {
        case .turn1:
            poolLadder.isHidden = false
        case .walk:
            let overlap = climbdave.position.x > (GetOut.ladderX - GetOut.ladderOverlapPx) * sfw
            poolLadder.isHidden = !overlap
        default:
            poolLadder.isHidden = true
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
        self.view!.presentScene(mainMenuScene, transition: SKTransition.crossFade(withDuration: 0.5))
    }
}
