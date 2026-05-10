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

    struct LanguageOption: Identifiable, Hashable {
        let id: String
        let title: String
        let speechCode: String?
        let voiceCode: String
    }

    struct TranslationEntry: Identifiable, Equatable {
        let id = UUID()
        let source: String
        let translated: String
        let mode: CaptureMode
        let timestamp: Date
    }

    static let sourceLanguages: [LanguageOption] = [
        .init(id: "auto", title: "Auto", speechCode: nil, voiceCode: "en-US"),
        .init(id: "en", title: "English", speechCode: "en-US", voiceCode: "en-US"),
        .init(id: "ja", title: "Japanese", speechCode: "ja-JP", voiceCode: "ja-JP"),
        .init(id: "ko", title: "Korean", speechCode: "ko-KR", voiceCode: "ko-KR"),
        .init(id: "zh", title: "Chinese", speechCode: "zh-Hans", voiceCode: "zh-CN"),
        .init(id: "th", title: "Thai", speechCode: "th-TH", voiceCode: "th-TH")
    ]

    static let targetLanguages: [LanguageOption] = [
        .init(id: "th", title: "Thai", speechCode: "th-TH", voiceCode: "th-TH"),
        .init(id: "en", title: "English", speechCode: "en-US", voiceCode: "en-US"),
        .init(id: "ja", title: "Japanese", speechCode: "ja-JP", voiceCode: "ja-JP"),
        .init(id: "ko", title: "Korean", speechCode: "ko-KR", voiceCode: "ko-KR"),
        .init(id: "zh", title: "Chinese", speechCode: "zh-Hans", voiceCode: "zh-CN")
    ]

    @Published var captureMode: CaptureMode = .microphone
    @Published var engineState: EngineState = .idle
    @Published var sourceLanguageId = "auto"
    @Published var targetLanguageId = "th"
    @Published var partialTranscript = "Press Start to request local speech and microphone permission."
    @Published var translatedText = "คำแปลจะแสดงตรงนี้แบบ floating / PiP-style"
    @Published var isOverlayVisible = true
    @Published var shouldSpeakTranslation = true
    @Published var subtitleFontSize = 20.0
    @Published var subtitleBackground = "Dark"
    @Published var latencyMillis = 0
    @Published var broadcastStatus = "Broadcast extension bridge is idle."
    @Published private(set) var history: [TranslationEntry] = []

    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var lastCommittedTranscript = ""
    private var broadcastImportTimer: Timer?

    private let localDictionary: [String: [String: String]] = [
        "th": [
            "hello": "สวัสดี",
            "thank you": "ขอบคุณ",
            "sorry": "ขอโทษ",
            "go go go": "ไป ไป ไป",
            "enemy spotted": "เจอศัตรูแล้ว",
            "the song is ending": "เพลงกำลังจะจบ",
            "i love you": "ฉันรักเธอ",
            "watch foreign videos with live subtitles": "ดูวิดีโอต่างภาษาพร้อมซับสด",
            "speak and get instant translation": "พูดแล้วรับคำแปลทันที"
        ],
        "en": [
            "สวัสดี": "Hello",
            "ขอบคุณ": "Thank you",
            "ขอโทษ": "Sorry",
            "เจอศัตรูแล้ว": "Enemy spotted",
            "ไป ไป ไป": "Go go go"
        ],
        "ja": [
            "hello": "こんにちは",
            "thank you": "ありがとうございます",
            "enemy spotted": "敵を発見"
        ],
        "ko": [
            "hello": "안녕하세요",
            "thank you": "감사합니다",
            "enemy spotted": "적 발견"
        ],
        "zh": [
            "hello": "你好",
            "thank you": "谢谢",
            "enemy spotted": "发现敌人"
        ]
    ]

    var selectedSourceLanguage: LanguageOption {
        Self.sourceLanguages.first { $0.id == sourceLanguageId } ?? Self.sourceLanguages[0]
    }

    var selectedTargetLanguage: LanguageOption {
        Self.targetLanguages.first { $0.id == targetLanguageId } ?? Self.targetLanguages[0]
    }

    func start() async {
        stop()
        engineState = .requestingPermission
        partialTranscript = "Requesting local speech and microphone permission…"

        let speechStatus = await requestSpeechAuthorization()
        guard speechStatus == .authorized else {
            engineState = .blocked
            partialTranscript = "Speech recognition permission was denied."
            translatedText = "เปิดสิทธิ์ Speech Recognition ใน Settings ก่อนใช้งาน"
            return
        }

        let microphoneAllowed = await requestMicrophoneAuthorization()
        guard microphoneAllowed else {
            engineState = .blocked
            partialTranscript = "Microphone permission was denied."
            translatedText = "เปิดสิทธิ์ Microphone ใน Settings ก่อนใช้งาน"
            return
        }

        do {
            try configureAudioSession()
            try startMicrophoneRecognition()
            engineState = .running
            partialTranscript = captureMode == .microphone
                ? "Listening to microphone locally on device…"
                : "ReplayKit mode selected: add a Broadcast Upload Extension to feed app/game audio buffers into this same translator pipeline."
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
        synthesizer.stopSpeaking(at: .immediate)
        stopBroadcastImport()

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
            "Thank you",
            "Watch foreign videos with live subtitles",
            "Speak and get instant translation"
        ]
        commitTranscript(samples.randomElement() ?? "Hello", isFinal: true)
        engineState = .running
        latencyMillis = Int.random(in: 80...220)
    }

    func clearHistory() {
        history.removeAll()
        lastCommittedTranscript = ""
    }

    func startBroadcastImport() {
        broadcastImportTimer?.invalidate()
        broadcastStatus = "Polling App Group subtitles from Broadcast Upload Extension…"
        broadcastImportTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.loadLatestBroadcastSubtitle()
            }
        }
    }

    func stopBroadcastImport() {
        broadcastImportTimer?.invalidate()
        broadcastImportTimer = nil
        if broadcastStatus.hasPrefix("Polling") {
            broadcastStatus = "Broadcast extension bridge is idle."
        }
    }

    func loadLatestBroadcastSubtitle() {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroupConfig.groupIdentifier) else {
            broadcastStatus = "App Group is unavailable. Configure the shared group entitlement before device testing."
            return
        }

        let url = container.appendingPathComponent(AppGroupConfig.latestSubtitleFileName)
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(BroadcastSubtitlePayload.self, from: data) else {
            broadcastStatus = "Waiting for Broadcast Upload Extension samples…"
            return
        }

        partialTranscript = payload.sourceText
        translatedText = payload.translatedText
        broadcastStatus = "Updated from ReplayKit broadcast at \(payload.updatedAt.formatted(date: .omitted, time: .standard))."

        if payload.sourceText != lastCommittedTranscript {
            lastCommittedTranscript = payload.sourceText
            history.insert(.init(source: payload.sourceText, translated: payload.translatedText, mode: .replayKit, timestamp: payload.updatedAt), at: 0)
            history = Array(history.prefix(20))
            speakIfNeeded(payload.translatedText)
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startMicrophoneRecognition() throws {
        let locale = selectedSourceLanguage.speechCode.map(Locale.init(identifier:)) ?? Locale.current
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
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
                    self.latencyMillis = max(1, Int(Date().timeIntervalSince(startedAt) * 1000) % 1000)
                    self.commitTranscript(text, isFinal: result.isFinal)
                }
                if let error {
                    self.engineState = .blocked
                    self.partialTranscript = error.localizedDescription
                }
            }
        }
    }

    private func commitTranscript(_ text: String, isFinal: Bool) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        let translated = translateLocally(cleaned)
        partialTranscript = cleaned
        translatedText = translated

        if isFinal || shouldCommitPartial(cleaned) {
            guard cleaned != lastCommittedTranscript else { return }
            lastCommittedTranscript = cleaned
            history.insert(.init(source: cleaned, translated: translated, mode: captureMode, timestamp: Date()), at: 0)
            history = Array(history.prefix(20))
            speakIfNeeded(translated)
        }
    }

    private func shouldCommitPartial(_ text: String) -> Bool {
        text.count >= 16 && abs(text.count - lastCommittedTranscript.count) >= 8
    }

    private func speakIfNeeded(_ translated: String) {
        guard shouldSpeakTranslation else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: translated)
        utterance.voice = AVSpeechSynthesisVoice(language: selectedTargetLanguage.voiceCode)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        synthesizer.speak(utterance)
    }

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }

    private func translateLocally(_ text: String) -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let translated = localDictionary[targetLanguageId]?[normalized] { return translated }
        return "[\(selectedTargetLanguage.title)] \(text)"
    }
}

enum LocalAudioError: LocalizedError {
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "On-device speech recognizer is not available for the selected source language on this device."
        }
    }
}
