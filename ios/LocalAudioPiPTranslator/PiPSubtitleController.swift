import AVFoundation
import AVKit
import CoreMedia
import SwiftUI
import UIKit

@MainActor
final class PiPSubtitleController: NSObject, ObservableObject {
    @Published private(set) var isPictureInPicturePossible = false
    @Published private(set) var isPictureInPictureActive = false
    @Published private(set) var statusMessage = "PiP subtitle renderer is ready."

    fileprivate let displayLayer = AVSampleBufferDisplayLayer()
    private var pictureInPictureController: AVPictureInPictureController?
    private var currentSubtitle = "คำแปลจะแสดงในหน้าต่าง PiP"

    override init() {
        super.init()
        configureDisplayLayer()
        configurePictureInPicture()
        renderSubtitleFrame(currentSubtitle)
    }

    func updateSubtitle(_ text: String) {
        currentSubtitle = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? currentSubtitle : text
        renderSubtitleFrame(currentSubtitle)
    }

    var systemPiPDescription: String {
        "This uses AVPictureInPictureController, so once PiP starts iOS owns the floating window and the user can drag it around like YouTube PiP."
    }

    func attachDisplayLayer(to view: UIView) {
        if displayLayer.superlayer !== view.layer {
            displayLayer.removeFromSuperlayer()
            view.layer.addSublayer(displayLayer)
        }
        displayLayer.frame = view.bounds
        isPictureInPicturePossible = pictureInPictureController?.isPictureInPicturePossible ?? false
    }

    func startPictureInPicture() {
        guard let pictureInPictureController else {
            statusMessage = "PiP is unavailable on this device."
            return
        }
        guard pictureInPictureController.isPictureInPicturePossible else {
            statusMessage = "PiP is not possible until the sample-buffer video layer is ready."
            return
        }
        pictureInPictureController.startPictureInPicture()
    }

    func stopPictureInPicture() {
        pictureInPictureController?.stopPictureInPicture()
    }

    private func configureDisplayLayer() {
        displayLayer.videoGravity = .resizeAspect
        displayLayer.backgroundColor = UIColor.clear.cgColor
    }

    private func configurePictureInPicture() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            statusMessage = "This device does not support Picture in Picture."
            return
        }

        if #available(iOS 15.0, *) {
            let contentSource = AVPictureInPictureController.ContentSource(
                sampleBufferDisplayLayer: displayLayer,
                playbackDelegate: self
            )
            let controller = AVPictureInPictureController(contentSource: contentSource)
            controller.canStartPictureInPictureAutomaticallyFromInline = false
            controller.delegate = self
            pictureInPictureController = controller
            isPictureInPicturePossible = controller.isPictureInPicturePossible
        } else {
            statusMessage = "Sample-buffer PiP subtitles require iOS 15 or newer."
        }
    }

    private func renderSubtitleFrame(_ subtitle: String) {
        let size = CGSize(width: 980, height: 220)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.black.withAlphaComponent(0.72).setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 34).fill()

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            paragraph.lineBreakMode = .byWordWrapping

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 54, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph
            ]
            let rect = CGRect(x: 42, y: 42, width: size.width - 84, height: size.height - 84)
            subtitle.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
            context.cgContext.setStrokeColor(UIColor.white.withAlphaComponent(0.18).cgColor)
            context.cgContext.setLineWidth(3)
            context.cgContext.stroke(CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2))
        }

        guard let sampleBuffer = image.makeSampleBuffer() else {
            statusMessage = "Could not render subtitle frame for PiP."
            return
        }

        if displayLayer.status == .failed {
            displayLayer.flush()
        }
        displayLayer.enqueue(sampleBuffer)
        statusMessage = "Rendered subtitle into PiP video stream."
    }
}

extension PiPSubtitleController: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            isPictureInPictureActive = true
            statusMessage = "System PiP subtitles are starting. Drag the PiP window like YouTube PiP."
        }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            isPictureInPictureActive = false
            statusMessage = "PiP subtitles stopped."
        }
    }
}

@available(iOS 15.0, *)
extension PiPSubtitleController: AVPictureInPictureSampleBufferPlaybackDelegate {
    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {}

    nonisolated func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .zero, duration: CMTime(value: 1, timescale: 1))
    }

    nonisolated func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        false
    }

    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}

    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

private extension UIImage {
    func makeSampleBuffer() -> CMSampleBuffer? {
        guard let cgImage else { return nil }
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ] as CFDictionary

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            cgImage.width,
            cgImage.height,
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))

        var formatDescription: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        guard let formatDescription else { return nil }

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        return sampleBuffer
    }
}

struct PiPSubtitlePreviewView: UIViewRepresentable {
    @ObservedObject var controller: PiPSubtitleController

    func makeUIView(context: Context) -> PiPSubtitleContainerView {
        let view = PiPSubtitleContainerView()
        view.backgroundColor = .clear
        view.attach(controller.displayLayer)
        return view
    }

    func updateUIView(_ uiView: PiPSubtitleContainerView, context: Context) {
        uiView.attach(controller.displayLayer)
        controller.attachDisplayLayer(to: uiView)
    }
}

final class PiPSubtitleContainerView: UIView {
    private weak var hostedLayer: AVSampleBufferDisplayLayer?

    func attach(_ layer: AVSampleBufferDisplayLayer) {
        hostedLayer = layer
        if layer.superlayer !== self.layer {
            layer.removeFromSuperlayer()
            self.layer.addSublayer(layer)
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        hostedLayer?.frame = bounds
    }
}
