import SpriteKit

func createLabel(text: String, fontSize: CGFloat, position: CGPoint, zPosition: CGFloat, fontColor: SKColor = .white, bold: Bool = false, align: SKLabelHorizontalAlignmentMode = .left) -> SKLabelNode {
    let label = SKLabelNode(text: text)
    label.fontSize = fontSize
    label.position = position
    label.zPosition = zPosition
    label.fontColor = fontColor
    label.horizontalAlignmentMode = align
    if (bold) {
        label.fontName = "DrawvidHand-Regular"
    } else {
        label.fontName = "DrawvidHand-Regular"
    }
    return label
}
