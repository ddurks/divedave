//
//  MainMenuScene.swift
//  divedave iOS
//
//  Created by David Durkin on 10/29/24.
//

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

    func setupMenu() {
        // Cover image
        coverImage = SKSpriteNode(imageNamed: "cover")
        coverImage.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
        coverImage.size.width = self.size.width
        coverImage.size.height = self.size.width
        coverImage.zPosition = 1
        addChild(coverImage)

        // Start arcade button
        startArcadeButton = MenuButton(imageNamed: "arcade",
                                       position: CGPoint(x: self.size.width / 2 + self.size.width / 5, y: self.size.height / 5),
                                       scale: 0.75 * GameState.shared.metrics.scaleFactorHeight,
                                       name: "startArcade") { [weak self] in
            self?.startGame(challengeMode: false)
        }
        addChild(startArcadeButton)

        // Start challenge button
        startChallengeButton = MenuButton(imageNamed: "challenge",
                                          position: CGPoint(x: self.size.width / 2 - self.size.width / 5, y: self.size.height / 5),
                                          scale: 0.75 * GameState.shared.metrics.scaleFactorHeight,
                                          name: "startChallenge") { [weak self] in
            self?.startGame(challengeMode: true)
        }
        addChild(startChallengeButton)
        
        setUpLoadingStuff()
        setupInstructions()
        
        highScore = UserDefaults.standard.integer(forKey: Game.highScoreKey)
        let bestScore = max(StatsStore.arcadeHigh, StatsStore.challengeHigh, highScore)
        if bestScore > 0 {
            displayHighScore(bestScore)
            displayMetaStats()
        }
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
        
        loadingDave = SKSpriteNode(imageNamed: "divedave-crouched")
        loadingDave.setScale(GameState.shared.metrics.scaleFactorHeight)
        loadingDave.position = CGPoint(x: loadingLabel.position.x, y: loadingLabel.position.y + loadingDave.size.height)
        loadingDave.isHidden = true;
        addChild(loadingDave)
    }

    func setupInstructions() {
        instructionsButton = MenuButton(imageNamed: "controls-help",
                                        position: CGPoint(x: self.size.width - 100, y: self.size.height - 100),
                                        scale: 0.75 * GameState.shared.metrics.scaleFactorHeight,
                                        name: "instructionsButton") { [weak self] in
            self?.showInstructions()
        }
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
        
        // Reveal the instruction panel and all labels
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
        CHALLENGE_MODE = challengeMode
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
        if let touch = touches.first {
            let location = touch.location(in: self)
            let touchedNode = self.atPoint(location)

            if let button = touchedNode as? MenuButton {
                button.triggerAction()
            } else if isShowingInstructions && touchedNode !== instructionsImage && touchedNode !== instructionPanel {
                hideInstructions()
            }
        }
    }
    
    private func displayMetaStats() {
        // Anchor the meta stats just below the high-score sign image on the left
        // side of the screen. The sign is drawn in displayHighScore with its
        // center at y = height - sign.size.height/8, so its bottom edge is at
        // y = height - 5*sign.size.height/8. We start a bit below that.
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
        // Add the sign image
        let sign = SKSpriteNode(imageNamed: "sign-xl")
        sign.setScale(GameState.shared.metrics.scaleFactorHeight * 2)
        let signPosition = CGPoint(x: (sign.size.width / 1.5), y: GameState.shared.metrics.height - (sign.size.height / 8))
        sign.position = signPosition
        sign.zRotation = .pi
        sign.zPosition = 20
        addChild(sign)
        
        // Add "YOUR CHALLENGE" label
        let challengeLabel = SKLabelNode(fontNamed: "Arial")
        challengeLabel.text = "YOUR CHALLENGE"
        challengeLabel.fontColor = .black
        challengeLabel.fontSize = 20 * GameState.shared.metrics.scaleFactorHeight * 2
        challengeLabel.position = CGPoint(x: (sign.size.width / 1.5), y: GameState.shared.metrics.height - (sign.size.height / 5) - (60 * GameState.shared.metrics.scaleFactorHeight * 2))
        challengeLabel.zPosition = 24
        challengeLabel.horizontalAlignmentMode = .center
        addChild(challengeLabel)
        
        // Add "HIGH SCORE" label
        let highScoreLabel = SKLabelNode(fontNamed: "Arial")
        highScoreLabel.text = "HIGH SCORE"
        highScoreLabel.fontColor = .black
        highScoreLabel.fontSize = 30 * GameState.shared.metrics.scaleFactorHeight * 2
        highScoreLabel.position = CGPoint(x: (sign.size.width / 1.5), y: GameState.shared.metrics.height - (sign.size.height / 5) - (90 * GameState.shared.metrics.scaleFactorHeight * 2))
        highScoreLabel.zPosition = 24
        highScoreLabel.horizontalAlignmentMode = .center
        addChild(highScoreLabel)
        
        // Add the high score value
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
