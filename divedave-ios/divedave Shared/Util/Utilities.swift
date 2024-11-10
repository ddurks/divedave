//
//  Utilities.swift
//  divedave iOS
//
//  Created by David Durkin on 11/7/24.
//

import SpriteKit

func createLabel(text: String, fontSize: CGFloat, position: CGPoint, zPosition: CGFloat, fontColor: SKColor = .white, bold: Bool = false, align: SKLabelHorizontalAlignmentMode = .left) -> SKLabelNode {
    let label = SKLabelNode(text: text)
    label.fontSize = fontSize
    label.position = position
    label.zPosition = zPosition
    label.fontColor = fontColor
    label.horizontalAlignmentMode = align
    if (bold) {
        label.fontName = "Arial-BoldMT"
    } else {
        label.fontName = "Arial"
    }
    return label
}
