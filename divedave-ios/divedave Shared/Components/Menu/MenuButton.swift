import SpriteKit

class MenuButton: SKSpriteNode {
    private var action: (() -> Void)?

    init(imageNamed: String, position: CGPoint, scale: CGFloat, name: String, action: @escaping () -> Void) {
        let texture = SKTexture(imageNamed: imageNamed)
        super.init(texture: texture, color: .clear, size: texture.size())

        self.position = position
        self.setScale(scale)
        self.name = name
        self.zPosition = 2
        self.action = action
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func triggerAction() {
        let scaleUpAction = SKAction.scale(to: 0.625, duration: 0.5)
        let scaleBackAction = SKAction.scale(to: self.xScale, duration: 0.5)
        let runAction = SKAction.run { [weak self] in
            self?.action?()
        }

        let sequence = SKAction.sequence([scaleUpAction, scaleBackAction, runAction])
        self.run(sequence)
    }
}
