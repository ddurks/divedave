import SpriteKit

@MainActor
final class BoardContact {
    private(set) var isTouching: Bool = false

    func didBegin(daveDidContactBoard: Bool) {
        if daveDidContactBoard { isTouching = true }
    }

    func didEnd(daveDidContactBoard: Bool) {
        if daveDidContactBoard { isTouching = false }
    }

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
