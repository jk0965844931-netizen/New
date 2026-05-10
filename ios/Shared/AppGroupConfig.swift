import Foundation

enum AppGroupConfig {
    static let groupIdentifier = "group.dev.local.audio-pip-translator"
    static let latestSubtitleFileName = "latest-subtitle.json"
    static let broadcastHeartbeatName = "dev.local.audio-pip-translator.broadcast-heartbeat"
}

struct BroadcastSubtitlePayload: Codable, Equatable {
    let sourceText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let updatedAt: Date
}
