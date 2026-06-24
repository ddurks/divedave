import SceneKit
import SpriteKit

@MainActor
final class InfoPanel {
    private var baseDepth: CGFloat
    private var panel: SKSpriteNode
    private var daveImage: AnimatedSprite
    private var score1: SKSpriteNode
    private var score2: SKSpriteNode
    private var score3: SKSpriteNode
    private var tryAgain: SKLabelNode
    private var scene: SKScene
    private let scoreSpacing: CGFloat

    init(scene: SKScene, depth: CGFloat) {
        self.scene = scene
        self.baseDepth = depth
        self.scoreSpacing = 275

        panel = SKSpriteNode(imageNamed: "panel")
        panel.position = CGPoint(x: GameState.shared.metrics.width / 2, y: GameState.shared.metrics.height / 2)
        panel.zPosition = baseDepth
        panel.isHidden = true
        scene.addChild(panel)

        daveImage = AnimatedSprite(spritesheetName: "divedave-emotions", frameWidth: 150, frameHeight: 160)
        daveImage.position = CGPoint(x: GameState.shared.metrics.width / 2, y: GameState.shared.metrics.height / 2 + 175)
        daveImage.setScale(2)
        daveImage.zPosition = baseDepth + 1
        daveImage.isHidden = true
        scene.addChild(daveImage)

        score1 = SKSpriteNode(imageNamed: "sign")
        score1.position = CGPoint(x: GameState.shared.metrics.width / 2 - scoreSpacing, y: GameState.shared.metrics.height / 2 - 325)
        score1.zPosition = baseDepth + 2
        score1.isHidden = true
        scene.addChild(score1)

        score2 = SKSpriteNode(imageNamed: "sign")
        score2.position = CGPoint(x: GameState.shared.metrics.width / 2, y: GameState.shared.metrics.height / 2 - 325)
        score2.zPosition = baseDepth + 2
        score2.isHidden = true
        scene.addChild(score2)

        score3 = SKSpriteNode(imageNamed: "sign")
        score3.position = CGPoint(x: GameState.shared.metrics.width / 2 + scoreSpacing, y: GameState.shared.metrics.height / 2 - 325)
        score3.zPosition = baseDepth + 2
        score3.isHidden = true
        scene.addChild(score3)

        tryAgain = SKLabelNode(fontNamed: "DrawvidHand-Regular")
        tryAgain.text = "tap to dive again"
        tryAgain.fontSize = 65
        tryAgain.position = CGPoint(x: GameState.shared.metrics.width / 2, y: 75)
        tryAgain.zPosition = baseDepth + 2
        tryAgain.isHidden = true
        scene.addChild(tryAgain)
    }

    func display(result: String, strings: [String], frame: Int, scores: [Int]?) {
        var height = GameState.shared.metrics.height / 2 + 5
        let resultColor: SKColor = (result == "FAILED DIVE" || result == "GAME OVER") ? Game.customRed : Game.customGreen
        tryAgain.fontColor = resultColor
        let resultLabel = SKLabelNode(fontNamed: "DrawvidHand-Regular")
        resultLabel.text = result
        resultLabel.fontSize = 80
        resultLabel.fontColor = resultColor
        resultLabel.position = CGPoint(x: GameState.shared.metrics.width / 2, y: height + 350)
        resultLabel.zPosition = baseDepth + 1
        scene.addChild(resultLabel)

        let lineSpacing: CGFloat = 75
        for string in strings {
            let color = (string.contains("rotations") && (result == "FAILED DIVE" || result == "GAME OVER")) ? SKColor.red : SKColor.black
            let stringLabel = SKLabelNode(fontNamed: "DrawvidHand-Regular")
            stringLabel.text = string
            stringLabel.fontSize = 80
            stringLabel.fontColor = color
            stringLabel.position = CGPoint(x: GameState.shared.metrics.width / 2, y: height)
            stringLabel.zPosition = baseDepth + 1
            scene.addChild(stringLabel)
            height -= lineSpacing
        }

        var scoreLabels: [SKLabelNode] = []
        if let scores = scores {
            var width = GameState.shared.metrics.width / 2 - scoreSpacing
            for score in scores {
                let scoreLabel = SKLabelNode(fontNamed: "DrawvidHand-Regular")
                scoreLabel.text = "\(score)"
                scoreLabel.fontSize = 100
                scoreLabel.position = CGPoint(x: width, y: GameState.shared.metrics.height / 2 - 350)
                scoreLabel.zPosition = baseDepth + 3
                scoreLabel.fontColor = .red
                scoreLabel.alpha = 0
                scoreLabel.setScale(0.3)
                scene.addChild(scoreLabel)
                scoreLabels.append(scoreLabel)
                width += scoreSpacing
            }
        }

        panel.isHidden = false
        if (frame >= 0) {
            daveImage.texture = daveImage.frames[frame]
        } else {
            daveImage.texture = daveImage.frames[0]
        }
        daveImage.isHidden = false

        tryAgain.position = CGPoint(x: GameState.shared.metrics.width / 2, y: 100)

        if scores != nil {
            let signs = [score1, score2, score3]
            let signBaseScale = score1.xScale

            for sign in signs {
                sign.alpha = 0
                sign.setScale(signBaseScale * 0.3)
                sign.isHidden = false
            }
            tryAgain.alpha = 0
            tryAgain.isHidden = true

            var seq: [SKAction] = []
            for idx in 0..<min(signs.count, scoreLabels.count) {
                let sign = signs[idx]
                let label = scoreLabels[idx]
                seq.append(SKAction.wait(forDuration: 0.4))
                seq.append(SKAction.run {
                    sign.run(SKAction.group([
                        SKAction.fadeIn(withDuration: 0.1),
                        SKAction.sequence([
                            SKAction.scale(to: signBaseScale * 1.2, duration: 0.12),
                            SKAction.scale(to: signBaseScale, duration: 0.08)
                        ])
                    ]))
                    label.run(SKAction.group([
                        SKAction.fadeIn(withDuration: 0.1),
                        SKAction.sequence([
                            SKAction.scale(to: 1.2, duration: 0.12),
                            SKAction.scale(to: 1.0, duration: 0.08)
                        ])
                    ]))
                })
            }
            seq.append(SKAction.wait(forDuration: 0.4))
            seq.append(SKAction.run { [weak self] in
                guard let self = self else { return }
                self.tryAgain.isHidden = false
                let blink = SKAction.repeatForever(SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.2, duration: 0.5),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.5)
                ]))
                self.tryAgain.run(SKAction.sequence([
                    SKAction.fadeIn(withDuration: 0.2),
                    blink
                ]), withKey: "blink")
            })
            scene.run(SKAction.sequence(seq))
        } else {
            score1.isHidden = true
            score2.isHidden = true
            score3.isHidden = true
            tryAgain.isHidden = true
        }
    }

    func close() {
        tryAgain.removeAction(forKey: "blink")
        tryAgain.isHidden = true
        panel.isHidden = true
        daveImage.isHidden = true
        score1.isHidden = true
        score2.isHidden = true
        score3.isHidden = true
    }
}

