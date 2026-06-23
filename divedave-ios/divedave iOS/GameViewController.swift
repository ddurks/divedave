import UIKit
import SpriteKit
import GameplayKit
import os

private let logger = Logger(subsystem: "com.drawvid.divedave", category: "lifecycle")

class GameViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        if let skView = self.view as? SKView {
            GameState.shared.metrics = SceneMetrics(deviceBounds: skView.bounds.size)
            let m = GameState.shared.metrics

            logger.debug("scene: \(m.width) x \(m.height)")

            preloadAllAssets {
                DispatchQueue.main.async {
                    self.prepareAndPresentMainMenuScene(skView: skView)
                }
            }

            skView.ignoresSiblingOrder = true
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
            SKTexture(imageNamed: "divedave-spritesheet_gettingout"),
            SKTexture(imageNamed: "ladder"),
            SKTexture(imageNamed: "divedave-spritesheet-extruded"),
            SKTexture(imageNamed: "water"),
            SKTexture(imageNamed: "board"),
            SKTexture(imageNamed: "platformtop"),
            SKTexture(imageNamed: "platformsection"),
            SKTexture(imageNamed: "platformbase"),
        ]

        SKTexture.preload(texturesToPreload, withCompletionHandler: completion)
    }

    func prepareAndPresentMainMenuScene(skView: SKView) {
        let m = GameState.shared.metrics
        let mainMenuScene = MainMenuScene(size: CGSize(width: m.width, height: m.height))
        mainMenuScene.backgroundColor = SKColor(red: 0.74, green: 0.84, blue: 1.0, alpha: 1.0)
        mainMenuScene.scaleMode = .aspectFit
        mainMenuScene.setupMenu()
        skView.presentScene(mainMenuScene, transition: SKTransition.crossFade(withDuration: 0.5))
    }
}
