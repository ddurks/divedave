//
//  ControlButton.swift
//  divedave iOS
//
//  Created by David Durkin on 10/29/24.
//

import SpriteKit

class ControlButton: SKSpriteNode {
    // Track button state
    var isDown = false
    var onPressed: (() -> Void)?
    var onReleased: (() -> Void)?
    private var scale: CGFloat = 1

    init(x: CGFloat, y: CGFloat, textureName: String, scale: CGFloat) {
        // Initialize button with the specified texture and position
        let texture = SKTexture(imageNamed: textureName)
        self.scale = scale
        super.init(texture: texture, color: .clear, size: texture.size())
        self.position = CGPoint(x: x, y: y)
        self.setScale(scale)
        self.zPosition = 30

        // Enable touch interaction
        self.isUserInteractionEnabled = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Touch began - handle button press
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDown = true
        self.setScale(self.scale * 1.25)
        onPressed?()
    }
    
    // Touch ended - handle button release
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.setScale(self.scale)
        pointerUp()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.setScale(self.scale)
        pointerUp()
    }
    
    private func pointerUp() {
        isDown = false
        onReleased?()
    }
}
