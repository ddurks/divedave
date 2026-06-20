import SpriteKit
import os

private let logger = Logger(subsystem: "com.drawvid.divedave", category: "loading")

class LoadingScene: SKScene {
    private var loadingAnimation: AnimatedSprite!

    override func didMove(to view: SKView) {
        self.backgroundColor = .black

        loadingAnimation = AnimatedSprite(
            spritesheetName: "divedave_loading_spritesheet",
            frameWidth: 256,
            frameHeight: 256,
            scale: 1
        )

        loadingAnimation.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(loadingAnimation)

        loadingAnimation.defineAnimation(
            name: "loading",
            frameIndices: Array(0..<21),
            timePerFrame: 0.125
        )

        logger.debug("Playing Animation!!")
        loadingAnimation.playAnimation(name: "loading", timePerFrame: 0.125)
    }
}
