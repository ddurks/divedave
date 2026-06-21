import SpriteKit
import os

private let logger = Logger(subsystem: "com.drawvid.divedave", category: "menu")

final class MainMenuScene: SKScene {
    private var startArcadeButton: MenuButton!
    private var startChallengeButton: MenuButton!
    private var instructionsButton: MenuButton!
    private var loadingLabel: SKLabelNode!
    private var coverImage: SKSpriteNode!
    private var instructionPanel: SKSpriteNode!
    private var instructionsImage: SKSpriteNode!
    private var isShowingInstructions = false
    private var userClickedStart = false
    private var loadingDave: SKSpriteNode!
    private var menuDave: MenuDave?

    func setupMenu() {
        coverImage = SKSpriteNode(imageNamed: "cover")
        coverImage.position = CGPoint(x: self.size.width / 2, y: self.size.height * 0.55)
        coverImage.size.width = self.size.width * 0.78
        coverImage.size.height = self.size.width * 0.78
        coverImage.zPosition = 1
        addChild(coverImage)

        startArcadeButton = MenuButton(imageNamed: "arcade",
                                       position: CGPoint(x: self.size.width / 2 + self.size.width / 5, y: self.size.height * 0.22),
                                       scale: 0.75 * GameState.shared.metrics.scaleFactorHeight,
                                       name: "startArcade") { [weak self] in
            self?.startGame(challengeMode: false)
        }
        addChild(startArcadeButton)

        startChallengeButton = MenuButton(imageNamed: "challenge",
                                          position: CGPoint(x: self.size.width / 2 - self.size.width / 5, y: self.size.height * 0.22),
                                          scale: 0.75 * GameState.shared.metrics.scaleFactorHeight,
                                          name: "startChallenge") { [weak self] in
            self?.startGame(challengeMode: true)
        }
        addChild(startChallengeButton)

        setUpLoadingStuff()
        setupInstructions()

        let bestScore = max(StatsStore.arcadeHigh, StatsStore.challengeHigh, GameState.shared.highScore)
        if bestScore > 0 {
            displayHighScore(bestScore)
            displayMetaStats()
        }

        setupMenuDave()
    }

    private func setupMenuDave() {
        let scale = GameState.shared.metrics.scaleFactorHeight
        // Feet sit at the frame's bottom edge, so a half-frame above the floor
        // puts his bottom edge flush with the bottom of the screen.
        let y = (Game.defaultDaveHeight * scale) / 2
        menuDave = MenuDave(scene: self,
                            y: y,
                            leftBound: self.size.width * 0.15,
                            rightBound: self.size.width * 0.85,
                            speed: 120 * GameState.shared.metrics.scaleFactorHeight,
                            scale: scale)
    }

    override func update(_ currentTime: TimeInterval) {
        menuDave?.update(currentTime)
    }

    func setUpLoadingStuff() {
        loadingLabel = SKLabelNode(text: "loading...")
        loadingLabel.fontName = "Arial-BoldMT"
        loadingLabel.fontSize = 30
        loadingLabel.fontColor = .white
        loadingLabel.position = CGPoint(x: self.size.width / 2, y: startArcadeButton.position.y)
        loadingLabel.zPosition = 3
        loadingLabel.isHidden = true;
        addChild(loadingLabel)

        let crouch = AnimatedSprite(spritesheetName: "divedave-spritesheet-extruded",
                                    frameWidth: Game.defaultDaveHeight,
                                    frameHeight: Game.defaultDaveHeight,
                                    margin: 1,
                                    spacing: 2,
                                    scale: GameState.shared.metrics.scaleFactorHeight)
        crouch.texture = crouch.frames[10]
        loadingDave = crouch
        loadingDave.position = CGPoint(x: loadingLabel.position.x, y: loadingLabel.position.y + loadingDave.size.height)
        loadingDave.isHidden = true;
        addChild(loadingDave)
    }

    func setupInstructions() {
        // Tuck into the true top-right corner: anchor the button's frame a
        // small margin from the screen edges (the artwork's own transparent
        // padding supplies the rest of the visual gap).
        let cornerMargin: CGFloat = 10
        instructionsButton = MenuButton(imageNamed: "controls-help",
                                        position: .zero,
                                        scale: 0.75 * GameState.shared.metrics.scaleFactorHeight,
                                        name: "instructionsButton") { [weak self] in
            self?.showInstructions()
        }
        instructionsButton.position = CGPoint(
            x: self.size.width - cornerMargin - instructionsButton.frame.width / 2,
            y: self.size.height * 0.95 - instructionsButton.frame.height / 2
        )
        addChild(instructionsButton)

        instructionPanel = SKSpriteNode(imageNamed: "panel")
        let aspectRatio = instructionPanel.size.width / instructionPanel.size.height
        instructionPanel.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
        instructionPanel.size = CGSize(width: GameState.shared.metrics.width, height: GameState.shared.metrics.width / aspectRatio)
        instructionPanel.zPosition = 5
        instructionPanel.isHidden = true
        addChild(instructionPanel)

        instructionsImage = SKSpriteNode(imageNamed: "controls")
        instructionsImage.size = CGSize(width: GameState.shared.metrics.width, height: GameState.shared.metrics.width / aspectRatio)
        instructionsImage.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
        instructionsImage.zPosition = 6
        instructionsImage.isHidden = true
        addChild(instructionsImage)
    }

