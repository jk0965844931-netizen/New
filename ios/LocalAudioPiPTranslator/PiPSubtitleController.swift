import AVKit
import SwiftUI
import UIKit

@MainActor
final class PiPSubtitleController: NSObject, ObservableObject {
    @Published private(set) var isPictureInPicturePossible = false
    @Published private(set) var isPictureInPictureActive = false
    @Published private(set) var statusMessage = "Safe movable subtitles are ready. System PiP is optional."
    @Published var showsSafeMovableOverlay = false
    @Published var allowsExperimentalSystemPiP = false

    fileprivate let sourceView = SubtitlePiPSourceView()
    private var pictureInPictureController: AVPictureInPictureController?
    private var contentViewController: UIViewController?
    private var currentSubtitle = "คำแปลจะแสดงในหน้าต่าง PiP"
    private var currentTranscript = "Screen Broadcast subtitle preview"

    override init() {
        super.init()
        sourceView.update(subtitle: currentSubtitle, transcript: currentTranscript)
    }

    var systemPiPDescription: String {
        "Safe mode shows a draggable subtitle window without starting System PiP, so it avoids the black-screen/crash path. Enable experimental System PiP only after the preview is visible."
    }

    func showSafeMovableOverlay() {
        showsSafeMovableOverlay = true
        statusMessage = "Safe movable subtitles are visible. Drag the subtitle card inside the app; System PiP was not force-started."
    }

    func hideSafeMovableOverlay() {
        showsSafeMovableOverlay = false
        statusMessage = "Safe movable subtitles hidden."
    }

    func updateSubtitle(_ text: String, transcript: String = "") {
        let cleanedSubtitle = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanedSubtitle.isEmpty { currentSubtitle = cleanedSubtitle }

        let cleanedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanedTranscript.isEmpty { currentTranscript = cleanedTranscript }

        sourceView.update(subtitle: currentSubtitle, transcript: currentTranscript)
        if let contentView = contentViewController?.view as? SubtitlePiPSourceView {
            contentView.update(subtitle: currentSubtitle, transcript: currentTranscript)
        }
    }

    func attachSourceView(to view: UIView) {
        if sourceView.superview !== view {
            sourceView.removeFromSuperview()
            sourceView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(sourceView)
            NSLayoutConstraint.activate([
                sourceView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                sourceView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                sourceView.topAnchor.constraint(equalTo: view.topAnchor),
                sourceView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
        configurePictureInPictureIfPossible()
    }

    func startPictureInPicture() {
        guard allowsExperimentalSystemPiP else {
            showSafeMovableOverlay()
            statusMessage = "System PiP is disabled in safe mode because this device showed a black screen/crash. Turn on Experimental System PiP to try it."
            return
        }

        configurePictureInPictureIfPossible()

        guard sourceView.window != nil else {
            showSafeMovableOverlay()
            statusMessage = "PiP preview is not attached yet, so safe movable subtitles were shown instead."
            return
        }
        guard let pictureInPictureController else {
            showSafeMovableOverlay()
            statusMessage = "System PiP is unavailable; safe movable subtitles were shown instead."
            return
        }
        guard pictureInPictureController.isPictureInPicturePossible else {
            isPictureInPicturePossible = false
            showSafeMovableOverlay()
            statusMessage = "System PiP is not possible yet; safe movable subtitles were shown instead."
            return
        }

        updateSubtitle(currentSubtitle, transcript: currentTranscript)
        pictureInPictureController.startPictureInPicture()
    }

    func stopPictureInPicture() {
        pictureInPictureController?.stopPictureInPicture()
        hideSafeMovableOverlay()
    }

    private func configurePictureInPictureIfPossible() {
        guard pictureInPictureController == nil else {
            isPictureInPicturePossible = pictureInPictureController?.isPictureInPicturePossible ?? false
            return
        }
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            statusMessage = "This device does not support Picture in Picture."
            return
        }
        guard sourceView.window != nil else {
            statusMessage = "PiP preview is ready; attach it on screen before starting PiP."
            return
        }

        if #available(iOS 15.0, *) {
            let pipContentView = SubtitlePiPSourceView()
            pipContentView.update(subtitle: currentSubtitle, transcript: currentTranscript)

            let callViewController = AVPictureInPictureVideoCallViewController()
            callViewController.preferredContentSize = CGSize(width: 980, height: 220)
            callViewController.view = pipContentView
            contentViewController = callViewController

            let contentSource = AVPictureInPictureController.ContentSource(
                activeVideoCallSourceView: sourceView,
                contentViewController: callViewController
            )
            let controller = AVPictureInPictureController(contentSource: contentSource)
            controller.canStartPictureInPictureAutomaticallyFromInline = false
            controller.delegate = self
            pictureInPictureController = controller
            isPictureInPicturePossible = controller.isPictureInPicturePossible
            statusMessage = "System PiP is ready. Tap Start movable PiP; the window should show subtitles instead of a black frame."
        } else {
            statusMessage = "Movable System PiP subtitles require iOS 15 or newer."
        }
    }
}

extension PiPSubtitleController: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            isPictureInPictureActive = true
            statusMessage = "System PiP subtitles are starting. Drag or collapse the PiP window like YouTube PiP."
        }
    }

    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            isPictureInPictureActive = true
            statusMessage = "System PiP is active. If you collapse it, tap the side handle to expand it again."
        }
    }

    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        Task { @MainActor in
            isPictureInPictureActive = false
            showsSafeMovableOverlay = true
            statusMessage = "PiP failed to start, so safe movable subtitles were shown: \(error.localizedDescription)"
        }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            isPictureInPictureActive = false
            statusMessage = "PiP subtitles stopped."
        }
    }
}

struct PiPSubtitlePreviewView: UIViewRepresentable {
    @ObservedObject var controller: PiPSubtitleController

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        controller.attachSourceView(to: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        controller.attachSourceView(to: uiView)
    }
}

final class SubtitlePiPSourceView: UIView {
    private let badgeLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let transcriptLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func update(subtitle: String, transcript: String) {
        subtitleLabel.text = subtitle.isEmpty ? "รอคำแปลจาก Screen Broadcast…" : subtitle
        transcriptLabel.text = transcript.isEmpty ? "Screen Broadcast subtitle preview" : transcript
    }

    private func setup() {
        backgroundColor = .clear
        layer.cornerRadius = 28
        layer.masksToBounds = true

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)

        let stack = UIStackView(arrangedSubviews: [badgeLabel, subtitleLabel, transcriptLabel])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        badgeLabel.text = "SCREEN BROADCAST • SYSTEM PiP"
        badgeLabel.textColor = UIColor.systemGreen
        badgeLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        badgeLabel.textAlignment = .center

        subtitleLabel.textColor = .white
        subtitleLabel.font = UIFont.systemFont(ofSize: 30, weight: .bold)
        subtitleLabel.adjustsFontSizeToFitWidth = true
        subtitleLabel.minimumScaleFactor = 0.55
        subtitleLabel.numberOfLines = 2
        subtitleLabel.textAlignment = .center

        transcriptLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        transcriptLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        transcriptLabel.numberOfLines = 1
        transcriptLabel.textAlignment = .center

        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12)
        ])
    }
}
