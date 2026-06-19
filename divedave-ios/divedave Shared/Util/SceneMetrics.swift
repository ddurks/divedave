//
//  SceneMetrics.swift
//  divedave iOS
//
//  Created by Lane E (Globals refactor) on 6/18/26.
//

import CoreGraphics

/// Snapshot of the on-screen drawing size and the per-axis scale factors
/// derived from the project's reference design dimensions (`Game.defaultWidth`
/// × `Game.defaultHeight`). Captured once at app launch and held by
/// `GameState.shared.metrics` so any scene/component can resolve sizes and
/// positions consistently.
struct SceneMetrics {
    let width: CGFloat
    let height: CGFloat
    let scaleFactorWidth: CGFloat
    let scaleFactorHeight: CGFloat

    /// Identity metrics — width/height equal to the reference design size, scale 1.0.
    /// Used as the initial value before `GameViewController.viewDidLoad` replaces it.
    static let `default` = SceneMetrics(
        width: Game.defaultWidth,
        height: Game.defaultHeight,
        scaleFactorWidth: 1.0,
        scaleFactorHeight: 1.0
    )

    /// Derive metrics from an `SKView`'s bounds size. Scale factors are
    /// computed against `Game.defaultWidth` / `Game.defaultHeight`.
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
