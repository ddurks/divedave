import Foundation

struct ChallengeState: Codable {
    let seed: String
    let boardHeightMeters: Double
    let goalRotations: Double
    let challenger: Player
    let responder: Player?

    enum CodingKeys: String, CodingKey {
        case seed = "s"
        case boardHeightMeters = "h"
        case goalRotations = "g"
        case challenger = "c"
        case responder = "r"
    }
}

struct Player: Codable {
    let name: String
    let score: Int

    enum CodingKeys: String, CodingKey {
        case name = "n"
        case score = "s"
    }
}

enum ChallengeStateCodec {
    private static let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")
    private static let host = "divedave.app"
    private static let path = "/c"
    private static let param = "s"

    static func newSeed() -> String {
        String((0..<8).map { _ in alphabet.randomElement()! })
    }

    static func encode(_ state: ChallengeState) -> URL? {
        guard let json = try? JSONEncoder().encode(state) else { return nil }
        let payload = base64urlEncode(json)
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.queryItems = [URLQueryItem(name: param, value: payload)]
        return components.url
    }

    static func decode(_ url: URL) -> ChallengeState? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let payload = components.queryItems?.first(where: { $0.name == param })?.value,
              let data = base64urlDecode(payload)
        else { return nil }
        return try? JSONDecoder().decode(ChallengeState.self, from: data)
    }

    private static func base64urlEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64urlDecode(_ string: String) -> Data? {
        var s = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = (4 - s.count % 4) % 4
        s.append(String(repeating: "=", count: pad))
        return Data(base64Encoded: s)
    }
}
