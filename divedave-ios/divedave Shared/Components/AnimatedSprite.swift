//
//  AnimatedSprite.swift
//  divedave iOS
//
//  Created by David Durkin on 10/30/24.
//

import SpriteKit

class AnimatedSprite: SKSpriteNode {
    public var frames: [SKTexture] = []
    private var animations: [String: [SKTexture]] = [:]
    public var currentAnimation: String?
    
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
    func loadFrames(from texture: SKTexture, frameWidth: CGFloat, frameHeight: CGFloat, margin: CGFloat, spacing: CGFloat) -> [SKTexture] {
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
        animations[name] = animationFrames
        
        // Set the initial texture to the first frame if texture is not already set
        if texture == nil {
            texture = animationFrames.first
        }
    }
    
    // Play a defined animation by name
    func playAnimation(name: String, timePerFrame: TimeInterval = 0.125, repeatForever: Bool = true, completion: (() -> Void)? = nil) {
        // Check if the animation is already playing
        if currentAnimation == name { return }
        
        guard let animationFrames = animations[name] else {
            print("Animation \(name) not found.")
            return
        }
        
        currentAnimation = name
        
        // Create the animation action
        let animationAction = SKAction.animate(with: animationFrames, timePerFrame: timePerFrame)
        let action: SKAction
        if repeatForever {
            action = SKAction.repeatForever(animationAction)
        } else {
            // Run the completion block after the animation finishes
            let completionAction = SKAction.run {
                completion?()
            }
            action = SKAction.sequence([animationAction, completionAction])
        }
        
        self.run(action, withKey: name)
    }
    
    // Stop current animation
    func stopAnimation() {
        if (self.currentAnimation != nil) {
            self.removeAllActions()
            self.currentAnimation = nil
        }
    }
}
