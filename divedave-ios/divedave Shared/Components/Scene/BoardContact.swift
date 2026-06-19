//
//  BoardContact.swift
//  divedave iOS
//
//  Tracks whether Dave is currently in contact with the springboard
//  (from the SKPhysicsContactDelegate callbacks) and provides a pure
//  geometric "is dave above the board" check used by jump/dive logic.
//

import SpriteKit

@MainActor
final class BoardContact {
    /// True while the physics engine reports an active contact between
    /// Dave and the springboard. Driven by `didBegin`/`didEnd` below.
    private(set) var isTouching: Bool = false

    func didBegin(daveDidContactBoard: Bool) {
        if daveDidContactBoard { isTouching = true }
    }

    func didEnd(daveDidContactBoard: Bool) {
        if daveDidContactBoard { isTouching = false }
    }

    /// Pure geometric predicate: is Dave horizontally within the board's
    /// span AND vertically at-or-above the board's top edge? No state
    /// mutation. (DiveScene's wrapper still resets rotation accumulators
    /// when this transitions to true — that side effect will move into
    /// RotationTracker in a later extraction.)
    static func isAbove(dave: SKSpriteNode, board: SKSpriteNode, tolerance: CGFloat = 1.0) -> Bool {
        let daveRightEdge = dave.position.x + dave.size.width / 4
        let daveLeftEdge = dave.position.x - dave.size.width / 4
        let boardRightEdge = board.position.x + board.size.width / 2
        let daveBottomEdge = dave.position.y - dave.size.height / 2
        let boardTopEdge = board.position.y + board.size.height / 2
        return (daveRightEdge > 0 && daveLeftEdge < boardRightEdge)
            && (daveBottomEdge >= boardTopEdge - tolerance)
    }
}
