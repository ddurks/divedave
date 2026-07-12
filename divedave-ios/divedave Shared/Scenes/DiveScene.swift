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

// Mirror of divedave-web GETTING_OUT, authored in the fixed 1250-wide world.
private enum GetOut {
    static let ladderX: CGFloat = 937
    static let ladderYUp: CGFloat = 191
    static let ladderScale: CGFloat = 0.87
    static let emergeYUp: CGFloat = 207
    static let deckYUp: CGFloat = 325
    static let walkSpeed: CGFloat = 450
    static let turnFrameDuration: TimeInterval = 0.07
    static let climbX: CGFloat = 28
    static let climbSpeed: CGFloat = 200
    static let climbOffsetX: CGFloat = 25
    static let ladderOverlapPx: CGFloat = 70
}

private enum GetOutState { case idle, emerge, turn1, walk, turn2, climb, done }

final class DiveScene: SKScene, SKPhysicsContactDelegate {
    private var readyForReset = false
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

    // Where Dave climbs the tower — the authored x in the fixed world (matches web).
    private var climbTargetX: CGFloat { GetOut.climbX }

    override func didMove(to view: SKView) {
        physicsWorld.gravity = CGVector(dx: 0, dy: -Game.gravity)
        physicsWorld.contactDelegate = self
        self.backgroundColor = SKColor(red: 0.74, green: 0.84, blue: 1.0, alpha: 1.0)
        diveComplete = false
        let buffer = GameState.shared.metrics.height/2
        if (GameState.shared.platformHeight < GameState.shared.metrics.height - buffer) {
            GameState.shared.sceneHeight = GameState.shared.metrics.height
        } else {
            GameState.shared.sceneHeight = GameState.shared.platformHeight + buffer
        }
        setupScene()
        cameraController = CameraController(scene: self)
        setupHUD(view: view, camera: cameraController.node)
        setupInfoPanels()
        setupSpringboard()
        // Mirror web's jumpTop: extend the camera's upper clamp by the jump apex
        // so it keeps following Dave through the jump. Game.gravity is SpriteKit's
        // input (≈150 pt/m, see Constants); ×150 gives the world-space accel.
        let launchVelocity = Game.jumpVelocity + Game.maxBoost
        cameraController.maxFollowY =
            springboard.position.y + launchVelocity * launchVelocity / (2 * Game.gravity * 150)
        setupHeightLabels()
        davePlayer = DavePlayer(scene: self, springboard: springboard)
        setupSplash()
        calculateGameLogic()
        // Band boundaries at 30 m and 60 m above water (×200 units/m), matching
        // web's plane/star altitudes: clouds/birds below, planes 30–60 m, stars/ufos above.
        atmosphere = Atmosphere(scene: self, sceneHeight: GameState.shared.sceneHeight, startY: landscapeHeight, middleY: waterLevel + 6000, endY: waterLevel + 12000)

        // Seat the camera on Dave before the first frame; otherwise it renders
        // once at the scene origin and snaps upward on the first update().
        cameraController.follow(targetY: dave.position.y)
    }

    func setupHUD(view: SKView, camera: SKCameraNode) {
        logger.debug("self.size: \(self.size.debugDescription)")
        hud = HUD(view: view, camera: camera, sceneSize: self.size)
        hud.onMenuPressed = self.prepareAndPresentMainMenuScene
    }

    func calculateGameLogic() {
        let halfFlips = DiveScorer.goalHalfFlips(heightMeters: Double(GameState.shared.platformHeight) / 200.0)

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

        logger.debug("Half-Flips: \(halfFlips), Streak: \(streak), Min Half-Flips: \(minHalfFlips), Goal Rotations: \(self.goalRotations)")
    }

