import CoreGraphics

struct SceneMetrics {
    let width: CGFloat
    let height: CGFloat
    let scaleFactorWidth: CGFloat
    let scaleFactorHeight: CGFloat

    static let `default` = SceneMetrics(
        width: Game.defaultWidth,
        height: Game.defaultHeight,
        scaleFactorWidth: 1.0,
        scaleFactorHeight: 1.0
    )

    init(viewBounds: CGSize) {
        self.width = viewBounds.width
        self.height = viewBounds.height
        self.scaleFactorWidth = viewBounds.width / Game.defaultWidth
        self.scaleFactorHeight = viewBounds.height / Game.defaultHeight
    }

    init(width: CGFloat, height: CGFloat, scaleFactorWidth: CGFloat, scaleFactorHeight: CGFloat) {
        self.width = width
        self.height = height
        self.scaleFactorWidth = scaleFactorWidth
        self.scaleFactorHeight = scaleFactorHeight
    }
}
