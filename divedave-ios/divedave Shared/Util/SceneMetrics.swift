import CoreGraphics

// The scene is a fixed 1250-wide world (Game.defaultWidth, == divedave-web WIDTH).
// Only the vertical field-of-view adapts to the device, mirroring web's
// computeViewportHeight: height = max(refHeight, round(width * deviceAspect)).
// `.aspectFit` then maps this fixed space to any screen, so all gameplay
// positions, sprite scales, and physics are device-independent by construction.
struct SceneMetrics {
    let width: CGFloat
    let height: CGFloat

    static let `default` = SceneMetrics(width: Game.defaultWidth, height: Game.refHeight)

    private init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }

    init(deviceBounds: CGSize) {
        let aspect = deviceBounds.width > 0
            ? deviceBounds.height / deviceBounds.width
            : Game.refHeight / Game.defaultWidth
        self.width = Game.defaultWidth
        self.height = max(Game.refHeight, (Game.defaultWidth * aspect).rounded())
    }
}