    func showInstructions() {
        guard !isShowingInstructions else { return }
        isShowingInstructions = true

        instructionPanel.isHidden = false
        instructionsImage.isHidden = false
    }

    func hideInstructions() {
        guard isShowingInstructions else { return }
        isShowingInstructions = false

        instructionPanel.isHidden = true
        instructionsImage.isHidden = true
    }

    func startGame(challengeMode: Bool) {
        logger.debug("Start Game")
        showLoadingLabel()
        GameState.shared.challengeMode = challengeMode
        let gameScene = DiveScene(size: CGSize(width: self.size.width, height: self.size.height))
        gameScene.scaleMode = .aspectFit
        DispatchQueue.main.async {
            self.view?.presentScene(gameScene, transition: SKTransition.fade(withDuration: 0.5))
        }
    }

    func showLoadingLabel() {
        startArcadeButton.isHidden = true
        startChallengeButton.isHidden = true
        loadingLabel.isHidden = false
        loadingDave.isHidden = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        // While the controls splash is up, any tap dismisses it (and is not
        // forwarded to the menu buttons) — matches the web behavior.
        if isShowingInstructions {
            hideInstructions()
            return
        }
        let touchedNode = self.atPoint(touch.location(in: self))
        if let button = touchedNode as? MenuButton {
            button.triggerAction()
        }
    }

    private func displayMetaStats() {
        let sign = SKSpriteNode(imageNamed: "sign-xl")
        sign.setScale(GameState.shared.metrics.scaleFactorHeight * 2)
        let signBottom = GameState.shared.metrics.height - (5 * sign.size.height / 8)
        let baseX = sign.size.width / 1.5
        let baseY = signBottom - (40 * GameState.shared.metrics.scaleFactorHeight * 2)
        let lineSpacing: CGFloat = 28 * GameState.shared.metrics.scaleFactorHeight * 2

        let streakLabel = SKLabelNode(fontNamed: "Arial")
        streakLabel.text = "LONGEST STREAK: \(StatsStore.longestStreak)"
        streakLabel.fontColor = .black
        streakLabel.fontSize = 18 * GameState.shared.metrics.scaleFactorHeight * 2
        streakLabel.position = CGPoint(x: baseX, y: baseY)
        streakLabel.zPosition = 24
        streakLabel.horizontalAlignmentMode = .center
        addChild(streakLabel)

        let divesLabel = SKLabelNode(fontNamed: "Arial")
        divesLabel.text = "TOTAL DIVES: \(StatsStore.totalDives)"
        divesLabel.fontColor = .black
        divesLabel.fontSize = 18 * GameState.shared.metrics.scaleFactorHeight * 2
        divesLabel.position = CGPoint(x: baseX, y: baseY - lineSpacing)
        divesLabel.zPosition = 24
        divesLabel.horizontalAlignmentMode = .center
        addChild(divesLabel)
    }

