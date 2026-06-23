import CoreGraphics
import Foundation

struct DiveOutcome {
    enum Result { case success, failure }
    let result: Result
    let scores: [Int]
    let emotionFrame: Int
}

enum BoostTiming {
    case perfect, good, ok, miss
}

enum DiveScorer {
    static func classifyBoostTiming(quicknessMs: Double) -> BoostTiming {
        if quicknessMs < Game.boostPerfectMs { return .perfect }
        if quicknessMs < Game.boostGoodMs { return .good }
        if quicknessMs < Game.boostOkMs { return .ok }
        return .miss
    }

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

        let adjustedFrame = tuckCount > 1 ? baseFrame - 1 : baseFrame
        return DiveOutcome(result: .success, scores: scores, emotionFrame: adjustedFrame)
    }

    static func chooseEmotionFrame(angle: Double) -> Int {
        let absAngle = abs(angle)

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

    static func heightInMeters(springboardY: CGFloat, waterY: CGFloat) -> Double {
        let heightDifference = springboardY - waterY
        let inMeters = heightDifference / 200.0
        return round(Double(inMeters) * 10) / 10
    }

    // Dive height (metres) → number of half-flips the goal may ask for. A tuning
    // heuristic, not real physics; computed in reference-screen space so the goal
    // is device-independent. Mirrors divedave-web goalHalfFlips (parity-tested).
    static func goalHalfFlips(heightMeters: Double) -> Int {
        let referenceScale = Double(Game.referenceScreenHeight) / Double(Game.defaultHeight)
        let diveHeight = heightMeters * 200.0 * referenceScale
        let waterLevel = 256.0 * referenceScale / 2.0 + 1.0
        let distance = max(0.0, diveHeight - waterLevel)
        let time = sqrt(distance) / 10.0
        let totalRotation = time * Double(Game.maxSpinVelocity) * 0.70
        return Int((totalRotation / (2.0 * .pi)) * 2.0)
    }
}
