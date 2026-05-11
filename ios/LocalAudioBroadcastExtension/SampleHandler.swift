import AVFoundation
import Foundation
import ReplayKit

final class SampleHandler: RPBroadcastSampleHandler {
    private let writer = BroadcastSharedSubtitleWriter()
    private var audioAppSampleCount = 0
    private var audioMicSampleCount = 0
    private var videoFrameCount = 0

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        writer.write(
            sourceText: "Broadcast started",
            translatedText: "เริ่มรับ Screen Recording จาก Broadcast Upload Extension แล้ว",
            sourceLanguage: "system",
            targetLanguage: "th"
        )
    }

    override func broadcastPaused() {
        writer.write(
            sourceText: "Broadcast paused",
            translatedText: "หยุด Broadcast ชั่วคราว",
            sourceLanguage: "system",
            targetLanguage: "th"
        )
    }

    override func broadcastResumed() {
        writer.write(
            sourceText: "Broadcast resumed",
            translatedText: "กลับมารับ Broadcast ต่อแล้ว",
            sourceLanguage: "system",
            targetLanguage: "th"
        )
    }

    override func broadcastFinished() {
        writer.write(
            sourceText: "Broadcast finished",
            translatedText: "สิ้นสุด Broadcast แล้ว",
            sourceLanguage: "system",
            targetLanguage: "th"
        )
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .audioApp:
            audioAppSampleCount += 1
            handleScreenAudioSample(kind: "screen app audio", count: audioAppSampleCount)
        case .audioMic:
            audioMicSampleCount += 1
            handleOptionalMicrophoneSample(count: audioMicSampleCount)
        case .video:
            videoFrameCount += 1
            handleVideoFrame(count: videoFrameCount)
        @unknown default:
            break
        }
    }

    private func handleScreenAudioSample(kind: String, count: Int) {
        guard count == 1 || count.isMultiple(of: 180) else { return }
        writer.write(
            sourceText: "Screen recording includes \(kind) buffers #\(count)",
            translatedText: "Screen Recording ส่งเสียงของแอปมาพร้อม broadcast #\(count)",
            sourceLanguage: "system",
            targetLanguage: "th"
        )
    }

    private func handleOptionalMicrophoneSample(count: Int) {
        guard count == 1 || count.isMultiple(of: 180) else { return }
        writer.write(
            sourceText: "Optional microphone track #\(count)",
            translatedText: "พบไมค์เสริมจาก Broadcast picker แต่โหมดหลักคือ Screen Recording",
            sourceLanguage: "system",
            targetLanguage: "th"
        )
    }

    private func handleVideoFrame(count: Int) {
        guard count == 1 || count.isMultiple(of: 300) else { return }
        writer.write(
            sourceText: "Receiving screen frames #\(count)",
            translatedText: "กำลังรับภาพหน้าจอผ่าน ReplayKit #\(count)",
            sourceLanguage: "system",
            targetLanguage: "th"
        )
    }
}

private final class BroadcastSharedSubtitleWriter {
    func write(sourceText: String, translatedText: String, sourceLanguage: String, targetLanguage: String) {
        let payload = BroadcastSubtitlePayload(
            sourceText: sourceText,
            translatedText: translatedText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            updatedAt: Date()
        )

        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroupConfig.groupIdentifier) else {
            return
        }

        let url = container.appendingPathComponent(AppGroupConfig.latestSubtitleFileName)
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: url, options: .atomic)
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                CFNotificationName(AppGroupConfig.broadcastHeartbeatName as CFString),
                nil,
                nil,
                true
            )
        }
    }
}
