//
//  Controls.swift
//  divedave iOS
//
//  Created by David Durkin on 10/29/24.
//

import SpriteKit

final class HUD {
    // Button nodes
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
    init(view: SKView, camera: SKCameraNode, sceneSize: CGSize, scaleFactorHeight: CGFloat) {
        // Position controls relative to the camera node (origin at camera center)
        let buttonY = -sceneSize.height * 0.425  // Offset from camera's center toward the bottom
        let buttonScale = 0.65 * scaleFactorHeight

        // Dynamic x-positions as offsets from the camera’s center
        let leftButtonX = -sceneSize.width * 0.35
        let rightButtonX = -sceneSize.width * 0.1
        let jumpButtonX = sceneSize.width * 0.35
        let flipButtonX = jumpButtonX  // Same as jump button, initially hidden
        
        // Initialize buttons with updated relative positions
        leftButton = ControlButton(x: leftButtonX, y: buttonY, spriteType: .staticSprite(textureName: "controls-left"), scale: buttonScale)
        rightButton = ControlButton(x: rightButtonX, y: buttonY, spriteType: .staticSprite(textureName: "controls-right"), scale: buttonScale)
        jumpButton = ControlButton(x: jumpButtonX, y: buttonY, spriteType: .staticSprite(textureName: "controls-jump"), scale: buttonScale)
        flipButton = ControlButton(x: flipButtonX, y: buttonY, spriteType: .staticSprite(textureName: "controls-flip"), scale: buttonScale)
        
        // Initially hide the flip button
        flipButton.isHidden = true
        
        // Add buttons to the camera so they stay fixed
        camera.addChild(leftButton)
        camera.addChild(rightButton)
        camera.addChild(jumpButton)
        camera.addChild(flipButton)
        
        // Create the goal label
        goalLabel = SKLabelNode(text: "GOAL:")
        goalLabel.fontName = "Arial"
        goalLabel.fontColor = SKColor(red: 0/255, green: 128/255, blue: 0/255, alpha: 1.0)
        goalLabel.fontSize = 65 * scaleFactorHeight
        goalLabel.position = CGPoint(x: (4*sceneSize.width/2)/5, y: (4*sceneSize.height/2)/5)
        goalLabel.horizontalAlignmentMode = .right
        goalLabel.zPosition = 20
        camera.addChild(goalLabel)
    
        // Sign label at the bottom, scaled and positioned
        sign = SKSpriteNode(imageNamed: "sign-xl")
        sign.setScale(scaleFactorHeight * 2)
        let signPosition = CGPoint(x: (sign.size.width / 1.5) - (sceneSize.width / 2), y: (sceneSize.height / 2) - (sign.size.height / 8))
        sign.position = signPosition
        sign.zRotation = .pi
        sign.zPosition = 20
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
            scale: scaleFactorHeight * 2
        )
        menuButton.position = CGPoint(x: sign.position.x, y: (sceneSize.height / 2) - (4 * sign.size.height / 5))
        
        menuButton.defineAnimation(name: "clicked", frameIndices: [1, 2, 3, 4, 4, 3, 2, 1, 0, 1], timePerFrame: 0.125, repeatForever: false)

        
        menuButton.onPressed = { [weak self] in
            Haptics.impact(.light)
            self?.menuButton.playAnimation(named: "clicked", timePerFrame: 0.125, repeatForever: false) {
                self?.onMenuPressed?()
            }
        }
        camera.addChild(menuButton)
        
        // Running score and streak labels, scaled
        runningScoreLabel = createLabel(text: "score: \(GameState.shared.totalScore)", fontSize: 30 * scaleFactorHeight * 2, position: CGPoint(x: signPosition.x, y: signPosition.y - (sign.size.height/4) + (30 * scaleFactorHeight)), zPosition: 21, fontColor: .black, align: .center)
        camera.addChild(runningScoreLabel)

        runningStreakLabel = createLabel(text: "streak: \(GameState.shared.streak)", fontSize: 30 * scaleFactorHeight * 2, position: CGPoint(x: signPosition.x, y: signPosition.y - (sign.size.height/4) - (30 * scaleFactorHeight)), zPosition: 21, fontColor: .black, align: .center)
        camera.addChild(runningStreakLabel)
        
        // High score label
        highScoreLabel = createLabel(text: "NEW HIGH SCORE!", fontSize: 50 * scaleFactorHeight * 2, position: CGPoint(x: 0, y: -(GameState.shared.metrics.height / 4)), zPosition: 20, fontColor: Game.customGreen)
        highScoreLabel.horizontalAlignmentMode = .center
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
    
    func jumpControls() {
        jumpButton.isHidden = false
        flipButton.isHidden = true
    }
    
    func flipControls() {
        flipButton.isHidden = false
        jumpButton.isHidden = true
    }
}

