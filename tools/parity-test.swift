import Foundation

@main
struct ParityTest {
    static func main() {
        guard CommandLine.arguments.count >= 2 else {
            FileHandle.standardError.write(Data("usage: parity-test <fixtures.json>\n".utf8))
            exit(2)
        }
        let fixturesURL = URL(fileURLWithPath: CommandLine.arguments[1])

        guard
            let data = try? Data(contentsOf: fixturesURL),
            let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else {
            FileHandle.standardError.write(
                Data("could not load fixtures at \(fixturesURL.path)\n".utf8)
            )
            exit(2)
        }

        var passed = 0
        var failed = 0
        var failures: [String] = []

        func check<T: Equatable>(_ label: String, expected: T, actual: T) {
            if expected == actual {
                passed += 1
            } else {
                failed += 1
                failures.append("  \(label): expected \(expected), got \(actual)")
            }
        }

        if let cases = root["chooseEmotionFrame"] as? [[String: Any]] {
            for c in cases {
                guard let angle = (c["angle"] as? NSNumber)?.doubleValue,
                      let expected = (c["expected"] as? NSNumber)?.intValue else { continue }
                check("chooseEmotionFrame(\(angle))",
                      expected: expected,
                      actual: DiveScorer.chooseEmotionFrame(angle: angle))
            }
        }

        if let cases = root["classifyBoostTiming"] as? [[String: Any]] {
            for c in cases {
                guard let quickness = (c["quicknessMs"] as? NSNumber)?.doubleValue,
                      let expected = c["expected"] as? String else { continue }
                let timing = DiveScorer.classifyBoostTiming(quicknessMs: quickness)
                let actual: String
                switch timing {
                case .perfect: actual = "perfect"
                case .good:    actual = "good"
                case .ok:      actual = "ok"
                case .miss:    actual = "miss"
                }
                check("classifyBoostTiming(\(quickness))", expected: expected, actual: actual)
            }
        }

        if let cases = root["scoreDive"] as? [[String: Any]] {
            for c in cases {
                guard let input = c["input"] as? [String: Any],
                      let goal = (input["goalRotations"] as? NSNumber)?.doubleValue,
                      let rotations = (input["rotations"] as? NSNumber)?.doubleValue,
                      let angle = (input["angle"] as? NSNumber)?.doubleValue,
                      let tuckCount = (input["tuckCount"] as? NSNumber)?.intValue,
                      let expectedResult = c["expectedResult"] as? String,
                      let expectedFrame = (c["expectedEmotionFrame"] as? NSNumber)?.intValue
                else { continue }

                let out = DiveScorer.score(
                    goalRotations: goal, rotations: rotations,
                    angle: angle, tuckCount: tuckCount
                )
                let resultStr = out.result == .success ? "success" : "failure"
                let label = "scoreDive(goal:\(goal), rot:\(rotations), angle:\(angle), tuck:\(tuckCount))"
                check("\(label).result", expected: expectedResult, actual: resultStr)
                check("\(label).emotionFrame", expected: expectedFrame, actual: out.emotionFrame)
            }
        }

        print("[swift] \(passed) passed, \(failed) failed")
        if failed > 0 {
            for f in failures { print(f) }
            exit(1)
        }
    }
}
