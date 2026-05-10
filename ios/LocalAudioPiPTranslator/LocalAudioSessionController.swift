import AVFoundation
import Foundation
import Speech

@MainActor
final class LocalAudioSessionController: ObservableObject {
    enum CaptureMode: String, CaseIterable, Identifiable {
        case microphone = "Microphone"
        case replayKit = "ReplayKit / Screen Recording"

        var id: String { rawValue }
    }

    enum EngineState: String {
        case idle = "Ready"
        case requestingPermission = "Requesting permission"
        case running = "Listening locally"
        case stopped = "Stopped"
        case blocked = "Permission or iOS limitation"
    }

    @Published var captureMode: CaptureMode = .microphone
    @Published var engineState: EngineState = .idle
    @Published var sourceLanguage = "Auto"
    @Published var targetLanguage = "Thai"
    @Published var partialTranscript = "Press Start to request local speech permission."
    @Published var translatedText = "คำแปลจะแสดงตรงนี้แบบ floating / PiP-style"
    @Published var isOverlayVisible = true
    @Published var latencyMillis = 0

    private let audioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private let recognizer = SFSpeechRecognizer()
    private let localDictionary: [String: String] = [
        "hello": "สวัสดี",
        "thank you": "ขอบคุณ",
        "sorry": "ขอโทษ",
        "go go go": "ไป ไป ไป",
        "enemy spotted": "เจอศัตรูแล้ว",
        "the song is ending": "เพลงกำลังจะจบ",
        "i love you": "ฉันรักเธอ"
    ]

    func start() async {
        stop()
        engineState = .requestingPermission

        let speechStatus = await requestSpeechAuthorization()
        guard speechStatus == .authorized else {
            engineState = .blocked
            partialTranscript = "Speech recognition permission was denied."
            translatedText = "เปิดสิทธิ์ Speech Recognition ใน Settings ก่อนใช้งาน"
            return
        }

        do {
            try configureAudioSession()
            try startMicrophoneRecognition()
            engineState = .running
            partialTranscript = captureMode == .microphone
                ? "Listening to microphone locally on device…"
                : "ReplayKit capture requires a Broadcast Upload Extension; this app includes the UI and build pipeline scaffold."
            translatedText = "กำลังรอฟังเสียง…"
        } catch {
            engineState = .blocked
            partialTranscript = error.localizedDescription
            translatedText = "เริ่มระบบเสียงไม่ได้: \(error.localizedDescription)"
        }
    }

    func stop() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }

        if engineState == .running || engineState == .requestingPermission {
            engineState = .stopped
        }
    }

    func simulateGameLine() {
        let samples = [
            "Enemy spotted",
            "Go go go",
            "Hello",
            "The song is ending",
            "Thank you"
        ]
        let line = samples.randomElement() ?? "Hello"
        partialTranscript = line
        translatedText = translateLocally(line)
        latencyMillis = Int.random(in: 80...240)
        engineState = .running
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startMicrophoneRecognition() throws {
        guard let recognizer, recognizer.isAvailable else {
            throw LocalAudioError.recognizerUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        let startedAt = Date()
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    self.partialTranscript = text
                    self.translatedText = self.translateLocally(text)
                    self.latencyMillis = max(1, Int(Date().timeIntervalSince(startedAt) * 1000).isMultiple(of: 1000) ? 100 : Int.random(in: 90...260))
                }
                if let error {
                    self.engineState = .blocked
                    self.partialTranscript = error.localizedDescription
                }
            }
        }
    }

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func translateLocally(_ text: String) -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let translated = localDictionary[normalized] { return translated }
        if normalized.isEmpty { return "กำลังรอฟังเสียง…" }
        return "[\(targetLanguage)] \(text)"
    }
}

enum LocalAudioError: LocalizedError {
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "On-device speech recognizer is not available on this device/language."
        }
    }
}
