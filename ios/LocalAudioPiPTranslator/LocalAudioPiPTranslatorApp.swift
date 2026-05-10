import SwiftUI

@main
struct LocalAudioPiPTranslatorApp: App {
    @StateObject private var audioSession = LocalAudioSessionController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioSession)
        }
    }
}
