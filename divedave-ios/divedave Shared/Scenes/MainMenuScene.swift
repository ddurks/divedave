//
//  MainMenuScene.swift
//  divedave iOS
//
//  Created by David Durkin on 10/29/24.
//

import SpriteKit

class MainMenuScene: SKScene {
    private var startArcadeButton: SKSpriteNode!
    private var startChallengeButton: SKSpriteNode!
    private var loadingLabel: SKLabelNode!
    private var instructionsButton: SKSpriteNode!
    private var coverImage: SKSpriteNode!
    private var instructionPanel: SKSpriteNode!
    private var instructionLabels: [SKLabelNode] = []
    private var highScoreLabel: SKLabelNode!
    private var instructionStrings: [String] = []
    private var isShowingInstructions = false
    private var isPreloading = false
    private var userClickedStart = false
    
    override func didMove(to view: SKView) {
    }

    func setupMenu() {
        // Cover image
        coverImage = SKSpriteNode(imageNamed: "cover")
        coverImage.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
        coverImage.size.width = self.size.width
        coverImage.size.height = self.size.width
        coverImage.zPosition = 1
        addChild(coverImage)

        // Instructions button
        instructionsButton = SKSpriteNode(imageNamed: "controls-help")
        instructionsButton.setScale(0.75 * scaleFactorHeight)
        instructionsButton.position = CGPoint(x: self.size.width - instructionsButton.size.width / 2, y: self.size.height - instructionsButton.size.height)
        instructionsButton.name = "instructionsButton"
        addChild(instructionsButton)

        // Start arcade button
        startArcadeButton = SKSpriteNode(imageNamed: "arcade")
        startArcadeButton.setScale(0.75 * scaleFactorHeight)
        startArcadeButton.position = CGPoint(x: 3 * self.size.width / 4, y: startArcadeButton.size.height)
        startArcadeButton.name = "startArcade"
        addChild(startArcadeButton)

        // Start challenge button
        startChallengeButton = SKSpriteNode(imageNamed: "challenge")
        startChallengeButton.setScale(0.75 * scaleFactorHeight)
        startChallengeButton.position = CGPoint(x: self.size.width / 4, y: startChallengeButton.size.height)
        startChallengeButton.name = "startChallenge"
        addChild(startChallengeButton)
        
        loadingLabel = SKLabelNode(text: "Loading...")
        loadingLabel.fontName = "Arial-BoldMT"
        loadingLabel.fontSize = 30
        loadingLabel.fontColor = .white
        loadingLabel.position = CGPoint(x: self.size.width / 2, y: startArcadeButton.position.y)
        loadingLabel.zPosition = 3
        loadingLabel.isHidden = true;
        addChild(loadingLabel)
        
        // Prepare the instruction strings
        instructionStrings = [
            "touch left and right buttons",
            "to move dave",
            "touch the jump button to jump",
            "while above the board",
            "jump quickly multiple times",
            "near the end of the board",
            "to jump higher",
            "touch the flip button to flip",
            "once dave has left the board"
        ]
    }

    func setupInstructions() {
        // Instruction panel (initially hidden)
        instructionPanel = SKSpriteNode(imageNamed: "panel")
        instructionPanel.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
        instructionPanel.size.width = coverImage.size.width
        instructionPanel.size.height = coverImage.size.height
        instructionPanel.zPosition = 2
        instructionPanel.isHidden = true
        addChild(instructionPanel)

        // Instruction text labels (initially hidden)
        var height = self.size.height / 2 + (450 * scaleFactorHeight)
        for text in instructionStrings {
            let instructionLabel = SKLabelNode(text: text)
            instructionLabel.fontName = "Arial-BoldMT"
            instructionLabel.fontSize = 25
            instructionLabel.fontColor = .white
            instructionLabel.position = CGPoint(x: self.size.width / 2, y: height)
            instructionLabel.zPosition = 3
            instructionLabel.horizontalAlignmentMode = .center
            instructionLabel.isHidden = true
            addChild(instructionLabel)
            instructionLabels.append(instructionLabel)
            height -= 35
        }
    }

    func showInstructions() {
        guard !isShowingInstructions else { return }
        isShowingInstructions = true
        
        // Reveal the instruction panel and all labels
        instructionPanel.isHidden = false
        instructionLabels.forEach { $0.isHidden = false }
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
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        NSLog("Touch began")
        if let touch = touches.first {
            let location = touch.location(in: self)
            let touchedNode = self.atPoint(location)
            
            switch touchedNode.name {
            case "instructionsButton":
                showInstructions()
            case "startArcade":
                startGame(challengeMode: false)
            case "startChallenge":
                startGame(challengeMode: true)
            default:
                break
            }
        }
    }
}
