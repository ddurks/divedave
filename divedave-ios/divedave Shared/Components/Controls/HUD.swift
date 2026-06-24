import SpriteKit

final class HUD {
    var leftButton: ControlButton
    var rightButton: ControlButton
    var jumpButton: ControlButton
    var flipButton: ControlButton
    var menuButton: ControlButton
    var onMenuPressed: ((() -> Void)?)
    var sign: SKSpriteNode!
    var goalLabel: SKLabelNode!
    var runningStreakLabel: SKLabelNode!
    var runningScoreLabel: SKLabelNode!
    var highScoreLabel: SKLabelNode!

    @MainActor
    init(view: SKView, camera: SKCameraNode, sceneSize: CGSize) {
        let jumpButtonY = -sceneSize.height * 0.425
        let buttonScale: CGFloat = 0.65

        let scaledButtonHeight = 512 * buttonScale
        let flipButtonY = jumpButtonY + scaledButtonHeight + 10

        let leftButtonX = -sceneSize.width * 0.35
        // Anchor the right button one button-width (+gap) from the left so the
        // movement pair keeps a fixed gap independent of viewport width — the
        // fixed-gap parity web gets from its absolute 175/450 placement.
        let rightButtonX = leftButtonX + scaledButtonHeight + 25
        let jumpButtonX = sceneSize.width * 0.35
        let flipButtonX = jumpButtonX

        leftButton = ControlButton(x: leftButtonX, y: jumpButtonY, spriteType: .staticSprite(textureName: "controls-left"), scale: buttonScale)
        rightButton = ControlButton(x: rightButtonX, y: jumpButtonY, spriteType: .staticSprite(textureName: "controls-right"), scale: buttonScale)
        jumpButton = ControlButton(x: jumpButtonX, y: jumpButtonY, spriteType: .staticSprite(textureName: "controls-jump"), scale: buttonScale)
        flipButton = ControlButton(x: flipButtonX, y: flipButtonY, spriteType: .staticSprite(textureName: "controls-flip"), scale: buttonScale)

        camera.addChild(leftButton)
        camera.addChild(rightButton)
        camera.addChild(jumpButton)
        camera.addChild(flipButton)

        goalLabel = SKLabelNode(text: "GOAL:")
        goalLabel.fontName = "DrawvidHand-Regular"
        goalLabel.fontColor = SKColor(red: 0/255, green: 128/255, blue: 0/255, alpha: 1.0)
        goalLabel.fontSize = 65
        goalLabel.position = CGPoint(x: (4*sceneSize.width/2)/5, y: (4*sceneSize.height/2)/5)
        goalLabel.horizontalAlignmentMode = .right
        goalLabel.zPosition = 20
        camera.addChild(goalLabel)

        // iOS uses the tall "sign-xl" (256×512: board + a long downward post).
        // Rotated π, the post hangs up behind the status bar / notch while the
        // readable board drops below it — clear of the iOS clock. Shown at 1.5×
        // web's size (deliberate native bump); board, fonts, offsets and the menu
        // button all scale together via signScale.
        let signScale: CGFloat = 1.5
        // Keep the board's left edge tucked ~3 units off-screen (web's look) as it
        // scales: half-board (128·signScale) minus 3, in camera-space (origin centre).
        let hudX = 128 * signScale - 3 - sceneSize.width / 2
        let boardCenterY = sceneSize.height / 2 - 260
        // Board centre sits ~141·signScale below the sprite's centre in the frame.
        let boardOffsetInSprite: CGFloat = 141 * signScale
        sign = SKSpriteNode(imageNamed: "sign-xl")
        sign.setScale(signScale)
        sign.position = CGPoint(x: hudX, y: boardCenterY + boardOffsetInSprite)
        sign.zRotation = .pi
        // Above the atmosphere (≤ z2) but below Dave (z5), so Dave stays visible
        // when his dive arc overlaps the sign/menu. Score/streak labels sit at z4 —
        // just above the board, still under Dave.
        sign.zPosition = 3
        camera.addChild(sign)

        menuButton = ControlButton(
            x: 200,
            y: 100,
            spriteType: .animatedSprite(
                spritesheetName: "menu-spritesheet",
                frameWidth: 256,
                frameHeight: 256,
                margin: 0,
                spacing: 0,
                frameIndex: 1
            ),
            scale: signScale
        )
        menuButton.position = CGPoint(x: hudX, y: boardCenterY - 205 * signScale)
        menuButton.zPosition = 3

        menuButton.defineAnimation(name: "clicked", frameIndices: [1, 2, 3, 4, 4, 3, 2, 1, 0, 1], timePerFrame: 0.125, repeatForever: false)


        menuButton.onPressed = { [weak self] in
            self?.menuButton.playAnimation(named: "clicked", timePerFrame: 0.125, repeatForever: false) {
                self?.onMenuPressed?()
            }
        }
        camera.addChild(menuButton)

        runningScoreLabel = createLabel(text: "score: \(GameState.shared.totalScore)", fontSize: 30 * signScale, position: CGPoint(x: hudX, y: boardCenterY + 35 * signScale), zPosition: 4, fontColor: .black, align: .center)
        camera.addChild(runningScoreLabel)

        runningStreakLabel = createLabel(text: "streak: \(GameState.shared.streak)", fontSize: 30 * signScale, position: CGPoint(x: hudX, y: boardCenterY - 35 * signScale), zPosition: 4, fontColor: .black, align: .center)
        camera.addChild(runningStreakLabel)

        highScoreLabel = createLabel(text: "NEW HIGH SCORE!", fontSize: 50, position: CGPoint(x: 0, y: sceneSize.height / 2 - 150), zPosition: 20, fontColor: Game.customGreen)
        highScoreLabel.horizontalAlignmentMode = .center
        let highScoreShadow = SKLabelNode(fontNamed: "DrawvidHand-Regular")
        highScoreShadow.text = "NEW HIGH SCORE!"
        highScoreShadow.fontSize = 50
        highScoreShadow.fontColor = .black
        highScoreShadow.horizontalAlignmentMode = .center
        highScoreShadow.position = CGPoint(x: 4, y: -4)
        highScoreShadow.zPosition = -1
        highScoreLabel.addChild(highScoreShadow)
        highScoreLabel.isHidden = true
        camera.addChild(highScoreLabel)
    }

    func setRunningScore(score: Int) {
        runningScoreLabel.text = "score: \(score)"
    }

    func setRunningStreak(streak: Int) {
        runningStreakLabel.text = "streak: \(streak)"
    }

    func setGoalFlips(flips: Double) {
        goalLabel.text = "GOAL: \(flips) " + (flips < 1.5 ? "FLIP" : "FLIPS")
    }

    func setVisible(_ visible: Bool) {
        leftButton.isHidden = !visible
        rightButton.isHidden = !visible
        jumpButton.isHidden = !visible
        flipButton.isHidden = !visible
    }

    func updateButtons(jumpEnabled: Bool, flipEnabled: Bool) {
        jumpButton.setEnabled(jumpEnabled)
        flipButton.setEnabled(flipEnabled)
    }
}

