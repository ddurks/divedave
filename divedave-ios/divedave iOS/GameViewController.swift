import UIKit
import SpriteKit
import GameplayKit
import os

private let logger = Logger(subsystem: "com.drawvid.divedave", category: "lifecycle")

class GameViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        Haptics.prepare()

        if let skView = self.view as? SKView {
            GameState.shared.metrics = SceneMetrics(viewBounds: skView.bounds.size)
            let m = GameState.shared.metrics

            logger.debug("WIDTH: \(m.width), HEIGHT: \(m.height), scaleFactorHeight: \(m.scaleFactorHeight), scaleFactorWidth: \(m.scaleFactorWidth)")

            preloadAllAssets {
                DispatchQueue.main.async {
                    self.prepareAndPresentMainMenuScene(skView: skView)
                }
            }

            skView.ignoresSiblingOrder = true
            skView.showsFPS = true
            skView.showsNodeCount = true
        }
    }

    func preloadAllAssets(completion: @escaping () -> Void) {
        let texturesToPreload = [
            SKTexture(imageNamed: "cover"),
            SKTexture(imageNamed: "panel"),
            SKTexture(imageNamed: "challenge"),
            SKTexture(imageNamed: "arcade"),
            SKTexture(imageNamed: "controls-help"),
            SKTexture(imageNamed: "landscape"),
            SKTexture(imageNamed: "getting-out-spritesheet"),
            SKTexture(imageNamed: "climbdave"),
            SKTexture(imageNamed: "divedave_spritesheet_extruded"),
            SKTexture(imageNamed: "water"),
            SKTexture(imageNamed: "board"),
            SKTexture(imageNamed: "platformtop"),
            SKTexture(imageNamed: "platformsection"),
            SKTexture(imageNamed: "platformbase"),
        ]

        SKTexture.preload(texturesToPreload, withCompletionHandler: completion)
    }

    func prepareAndPresentMainMenuScene(skView: SKView) {
        let mainMenuScene = MainMenuScene(size: skView.bounds.size)
        mainMenuScene.backgroundColor = SKColor(red: 0.74, green: 0.84, blue: 1.0, alpha: 1.0)
        mainMenuScene.scaleMode = .aspectFill
        mainMenuScene.setupMenu()
        skView.presentScene(mainMenuScene, transition: SKTransition.crossFade(withDuration: 0.5))
    }
}
