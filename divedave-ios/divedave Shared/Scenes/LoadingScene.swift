//
//  LoadingScene.swift
//  divedave iOS
//
//  Created by David Durkin on 11/4/24.
//

import SpriteKit

class LoadingScene: SKScene {
    private var loadingAnimation: AnimatedSprite!

    override func didMove(to view: SKView) {
        self.backgroundColor = .black
        
        // Initialize the AnimatedSprite for the loading GIF
        loadingAnimation = AnimatedSprite(
            spritesheetName: "divedave_loading_spritesheet",
            frameWidth: 256,
            frameHeight: 256,
            scale: 1
        )
        
        // Position the animation in the center of the screen
        loadingAnimation.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(loadingAnimation)
        
        // Define the loading animation (assuming 21 frames in the spritesheet)
        loadingAnimation.defineAnimation(
            name: "loading",
            frameIndices: Array(0..<21), // Update to match actual frame count
            timePerFrame: 0.125
        )
        
        // Play the loading animation in a loop
        NSLog("Playing Animation!!")
        loadingAnimation.playAnimation(name: "loading", timePerFrame: 0.125)
    }
}