    private func displayHighScore(_ highScore: Int) {
        logger.debug("highScore: \(highScore)")
        let sign = SKSpriteNode(imageNamed: "sign-xl")
        sign.setScale(GameState.shared.metrics.scaleFactorHeight * 2)
        let signPosition = CGPoint(x: (sign.size.width / 1.5), y: GameState.shared.metrics.height - (sign.size.height / 8))
        sign.position = signPosition
        sign.zRotation = .pi
        sign.zPosition = 20
        addChild(sign)

        let challengeLabel = SKLabelNode(fontNamed: "Arial")
        challengeLabel.text = "YOUR CHALLENGE"
        challengeLabel.fontColor = .black
        challengeLabel.fontSize = 20 * GameState.shared.metrics.scaleFactorHeight * 2
        challengeLabel.position = CGPoint(x: (sign.size.width / 1.5), y: GameState.shared.metrics.height - (sign.size.height / 5) - (60 * GameState.shared.metrics.scaleFactorHeight * 2))
        challengeLabel.zPosition = 24
        challengeLabel.horizontalAlignmentMode = .center
        addChild(challengeLabel)

        let highScoreLabel = SKLabelNode(fontNamed: "Arial")
        highScoreLabel.text = "HIGH SCORE"
        highScoreLabel.fontColor = .black
        highScoreLabel.fontSize = 30 * GameState.shared.metrics.scaleFactorHeight * 2
        highScoreLabel.position = CGPoint(x: (sign.size.width / 1.5), y: GameState.shared.metrics.height - (sign.size.height / 5) - (90 * GameState.shared.metrics.scaleFactorHeight * 2))
        highScoreLabel.zPosition = 24
        highScoreLabel.horizontalAlignmentMode = .center
        addChild(highScoreLabel)

        let scoreLabel = SKLabelNode(fontNamed: "Arial")
        scoreLabel.text = "\(highScore)"
        scoreLabel.fontColor = .black
        scoreLabel.fontSize = 50 * GameState.shared.metrics.scaleFactorHeight * 2
        scoreLabel.position = CGPoint(x: (sign.size.width / 1.5), y: GameState.shared.metrics.height - (sign.size.height / 5) - (150 * GameState.shared.metrics.scaleFactorHeight * 2))
        scoreLabel.zPosition = 24
        scoreLabel.horizontalAlignmentMode = .center
        addChild(scoreLabel)
    }
}

// A decorative Dave that paces back and forth between two x bounds, reusing the
// gameplay walk cycle and the direction-change turn pivot. Purely cosmetic;
// driven by the scene's update(_:). Mirrors the web MenuDave — keep in sync.
@MainActor
final class MenuDave {
    private let sprite: AnimatedSprite
    private let leftBound: CGFloat
    private let rightBound: CGFloat
    private let speed: CGFloat            // points per second
    private let baseScale: CGFloat
    private let walkFrames = [5, 6, 7, 8]
    private let walkFrameDuration: TimeInterval = 0.125
    private let turnFrameDuration: TimeInterval = 0.05

    private var dir: CGFloat = 1
    private var lastTime: TimeInterval = 0
    private var walkAccum: TimeInterval = 0
    private var walkIndex = 0
    private var turning = false
    private var turnStart: TimeInterval = 0
    private var turnViaBack = false
    private var turnFrom: CGFloat = 1
    private var turnTo: CGFloat = 1

    init(scene: SKScene, y: CGFloat, leftBound: CGFloat, rightBound: CGFloat, speed: CGFloat, scale: CGFloat) {
        self.leftBound = leftBound
        self.rightBound = rightBound
        self.speed = speed
        self.baseScale = scale
        sprite = AnimatedSprite(spritesheetName: "divedave-spritesheet-extruded",
                                frameWidth: Game.defaultDaveHeight,
                                frameHeight: Game.defaultDaveHeight,
                                margin: 1, spacing: 2, scale: scale)
        sprite.position = CGPoint(x: leftBound, y: y)
        sprite.zPosition = 2
        sprite.texture = sprite.frames[walkFrames[0]]
        scene.addChild(sprite)
    }

    func update(_ currentTime: TimeInterval) {
        if lastTime == 0 { lastTime = currentTime }
        let dt = currentTime - lastTime
        lastTime = currentTime
        if turning { advanceTurn(currentTime); return }
        sprite.position.x += dir * speed * CGFloat(dt)
        sprite.xScale = dir < 0 ? -baseScale : baseScale
        walkAccum += dt
        if walkAccum >= walkFrameDuration {
            walkAccum -= walkFrameDuration
            walkIndex = (walkIndex + 1) % walkFrames.count
            sprite.texture = sprite.frames[walkFrames[walkIndex]]
        }
        if (dir > 0 && sprite.position.x >= rightBound) || (dir < 0 && sprite.position.x <= leftBound) {
            startTurn(currentTime)
        }
    }

    private func startTurn(_ t: TimeInterval) {
        turning = true
        turnStart = t
        turnViaBack = Bool.random()
        turnFrom = dir
        turnTo = -dir
        advanceTurn(t)
    }

    private func advanceTurn(_ t: TimeInterval) {
        let mid = turnViaBack ? 3 : 1
        let pivot = turnViaBack ? 4 : 0
        let frames = [2, mid, pivot, mid, 2]
        let dirs = [turnFrom, turnFrom, turnFrom, turnTo, turnTo]
        let step = Int((t - turnStart) / turnFrameDuration)
        if step >= frames.count {
            turning = false
            dir = turnTo
            walkAccum = 0
            walkIndex = 0
            sprite.xScale = dir < 0 ? -baseScale : baseScale
            sprite.texture = sprite.frames[walkFrames[0]]
            return
        }
        sprite.xScale = dirs[step] < 0 ? -baseScale : baseScale
        sprite.texture = sprite.frames[frames[step]]
    }
}
