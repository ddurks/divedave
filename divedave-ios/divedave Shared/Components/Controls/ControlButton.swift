//
//  ControlButton.swift
//  divedave iOS
//
//  Created by David Durkin on 10/29/24.
//

import SpriteKit
import os

private let logger = Logger(subsystem: "com.drawvid.divedave", category: "input")

enum SpriteType {
    case staticSprite(textureName: String)
    case animatedSprite(spritesheetName: String, frameWidth: CGFloat, frameHeight: CGFloat, margin: CGFloat, spacing: CGFloat, frameIndex: Int = 0)
}

final class ControlButton: SKNode {
    // Track button state
    var isDown = false
    var onPressed: (() -> Void)?
    var onReleased: (() -> Void)?
    private var scale: CGFloat = 1
    private var spriteType: SpriteType
    private var spriteNode: SKNode

    /// True when the button renders at full opacity. `setEnabled(false)`
    /// greys it out visually. Touch tracking stays active either way so
    /// `isDown` remains accurate across enable/disable flips — that's what
    /// preserves the hold-jump-to-bounce pattern: the player can keep their
    /// finger down through `.launching` / `.airborne` (button greyed), and
    /// when the state returns to `.grounded` (button un-greys) the still-
    /// true `isDown` flag fires the next jump on the next frame.
    /// Functional gating lives in the state-machine switch in DiveScene.
    private(set) var isEnabled = true
    
    init(x: CGFloat, y: CGFloat, spriteType: SpriteType, scale: CGFloat) {
        self.scale = scale
        self.spriteType = spriteType
        
        switch spriteType {
        case .staticSprite(let textureName):
            let texture = SKTexture(imageNamed: textureName)
            let staticSprite = SKSpriteNode(texture: texture, color: .clear, size: texture.size())
            staticSprite.setScale(scale)
            self.spriteNode = staticSprite
            
        case .animatedSprite(let spritesheetName, let frameWidth, let frameHeight, let margin, let spacing, let frameIndex):
            let animatedSprite = AnimatedSprite(
                spritesheetName: spritesheetName,
                frameWidth: frameWidth,
                frameHeight: frameHeight,
                margin: margin,
                spacing: spacing,
                scale: scale
            )
            animatedSprite.texture = animatedSprite.frames[frameIndex]
            animatedSprite.setScale(scale)
            self.spriteNode = animatedSprite
        }
        
        super.init()
        
        self.position = CGPoint(x: x, y: y)
        self.addChild(spriteNode)
        self.zPosition = 20

        // Enable touch interaction
        self.isUserInteractionEnabled = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Touch began - handle button press
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDown = true
        switch spriteType {
        case .staticSprite:
            spriteNode.setScale(self.scale * 1.25)
        case .animatedSprite:
            break
        }
        onPressed?()
    }
    
    // Touch ended - handle button release
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        switch spriteType {
        case .staticSprite:
            spriteNode.setScale(self.scale)
        case .animatedSprite:
            break
        }
        pointerUp()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        switch spriteType {
        case .staticSprite:
            spriteNode.setScale(self.scale)
        case .animatedSprite:
            break
        }
        pointerUp()
    }
    
    private func pointerUp() {
        isDown = false
        onReleased?()
        
        if case .staticSprite(let textureName) = spriteType, textureName == "controls-jump" {
            // CACurrentMediaTime is a monotonic clock — immune to system clock changes
            // and faster than allocating a Date(). The companion read site in
            // DiveScene compares this against landedAt (also CACurrentMediaTime).
            GameState.shared.jumpReleasedAt = CACurrentMediaTime()
            Haptics.impact(.medium)
            logger.debug("jumpReleasedAt: \(GameState.shared.jumpReleasedAt)")
        }
    }
    
    func defineAnimation(name: String, frameIndices: [Int], timePerFrame: TimeInterval, repeatForever: Bool = true) {
        guard let animatedSprite = spriteNode as? AnimatedSprite else { return }
        animatedSprite.defineAnimation(name: name, frameIndices: frameIndices, timePerFrame: timePerFrame, repeatForever: repeatForever)
    }
    
    func playAnimation(named name: String, timePerFrame: TimeInterval, repeatForever: Bool = true, delay: TimeInterval = 0.0, completion: (() -> Void)? = nil) {
        guard let animatedSprite = spriteNode as? AnimatedSprite else { return }
        animatedSprite.playAnimation(name: name, timePerFrame: timePerFrame, repeatForever: repeatForever, delay: delay, completion: completion)
    }
    
    func stopAnimation() {
        guard let animatedSprite = spriteNode as? AnimatedSprite else { return }
        animatedSprite.stopAnimation()
    }

    /// Toggle the greyed-out visual. See `isEnabled` for why we don't gate
    /// touch handling here.
    func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled else { return }
        isEnabled = enabled
        alpha = enabled ? 1.0 : 0.4
    }
}
