//
//  Controls.swift
//  divedave iOS
//
//  Created by David Durkin on 10/29/24.
//

import SpriteKit

class Controls {
    // Button nodes
    var leftButton: ControlButton
    var rightButton: ControlButton
    var jumpButton: ControlButton
    var flipButton: ControlButton
    
    init(camera: SKCameraNode, sceneSize: CGSize, scaleFactorHeight: CGFloat) {
        // Position controls relative to the camera node (origin at camera center)
        let buttonY = -sceneSize.height * 0.425  // Offset from camera's center toward the bottom
        let buttonScale = 0.65 * scaleFactorHeight

        // Dynamic x-positions as offsets from the camera’s center
        let leftButtonX = -sceneSize.width * 0.35
        let rightButtonX = -sceneSize.width * 0.1
        let jumpButtonX = sceneSize.width * 0.35
        let flipButtonX = jumpButtonX  // Same as jump button, initially hidden
        
        // Initialize buttons with updated relative positions
        leftButton = ControlButton(x: leftButtonX, y: buttonY, textureName: "controls-left", scale: buttonScale)
        rightButton = ControlButton(x: rightButtonX, y: buttonY, textureName: "controls-right", scale: buttonScale)
        jumpButton = ControlButton(x: jumpButtonX, y: buttonY, textureName: "controls-jump", scale: buttonScale)
        flipButton = ControlButton(x: flipButtonX, y: buttonY, textureName: "controls-flip", scale: buttonScale)
        
        // Initially hide the flip button
        flipButton.isHidden = true
        
        // Add buttons to the camera so they stay fixed
        camera.addChild(leftButton)
        camera.addChild(rightButton)
        camera.addChild(jumpButton)
        camera.addChild(flipButton)
        
        // Sign label at the bottom, scaled and positioned
        let sign = SKSpriteNode(imageNamed: "sign")
        sign.setScale(scaleFactorHeight)
        sign.position = CGPoint(x: (sign.size.width / 1.5) - (sceneSize.width / 2), y: (sceneSize.height / 2) - (sign.size.height / 2))
        sign.zRotation = .pi
        sign.zPosition = 30
        camera.addChild(sign)
    }
    
    func setVisible(_ visible: Bool) {
        leftButton.isHidden = !visible
        rightButton.isHidden = !visible
        jumpButton.isHidden = !visible
        flipButton.isHidden = !visible
    }
    
    func jumpControls() {
        jumpButton.isHidden = false
        flipButton.isHidden = true
    }
    
    func flipControls() {
        flipButton.isHidden = false
        jumpButton.isHidden = true
    }
}

