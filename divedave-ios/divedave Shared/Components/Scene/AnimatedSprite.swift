import SpriteKit
import os

private let logger = Logger(subsystem: "com.drawvid.divedave", category: "animation")

final class AnimatedSprite: SKSpriteNode {
    struct AnimationConfig {
        let frames: [SKTexture]
        let timePerFrame: TimeInterval
        let repeatForever: Bool
    }

    // Single key so each playAnimation REPLACES the previous animation action
    // instead of stacking actions that fight over the texture each frame.
    private static let animationKey = "animation"

    public var frames: [SKTexture] = []
    private var animations: [String: AnimationConfig] = [:]
    public private(set) var currentAnimation: String?

    init(spritesheetName: String, frameWidth: CGFloat, frameHeight: CGFloat, margin: CGFloat = 0, spacing: CGFloat = 0, scale: CGFloat = 1.0) {
        let spritesheet = SKTexture(imageNamed: spritesheetName)
        super.init(texture: nil, color: .clear, size: CGSize(width: frameWidth, height: frameHeight))
        self.setScale(scale)

        frames = loadFrames(from: spritesheet, frameWidth: frameWidth, frameHeight: frameHeight, margin: margin, spacing: spacing)

        self.texture = frames.first
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

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

    func defineAnimation(name: String, frameIndices: [Int], timePerFrame: TimeInterval, repeatForever: Bool = true) {
        let animationFrames = frameIndices.map { frames[$0] }
        animations[name] = AnimationConfig(frames: animationFrames, timePerFrame: timePerFrame, repeatForever: repeatForever)

        if texture == nil {
            texture = animationFrames.first
        }
    }

    func playAnimation(name: String, delay: TimeInterval = 0.0, completion: (() -> Void)? = nil) {
        if currentAnimation == name { return }

        guard let config = animations[name] else {
            print("Animation \(name) not found.")
            return
        }

        currentAnimation = name

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

        self.run(action, withKey: Self.animationKey)
    }

    func playAnimation(name: String, timePerFrame: TimeInterval, repeatForever: Bool = true, delay: TimeInterval = 0.0, completion: (() -> Void)? = nil) {
        playAnimation(name: name, delay: delay, completion: completion)
    }

    func clearCurrentAnimation() {
        currentAnimation = nil
    }

    func stopAnimation() {
        if (self.currentAnimation != nil) {
            self.removeAllActions()
            self.currentAnimation = nil
        }
    }
}