    func setupScene() {
        waterLevel = (256/2) + 1

        setupLandscapeAndPool()

        let platformX = GameState.shared.metrics.width / 7
        let platformTopPosition = CGPoint(x: platformX, y: waterLevel + GameState.shared.platformHeight)
        platformTop = SKSpriteNode(imageNamed: "platformtop")
        platformTop.position = platformTopPosition
        // Tower/board sit between the atmosphere (≤2) and the HUD sign/menu (3) so
        // the sign and menu button draw over them, while Dave (5) stays above the sign.
        platformTop.zPosition = 2.6
        addChild(platformTop)

        for i in stride(from: platformTop.position.y - platformTop.size.height, to: 200, by: -100) {
            let platformSection = SKSpriteNode(imageNamed: "platformsection")
            platformSection.position = CGPoint(x: platformTopPosition.x, y: i)
            platformSection.zPosition = 2.5
            addChild(platformSection)
        }

        let platformBase = SKSpriteNode(imageNamed: "platformbase")
        platformBase.position = CGPoint(x: platformTopPosition.x, y: 200)
        platformBase.zPosition = 2.6
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
        let majorSpacing = 200.0
        let minorSpacing = 20.0
        let maxY = springboard.position.y
        let markerX = 5 * GameState.shared.metrics.width / 6

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

            let labelPosition = CGPoint(x: markerX, y: CGFloat(y))
            let formattedHeight = String(currentMeter)

            if majorCounter >= majorSpacing {
                let label = createLabel(text: "- \(formattedHeight)m", fontSize: 70, position: labelPosition, zPosition: 10, fontColor: labelColor, bold: true)
                label.isHidden = false
                addChild(label)
                majorCounter = 0.0
                currentMeter += 1
            }
            else if minorCounter >= minorSpacing {
                let marker = createLabel(text: "-", fontSize: 70, position: labelPosition, zPosition: 10, fontColor: labelColor)
                marker.isHidden = false
                addChild(marker)
                minorCounter = 0.0
            }

            y += 1

            majorCounter += 1
            minorCounter += 1
        }
    }

    func resetScene() {
        if (self.diveComplete && self.readyForReset) {
            if (!GameState.shared.challengeMode) {
                // 3–100 m dive (platformHeight / 200 = metres); static so the
                // range matches every device and web.
                GameState.shared.platformHeight = Double.random(in: 600...20000)
                restartScene()
            } else {
                if (GameState.shared.totalScore == 0) {
                    GameState.shared.platformHeight = 600
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
                              spacing: 2)
        climbdave.position = CGPoint(x: GetOut.climbX, y: GetOut.deckYUp)
        // Climbs up behind the diving tower, so below the platform/board (2.5–2.7).
        climbdave.zPosition = 2.4
        climbdave.isHidden = true

        addChild(climbdave)

        climbdave.defineAnimation(name: "walk", frameIndices: [5, 6, 7, 8], timePerFrame: 0.125)
        climbdave.defineAnimation(name: "climb", frameIndices: [20, 21, 22, 23], timePerFrame: 0.125)
    }

    func setupSpringboard() {
        springboard = AnimatedSprite(spritesheetName: "board", frameWidth: 440, frameHeight: 64, margin: 1, spacing: 2)
        springboard.position = CGPoint(x: platformTop.position.x + platformTop.size.width / 3, y: platformTop.position.y)
        springboard.zPosition = 2.7

        // Board bounce frames keyed to boost timing (1 = OK, 2 = GOOD, 3 = PERFECT);
        // a non-notable (miss) bounce leaves the board at rest (frame 0). Mirrors divedave-web.
        springboard.defineAnimation(name: "bounceOk", frameIndices: [1, 0], timePerFrame: 0.25, repeatForever: false)
        springboard.defineAnimation(name: "bounceGood", frameIndices: [2, 0], timePerFrame: 0.25, repeatForever: false)
        springboard.defineAnimation(name: "bouncePerfect", frameIndices: [3, 0], timePerFrame: 0.25, repeatForever: false)

        springboard.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: springboard.size.width, height: springboard.size.height))
        springboard.physicsBody?.isDynamic = false
        springboard.physicsBody?.affectedByGravity = false
        springboard.physicsBody?.restitution = 0.0
        springboard.physicsBody?.friction = 0.0
        springboard.physicsBody?.categoryBitMask = PhysicsCategory.springboard.rawValue

        addChild(springboard)
    }

    func setupSplash() {
        splash = AnimatedSprite(spritesheetName: "splash", frameWidth: 256, frameHeight: 256)
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
                self?.cameraController.shake(intensity: 4, duration: 0.15)
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
        water.zPosition = 3
        addChild(water)
        water.playAnimation(name: "idle")

        let outerwater = AnimatedSprite(
            spritesheetName: "water",
            frameWidth: 1250,
            frameHeight: 200,
            margin: 0,
            spacing: 0,
            scale: 1.0
        )
        outerwater.defineAnimation(name: "idle", frameIndices: [0, 1, 2, 3], timePerFrame: 0.25)
        outerwater.size = water.size
        // Front band (z6 > Dave's z5) hides Dave once submerged: the back water
        // shifted down a quarter of the water height. Mirrors divedave-web, where the
        // front/back water centers differ by 50pt of the 200pt sprite (¼) — Dave
        // enters at the surface and goes under a quarter-height below it.
        outerwater.position = CGPoint(
            x: GameState.shared.metrics.width / 2,
            y: water.position.y - water.size.height / 4
        )
        outerwater.zPosition = 6
        addChild(outerwater)
        outerwater.playAnimation(name: "idle")

        gettingoutdave = AnimatedSprite(
            spritesheetName: "divedave-spritesheet_gettingout",
            frameWidth: 256,
            frameHeight: 256,
            margin: 0,
            spacing: 0
        )

        gettingoutdave.defineAnimation(name: "getOut", frameIndices: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], timePerFrame: 0.1, repeatForever: false)

        gettingoutdave.position = CGPoint(x: GetOut.ladderX, y: GetOut.emergeYUp)
        gettingoutdave.zPosition = 7
        gettingoutdave.isHidden = true
        addChild(gettingoutdave)

        poolLadder = SKSpriteNode(imageNamed: "ladder")
        poolLadder.setScale(GetOut.ladderScale)
        poolLadder.position = CGPoint(x: GetOut.ladderX, y: GetOut.ladderYUp)
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

        let walkSpeed = Game.daveSpeed
        if hud?.leftButton.isDown == true {
            dave.physicsBody?.velocity.dx = -walkSpeed
        }
        if hud?.rightButton.isDown == true {
            dave.physicsBody?.velocity.dx = walkSpeed
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
            diveComplete = true
                splash.position = CGPoint(x: dave.position.x, y: waterLevel + 100)
                splash.isHidden = false
                splash.playAnimation(name: "splash") {
                    self.splash.isHidden = true
                    self.splash.clearCurrentAnimation()
                }
                cameraController.shake(intensity: 14, duration: 0.3)

                GameState.shared.stats.height = calculateHeightFromWater()
                GameState.shared.stats.angle = round(dave.zRotation * (180.0 / .pi) * 10.0) / 10
                GameState.shared.stats.tucked = rotationTracker.tucked
                GameState.shared.stats.tuckCount = rotationTracker.tuckCount
                GameState.shared.stats.rotations = round(rotationTracker.totalRotations * 10) / 10

                logger.debug("stats: \(String(describing: GameState.shared.stats))")

                let result = scoreDive()
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
            waterY: waterLevel
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
            y: springboard.position.y + (springboard.size.height / 2) + 10
        )
        container.zPosition = 4
        container.alpha = 0
        container.setScale(0.3)

        let shadow = SKLabelNode(text: text)
        shadow.fontName = "DrawvidHand-Regular"
        shadow.fontSize = 88
        shadow.fontColor = .black
        shadow.position = CGPoint(x: 7, y: -7)
        container.addChild(shadow)

        let main = SKLabelNode(text: text)
        main.fontName = "DrawvidHand-Regular"
        main.fontSize = 88
        main.fontColor = color
        main.zPosition = 1 // keep above the black shadow; ignoresSiblingOrder leaves equal-zPosition order undefined
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

        let fontColor: SKColor = completed > Double(goalRotations) ? Game.customRed : Game.customGreen
        let text = "\(Int(completed))"

        let container = SKNode()
        container.position = dave.position
        container.zPosition = 4
        container.alpha = 0
        container.setScale(0.3)

        let shadow = SKLabelNode(text: text)
        shadow.fontName = "DrawvidHand-Regular"
        shadow.fontSize = 211
        shadow.fontColor = .black
        shadow.position = CGPoint(x: 14, y: -14)
        container.addChild(shadow)

        let main = SKLabelNode(text: text)
        main.fontName = "DrawvidHand-Regular"
        main.fontSize = 211
        main.fontColor = fontColor
        main.zPosition = 1 // keep above the black shadow; ignoresSiblingOrder leaves equal-zPosition order undefined
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
            resetScene()
        }
    }

    // Drive the on-screen HUD buttons from a hardware keyboard (handy in the
    // Simulator, and for iPad keyboards). Keys mirror divedave-web: A/← left,
    // D/→ right, Space/W/↑ jump, R/↓ flip, Enter advances after a dive, Esc
    // returns to the menu. Forwarded from GameViewController; returns true when
    // the key was consumed.
    @discardableResult
    func handleKey(_ keyCode: UIKeyboardHIDUsage, pressed: Bool) -> Bool {
        switch keyCode {
        case .keyboardReturnOrEnter, .keypadEnter:
            if pressed, diveComplete { resetScene() }
            return true
        case .keyboardEscape:
            if pressed { prepareAndPresentMainMenuScene() }
            return true
        default:
            guard let button = hudButton(for: keyCode) else { return false }
            if pressed { button.press() } else { button.release() }
            return true
        }
    }

    private func hudButton(for keyCode: UIKeyboardHIDUsage) -> ControlButton? {
        switch keyCode {
        case .keyboardA, .keyboardLeftArrow:                   return hud?.leftButton
        case .keyboardD, .keyboardRightArrow:                  return hud?.rightButton
        case .keyboardSpacebar, .keyboardW, .keyboardUpArrow:  return hud?.jumpButton
        case .keyboardR, .keyboardDownArrow:                   return hud?.flipButton
        default:                                               return nil
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
            self.climbdave.position = CGPoint(x: GetOut.ladderX, y: GetOut.deckYUp)
            self.climbdave.xScale = -1.0
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
                climbdave.xScale = -1.0
                climbdave.playAnimation(name: "walk")
            } else {
                goState = .climb
                climbdave.stopAnimation()
                climbdave.xScale = 1.0
                climbdave.position.x = climbTargetX - GetOut.climbOffsetX
                climbdave.playAnimation(name: "climb")
            }
            return
        }
        climbdave.texture = climbdave.frames[goTurnFrames[step]]
        climbdave.xScale = goTurnFlips[step] ? -1.0 : 1.0
    }

    private func advanceWalk(_ dt: TimeInterval) {
        climbdave.position.x -= GetOut.walkSpeed * CGFloat(dt)
        if climbdave.position.x <= climbTargetX {
            climbdave.position.x = climbTargetX
            climbdave.stopAnimation()
            startTurn(.turn2)
        }
    }

    private func advanceClimb(_ dt: TimeInterval) {
        guard platformTop != nil else { return }
        climbdave.position.y += GetOut.climbSpeed * CGFloat(dt)
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
            let overlap = climbdave.position.x > (GetOut.ladderX - GetOut.ladderOverlapPx)
            poolLadder.isHidden = !overlap
        default:
            poolLadder.isHidden = true
        }
    }

    func prepareAndPresentMainMenuScene() {
        let m = GameState.shared.metrics
        let mainMenuScene = MainMenuScene(size: CGSize(width: m.width, height: m.height))
        mainMenuScene.backgroundColor = SKColor(red: 0.74, green: 0.84, blue: 1.0, alpha: 1.0)
        mainMenuScene.scaleMode = .aspectFit
        mainMenuScene.setupMenu()
        self.diveComplete = true
        self.readyForReset = true
        GameState.shared.totalScore = 0
        GameState.shared.platformHeight = 600
        self.view?.presentScene(mainMenuScene, transition: SKTransition.crossFade(withDuration: 0.5))
    }
}
