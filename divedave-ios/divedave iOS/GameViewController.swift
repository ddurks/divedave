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

    // Hardware-keyboard support: UIPress events reach the responder chain (the
    // view controller), not the SKScene directly, so receive them here and
    // forward to the live DiveScene. Lets the game be played from a keyboard in
    // the Simulator, and on iPads with a keyboard attached.
    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if !forwardKeys(presses, pressed: true) {
            super.pressesBegan(presses, with: event)
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if !forwardKeys(presses, pressed: false) {
            super.pressesEnded(presses, with: event)
        }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if !forwardKeys(presses, pressed: false) {
            super.pressesCancelled(presses, with: event)
        }
    }

    private func forwardKeys(_ presses: Set<UIPress>, pressed: Bool) -> Bool {
        guard let scene = (view as? SKView)?.scene as? DiveScene else { return false }
        var handled = false
        for press in presses {
            guard let keyCode = press.key?.keyCode else { continue }
            if scene.handleKey(keyCode, pressed: pressed) { handled = true }
        }
        return handled
    }
}
