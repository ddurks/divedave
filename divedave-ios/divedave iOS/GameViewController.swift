//
//  GameViewController.swift
//  divedave iOS
//
//  Created by David Durkin on 10/29/24.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let skView = self.view as? SKView {
            WIDTH = skView.bounds.size.width
            HEIGHT = skView.bounds.size.height
            scaleFactorHeight = HEIGHT / DEFAULT_HEIGHT
            scaleFactorWidth = WIDTH / DEFAULT_WIDTH
            
            NSLog("WIDTH: \(WIDTH)")
            NSLog("HEIGHT: \(HEIGHT)")
            NSLog("scaleFactorHeight: \(scaleFactorHeight)")
            NSLog("scaleFactorWidth: \(scaleFactorWidth)")
            
            // Preload assets for MainMenuScene while showing LoadingScene
            preloadAllAssets {
                // After preloading, transition to the main menu
                DispatchQueue.main.async {
                    self.prepareAndPresentMainMenuScene(skView: skView)
                }
            }
            
            skView.ignoresSiblingOrder = true
            skView.showsPhysics = true
            skView.showsFPS = true
            skView.showsNodeCount = true
        }
    }
    
    func preloadAllAssets(completion: @escaping () -> Void) {
        // List of textures to preload for MainMenuScene
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
        // Create and present the MainMenuScene instance
        let mainMenuScene = MainMenuScene(size: skView.bounds.size)
        mainMenuScene.backgroundColor = SKColor(red: 0.74, green: 0.84, blue: 1.0, alpha: 1.0)
        mainMenuScene.scaleMode = .aspectFill
        mainMenuScene.setupMenu()
        skView.presentScene(mainMenuScene, transition: SKTransition.crossFade(withDuration: 0.5))
    }
}
