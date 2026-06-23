import UIKit
import Messages
import SpriteKit

final class MessagesViewController: MSMessagesAppViewController {
    private var skView: SKView?
    private var diveScene: DiveScene?
    private var incomingState: ChallengeState?
    private var currentSeed: String?
    private var pendingDiveStart = false

    private let backgroundColor = UIColor(red: 0.74, green: 0.84, blue: 1.0, alpha: 1.0)
    private let appStoreURL = URL(string: "https://apps.apple.com/app/divedave")!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = backgroundColor
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        if let selected = conversation.selectedMessage, let url = selected.url {
            incomingState = ChallengeStateCodec.decode(url)
        } else {
            incomingState = nil
        }
        renderCompactUI()
    }

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.willTransition(to: presentationStyle)
        if presentationStyle != .expanded {
            teardownDive()
            renderCompactUI()
        }
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        if presentationStyle == .expanded {
            // A finished round (both players have a score) is read-only —
            // expanding the bubble should keep the recap, not start a new dive.
            if incomingState?.responder != nil {
                renderCompactUI()
                return
            }
            pendingDiveStart = true
            view.setNeedsLayout()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if pendingDiveStart, presentationStyle == .expanded, view.bounds.height > 400 {
            pendingDiveStart = false
            if incomingState?.responder != nil { return }
            startDive()
        }
    }

    private func renderCompactUI() {
        clearChildren()
        if let state = incomingState, state.responder != nil {
            renderFinishedRound(state)
        } else if let state = incomingState {
            renderIncomingPreview(state)
        } else {
            renderOutgoingPrompt()
        }
    }

    private func renderOutgoingPrompt() {
        let image = makeImage("divedave_challenge")
        let label = makeLabel("Tap to challenge a friend")
        let button = makeButton("Play", action: #selector(playTapped))
        stack([image, label, button])
    }

    private func renderIncomingPreview(_ state: ChallengeState) {
        let h = String(format: "%.1f", state.boardHeightMeters)
        let text = "\(state.challenger.name) scored \(state.challenger.score) from \(h) m — beat it?"
        let label = makeLabel(text)
        let button = makeButton("Play", action: #selector(playTapped))
        stack([label, button])
    }

    private func renderFinishedRound(_ state: ChallengeState) {
        guard let responder = state.responder else { return }
        let summary = "\(state.challenger.name): \(state.challenger.score)  vs  \(responder.name): \(responder.score)"
        let label = makeLabel(summary)
        let button = makeButton("Get Dive Dave", action: #selector(getAppTapped))
        stack([label, button])
    }

    @objc private func playTapped() {
        requestPresentationStyle(.expanded)
    }

    @objc private func getAppTapped() {
        extensionContext?.open(appStoreURL, completionHandler: nil)
    }

    private func startDive() {
        clearChildren()

        let skView = SKView()
        skView.translatesAutoresizingMaskIntoConstraints = false
        skView.ignoresSiblingOrder = true
        view.addSubview(skView)
        NSLayoutConstraint.activate([
            skView.topAnchor.constraint(equalTo: view.topAnchor),
            skView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            skView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            skView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        self.skView = skView

        let seed = incomingState?.seed ?? ChallengeStateCodec.newSeed()
        currentSeed = seed
        GameState.shared.duelSeed = seed
        GameState.shared.challengeMode = false

        GameState.shared.metrics = SceneMetrics(deviceBounds: view.bounds.size)

        let m = GameState.shared.metrics
        let scene = DiveScene(size: CGSize(width: m.width, height: m.height))
        scene.scaleMode = .aspectFit
        scene.onDuelComplete = { [weak self] score in
            Task { @MainActor in self?.finishDuel(score: score) }
        }
        diveScene = scene
        skView.presentScene(scene)
    }

    private func teardownDive() {
        skView?.presentScene(nil)
        skView?.removeFromSuperview()
        skView = nil
        diveScene = nil
        GameState.shared.duelSeed = nil
    }

    @MainActor
    private func finishDuel(score: Int) {
        guard let scene = diveScene, let seed = currentSeed else { return }
        let me = Player(name: UIDevice.current.name, score: score)
        let state: ChallengeState
        if let incoming = incomingState {
            state = ChallengeState(
                seed: incoming.seed,
                boardHeightMeters: incoming.boardHeightMeters,
                goalRotations: incoming.goalRotations,
                challenger: incoming.challenger,
                responder: me
            )
        } else {
            state = ChallengeState(
                seed: seed,
                boardHeightMeters: scene.calculateHeightFromWater(),
                goalRotations: scene.goalRotations,
                challenger: me,
                responder: nil
            )
        }

        guard let url = ChallengeStateCodec.encode(state) else { return }
        let message = MSMessage()
        message.url = url
        message.layout = makeLayout(for: state)
        activeConversation?.insert(message) { _ in }
        dismiss()
    }

    private func makeLayout(for state: ChallengeState) -> MSMessageTemplateLayout {
        let layout = MSMessageTemplateLayout()
        let h = String(format: "%.1f", state.boardHeightMeters)
        if let responder = state.responder {
            layout.caption = "\(state.challenger.name): \(state.challenger.score) vs \(responder.name): \(responder.score)"
        } else {
            layout.caption = "\(state.challenger.name) scored \(state.challenger.score) from \(h) m — beat it?"
        }
        layout.image = nil
        return layout
    }

    private func clearChildren() {
        view.subviews.forEach { $0.removeFromSuperview() }
    }

    private func makeLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }

    private func makeImage(_ name: String) -> UIImageView {
        let imageView = UIImageView(image: UIImage(named: name))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 120),
            imageView.heightAnchor.constraint(equalToConstant: 120),
        ])
        return imageView
    }

    private func makeButton(_ title: String, action: Selector) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = UIColor(red: 0.1, green: 0.3, blue: 0.6, alpha: 1.0)
        config.baseForegroundColor = .white
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24)
        var attr = AttributedString(title)
        attr.font = .systemFont(ofSize: 22, weight: .bold)
        config.attributedTitle = attr
        let button = UIButton(configuration: config)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func stack(_ views: [UIView]) {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
        ])
    }
}
