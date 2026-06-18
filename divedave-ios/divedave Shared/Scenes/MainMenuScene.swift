//
//  MainMenuScene.swift
//  divedave iOS
//
//  Created by David Durkin on 10/29/24.
//

import SpriteKit

class MainMenuScene: SKScene {
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
                                       scale: 0.75 * scaleFactorHeight,
                                       name: "startArcade") { [weak self] in
            self?.startGame(challengeMode: false)
        }
        addChild(startArcadeButton)

        // Start challenge button
        startChallengeButton = MenuButton(imageNamed: "challenge",
                                          position: CGPoint(x: self.size.width / 2 - self.size.width / 5, y: self.size.height / 5),
                                          scale: 0.75 * scaleFactorHeight,
                                          name: "startChallenge") { [weak self] in
            self?.startGame(challengeMode: true)
        }
        addChild(startChallengeButton)
        
        setUpLoadingStuff()
        setupInstructions()
        
        highScore = UserDefaults.standard.integer(forKey: HIGH_SCORE)
        if highScore > 0 {
            displayHighScore(highScore)
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
        loadingDave.setScale(scaleFactorHeight)
        loadingDave.position = CGPoint(x: loadingLabel.position.x, y: loadingLabel.position.y + loadingDave.size.height)
        loadingDave.isHidden = true;
        addChild(loadingDave)
    }

    func setupInstructions() {
        instructionsButton = MenuButton(imageNamed: "controls-help",
                                        position: CGPoint(x: self.size.width - 100, y: self.size.height - 100),
                                        scale: 0.75 * scaleFactorHeight,
                                        name: "instructionsButton") { [weak self] in
            self?.showInstructions()
        }
        addChild(instructionsButton)
        
        instructionPanel = SKSpriteNode(imageNamed: "panel")
        let aspectRatio = instructionPanel.size.width / instructionPanel.size.height
        instructionPanel.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
        instructionPanel.size = CGSize(width: WIDTH, height: WIDTH / aspectRatio)
        instructionPanel.zPosition = 5
        instructionPanel.isHidden = true
        addChild(instructionPanel)
        
        instructionsImage = SKSpriteNode(imageNamed: "controls")
        instructionsImage.size = CGSize(width: WIDTH, height: WIDTH / aspectRatio)
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
        NSLog("Start Game")
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
    
    private func displayHighScore(_ highScore: Int) {
        NSLog("highScore: \(highScore)")
        // Add the sign image
        let sign = SKSpriteNode(imageNamed: "sign-xl")
        sign.setScale(scaleFactorHeight * 2)
        let signPosition = CGPoint(x: (sign.size.width / 1.5), y: HEIGHT - (sign.size.height / 8))
        sign.position = signPosition
        sign.zRotation = .pi
        sign.zPosition = 20
        addChild(sign)
        
        // Add "YOUR CHALLENGE" label
        let challengeLabel = SKLabelNode(fontNamed: "Arial")
        challengeLabel.text = "YOUR CHALLENGE"
        challengeLabel.fontColor = .black
        challengeLabel.fontSize = 20 * scaleFactorHeight * 2
        challengeLabel.position = CGPoint(x: (sign.size.width / 1.5), y: HEIGHT - (sign.size.height / 5) - (60 * scaleFactorHeight * 2))
        challengeLabel.zPosition = 24
        challengeLabel.horizontalAlignmentMode = .center
        addChild(challengeLabel)
        
        // Add "HIGH SCORE" label
        let highScoreLabel = SKLabelNode(fontNamed: "Arial")
        highScoreLabel.text = "HIGH SCORE"
        highScoreLabel.fontColor = .black
        highScoreLabel.fontSize = 30 * scaleFactorHeight * 2
        highScoreLabel.position = CGPoint(x: (sign.size.width / 1.5), y: HEIGHT - (sign.size.height / 5) - (90 * scaleFactorHeight * 2))
        highScoreLabel.zPosition = 24
        highScoreLabel.horizontalAlignmentMode = .center
        addChild(highScoreLabel)
        
        // Add the high score value
        let scoreLabel = SKLabelNode(fontNamed: "Arial")
        scoreLabel.text = "\(highScore)"
        scoreLabel.fontColor = .black
        scoreLabel.fontSize = 50 * scaleFactorHeight * 2
        scoreLabel.position = CGPoint(x: (sign.size.width / 1.5), y: HEIGHT - (sign.size.height / 5) - (150 * scaleFactorHeight * 2))
        scoreLabel.zPosition = 24
        scoreLabel.horizontalAlignmentMode = .center
        addChild(scoreLabel)
    }
}
