//
//  AnimatedSprite.swift
//  divedave iOS
//
//  Created by David Durkin on 10/30/24.
//

import SpriteKit
import os

private let logger = Logger(subsystem: "com.drawvid.divedave", category: "animation")

final class AnimatedSprite: SKSpriteNode {
    struct AnimationConfig {
        let frames: [SKTexture]
        let timePerFrame: TimeInterval
        let repeatForever: Bool
    }

    public var frames: [SKTexture] = []
    private var animations: [String: AnimationConfig] = [:]
    public private(set) var currentAnimation: String?
    
    init(spritesheetName: String, frameWidth: CGFloat, frameHeight: CGFloat, margin: CGFloat = 0, spacing: CGFloat = 0, scale: CGFloat = 1.0) {
        let spritesheet = SKTexture(imageNamed: spritesheetName)
        super.init(texture: nil, color: .clear, size: CGSize(width: frameWidth, height: frameHeight))
        self.setScale(scale)
        
        // Load frames from spritesheet
        frames = loadFrames(from: spritesheet, frameWidth: frameWidth, frameHeight: frameHeight, margin: margin, spacing: spacing)
        
        // Set initial texture
        self.texture = frames.first
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    // Load frames from a spritesheet
    func loadFrames(from texture: SKTexture, frameWidth: CGFloat, frameHeight: CGFloat, margin: CGFloat = 0, spacing: CGFloat = 0) -> [SKTexture] {
        var frames: [SKTexture] = []
        
        let rows = Int((texture.size().height - margin + spacing) / (frameHeight + spacing))
        let columns = Int((texture.size().width - margin + spacing) / (frameWidth + spacing))
        
        for row in 0..<rows {
            for column in 0..<columns {
                let x = margin + CGFloat(column) * (frameWidth + spacing)
                let y = margin + CGFloat(row) * (frameHeight + spacing)
                
                let frameRect = CGRect(
                    x: x / texture.size().width,
                    y: 1 - ((y + frameHeight) / texture.size().height),
                    width: frameWidth / texture.size().width,
                    height: frameHeight / texture.size().height
                )
                
                let frameTexture = SKTexture(rect: frameRect, in: texture)
                frames.append(frameTexture)
            }
        }
        
        return frames
    }
    
    // Define an animation sequence with a name and frame indices
    func defineAnimation(name: String, frameIndices: [Int], timePerFrame: TimeInterval, repeatForever: Bool = true) {
        // Map the frame indices to textures for this animation
        let animationFrames = frameIndices.map { frames[$0] }
        animations[name] = AnimationConfig(frames: animationFrames, timePerFrame: timePerFrame, repeatForever: repeatForever)

        // Set the initial texture to the first frame if texture is not already set
        if texture == nil {
            texture = animationFrames.first
        }
    }

    // Play a defined animation by name using stored config values
    func playAnimation(name: String, delay: TimeInterval = 0.0, completion: (() -> Void)? = nil) {
        // Check if the animation is already playing
        if currentAnimation == name { return }

        guard let config = animations[name] else {
            print("Animation \(name) not found.")
            return
        }

        currentAnimation = name

        // Create the animation action
        let animationAction = SKAction.animate(with: config.frames, timePerFrame: config.timePerFrame)
        let action: SKAction
        if config.repeatForever {
            action = SKAction.repeatForever(animationAction)
        } else {
            let waitAction = SKAction.wait(forDuration: delay)

            let completionAction = SKAction.run {
                completion?()
            }

            logger.debug("delay: \(delay)")
            action = delay > 0 ? SKAction.sequence([waitAction, animationAction, completionAction]) : SKAction.sequence([animationAction, completionAction])
        }

        self.run(action, withKey: name)
    }

    // Backwards-compatible overload that accepts (and ignores) explicit timing
    // params; per-animation timing comes from defineAnimation.
    func playAnimation(name: String, timePerFrame: TimeInterval, repeatForever: Bool = true, delay: TimeInterval = 0.0, completion: (() -> Void)? = nil) {
        playAnimation(name: name, delay: delay, completion: completion)
    }

    // Clear the current animation marker without removing actions.
    func clearCurrentAnimation() {
        currentAnimation = nil
    }

    // Stop current animation
    func stopAnimation() {
        if (self.currentAnimation != nil) {
            self.removeAllActions()
            self.currentAnimation = nil
        }
    }
}
