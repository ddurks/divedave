//
//  InfoPanel.swift
//  divedave iOS
//
//  Created by David Durkin on 11/6/24.
//

import SceneKit
import SpriteKit

class InfoPanel {
    private var baseDepth: CGFloat
    private var panel: SKSpriteNode
    private var daveImage: AnimatedSprite
    private var score1: SKSpriteNode
    private var score2: SKSpriteNode
    private var score3: SKSpriteNode
    private var tryAgain: SKLabelNode
    private var scene: SKScene

    init(scene: SKScene, depth: CGFloat) {
        self.scene = scene
        self.baseDepth = depth

        // Create panel
        panel = SKSpriteNode(imageNamed: "panel")
        panel.position = CGPoint(x: WIDTH / 2, y: HEIGHT / 2)
        panel.setScale(scaleFactorHeight)
        panel.zPosition = baseDepth
        panel.isHidden = true
        scene.addChild(panel)

        // Create dave image
        daveImage = AnimatedSprite(spritesheetName: "divedave-emotions", frameWidth: 150, frameHeight: 160, scale: scaleFactorHeight)
        daveImage.position = CGPoint(x: WIDTH / 2, y: HEIGHT / 2 + (175 * scaleFactorHeight))
        daveImage.setScale(2 * scaleFactorHeight)
        daveImage.zPosition = baseDepth + 1
        daveImage.isHidden = true
        scene.addChild(daveImage)

        // Create score images
        score1 = SKSpriteNode(imageNamed: "sign")
        score1.position = CGPoint(x: WIDTH / 2 - (275 * scaleFactorWidth), y: HEIGHT / 2 - (325 * scaleFactorHeight))
        score1.setScale(scaleFactorHeight)
        score1.zPosition = baseDepth + 2
        score1.isHidden = true
        scene.addChild(score1)

        score2 = SKSpriteNode(imageNamed: "sign")
        score2.position = CGPoint(x: WIDTH / 2, y: HEIGHT / 2 - (325 * scaleFactorHeight))
        score2.setScale(scaleFactorHeight)
        score2.zPosition = baseDepth + 2
        score2.isHidden = true
        scene.addChild(score2)

        score3 = SKSpriteNode(imageNamed: "sign")
        score3.position = CGPoint(x: WIDTH / 2 + (275 * scaleFactorWidth), y: HEIGHT / 2 - (325 * scaleFactorHeight))
        score3.setScale(scaleFactorHeight)
        score3.zPosition = baseDepth + 2
        score3.isHidden = true
        scene.addChild(score3)

        // Create "try again" label
        tryAgain = SKLabelNode(fontNamed: "Arial-BoldMT")
        tryAgain.text = "tap to dive again"
        tryAgain.fontSize = 65
        tryAgain.position = CGPoint(x: WIDTH / 2, y: (75 * scaleFactorHeight))
        tryAgain.setScale(scaleFactorHeight)
        tryAgain.zPosition = baseDepth + 2
        tryAgain.isHidden = true
        scene.addChild(tryAgain)
    }

    func display(result: String, strings: [String], frame: Int, scores: [Int]?) {
        var height = HEIGHT / 2 + (5 * scaleFactorHeight)
        let resultLabel = SKLabelNode(fontNamed: "Arial-BoldMT")
        resultLabel.text = result
        resultLabel.fontSize = 80 * scaleFactorHeight
        resultLabel.position = CGPoint(x: WIDTH / 2, y: height + (350 * scaleFactorHeight))
        resultLabel.zPosition = baseDepth + 1
        scene.addChild(resultLabel)

        // Display additional strings
        for string in strings {
            let color = (string.contains("rotations") && (result == "FAILED DIVE" || result == "GAME OVER")) ? SKColor.red : SKColor.black
            let stringLabel = SKLabelNode(fontNamed: "Arial-BoldMT")
            stringLabel.text = string
            stringLabel.fontSize = 80 * scaleFactorHeight
            stringLabel.fontColor = color
            stringLabel.position = CGPoint(x: WIDTH / 2, y: height)
            stringLabel.zPosition = baseDepth + 1
            scene.addChild(stringLabel)
            height -= (75 * scaleFactorWidth)
        }

        // Display scores
        var width = WIDTH / 2 - (275 * scaleFactorWidth)
        if let scores = scores {
            for score in scores {
                let scoreLabel = SKLabelNode(fontNamed: "Arial-BoldMT")
                scoreLabel.text = "\(score)"
                scoreLabel.fontSize = 100 * scaleFactorHeight
                scoreLabel.position = CGPoint(x: width, y: HEIGHT / 2 - (350 * scaleFactorHeight))
                scoreLabel.zPosition = baseDepth + 3
                scoreLabel.fontColor = .red
                scene.addChild(scoreLabel)
                width += (275 * scaleFactorWidth)
            }
        }

        // Update try again label position and visibility
        tryAgain.position = CGPoint(x: WIDTH / 2, y: (100 * scaleFactorHeight))
        tryAgain.isHidden = (scores == nil)

        // Show the panel and images
        panel.isHidden = false
        if (frame >= 0) {
            daveImage.texture = daveImage.frames[frame]
        } else {
            daveImage.texture = daveImage.frames[0]
        }
        daveImage.isHidden = false
        score1.isHidden = (scores == nil)
        score2.isHidden = (scores == nil)
        score3.isHidden = (scores == nil)
    }

    func close() {
        tryAgain.isHidden = true
        panel.isHidden = true
        daveImage.isHidden = true
        score1.isHidden = true
        score2.isHidden = true
        score3.isHidden = true
    }
}

