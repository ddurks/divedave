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

    // The fixed-width world renders physically larger on wide/short iPad-class
    // viewports, so chrome (HUD + menu) sized in world units comes out oversized.
    // Phones sit at aspect ≥ ~1.78, iPads at ≤ ~1.52, so 1.6 cleanly splits them.
    var isWideViewport: Bool { height / width < 1.6 }
    // One factor the HUD and menu chrome multiply by, so both shrink together on
    // iPad and stay byte-identical on phones.
    var hudScale: CGFloat { isWideViewport ? 0.69 : 1.0 }
}
