//
//  DiveScorer.swift
//  divedave iOS
//
//  Pure dive-scoring math. No scene/HUD/persistence side effects —
//  DiveScene handles those at the call site.
//

import CoreGraphics
import Foundation

struct DiveOutcome {
    enum Result { case success, failure }
    let result: Result
    let scores: [Int]
    let emotionFrame: Int
}

enum DiveScorer {
    /// Compute the dive's outcome (success/failure, three judge scores, emotion frame)
    /// from raw flight data. Pure — no side effects, no scene interaction.
    static func score(goalRotations: Double, rotations: Double, angle: Double, tuckCount: Int) -> DiveOutcome {
        guard abs(rotations - goalRotations) < 0.25 else {
            return DiveOutcome(result: .failure, scores: [0, 0, 0], emotionFrame: 0)
        }

        let baseFrame = chooseEmotionFrame(angle: angle)

        var scores: [Int] = []
        for _ in 0..<3 {
            let s: Int
            switch baseFrame {
            case 4: s = Int(10 - Double(Int.random(in: 0...1)) / 2.0 - Double(tuckCount - 1))
            case 3: s = Int(10 - Double(Int.random(in: 3...6)) / 2.0 - Double(tuckCount - 1))
            case 2: s = Int(10 - Double(Int.random(in: 7...10)) / 2.0 - Double(tuckCount - 1))
            case 1: s = Int(10 - Double(Int.random(in: 10...15)) / 2.0 - Double(tuckCount - 1))
            case 0: s = Int(10 - Double(Int.random(in: 14...18)) / 2.0 - Double(tuckCount - 1))
            default: s = 0
            }
            scores.append(s)
        }

        // Adjust emotion frame down by one if there was more than one tuck (visual penalty).
        let adjustedFrame = tuckCount > 1 ? baseFrame - 1 : baseFrame
        return DiveOutcome(result: .success, scores: scores, emotionFrame: adjustedFrame)
    }

    /// Map a final body angle (degrees) to one of 5 "emotion" frames.
    /// 4 = best (vertical, head-down), 0 = worst (horizontal flop).
    static func chooseEmotionFrame(angle: Double) -> Int {
        let absAngle = abs(angle)

        // Degree boundaries (kept as named locals so the staircase below reads as a table).
        let boundary10 = 10.0
        let boundary25 = 25.0
        let boundary45 = 45.0
        let boundary70 = 70.0
        let boundary110 = 110.0
        let boundary135 = 135.0
        let boundary155 = 155.0
        let boundary170 = 170.0

        if absAngle < boundary10 || absAngle > boundary170 {
            return 4
        } else if (absAngle >= boundary10 && absAngle < boundary25) || (absAngle <= boundary170 && absAngle > boundary155) {
            return 3
        } else if (absAngle >= boundary25 && absAngle < boundary45) || (absAngle <= boundary155 && absAngle > boundary135) {
            return 2
        } else if (absAngle >= boundary45 && absAngle < boundary70) || (absAngle <= boundary135 && absAngle > boundary110) {
            return 1
        } else if absAngle >= boundary70 && absAngle < boundary110 {
            return 0
        }
        return 2
    }

    /// Display height of the springboard above water, in the HUD's "meters" units.
    static func heightInMeters(springboardY: CGFloat, waterY: CGFloat, scaleFactorHeight: CGFloat) -> Double {
        let heightDifference = springboardY - waterY
        let inMeters = heightDifference / (200.0 * scaleFactorHeight)
        return round(Double(inMeters) * 10) / 10
    }
}
