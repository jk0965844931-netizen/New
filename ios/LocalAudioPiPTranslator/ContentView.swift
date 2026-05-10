import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var audioSession: LocalAudioSessionController

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    controls
                    limitationCard
                    transcriptCard
                    Spacer(minLength: 120)
                }
                .padding(20)
            }
            .background(AppGradient().ignoresSafeArea())

            if audioSession.isOverlayVisible {
                FloatingTranslationOverlay()
                    .environmentObject(audioSession)
                    .padding()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Local Audio PiP Translator")
                .font(.largeTitle.bold())
            Text("ฟังเสียงจากไมค์หรือ pipeline แบบ ReplayKit, ถอดเสียงและแปลในเครื่อง แล้วแสดงผลแบบ floating PiP-style")
                .foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Capture mode", selection: $audioSession.captureMode) {
                ForEach(LocalAudioSessionController.CaptureMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                VStack(alignment: .leading) {
                    Text("State")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(audioSession.engineState.rawValue)
                        .font(.headline)
                }
                Spacer()
                Text("~\(audioSession.latencyMillis) ms")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.green)
            }

            HStack {
                Button("Start") {
                    Task { await audioSession.start() }
                }
                .buttonStyle(.borderedProminent)

                Button("Stop") {
                    audioSession.stop()
                }
                .buttonStyle(.bordered)

                Button("Demo line") {
                    audioSession.simulateGameLine()
                }
                .buttonStyle(.bordered)
            }

            Toggle("Show PiP-style overlay", isOn: $audioSession.isOverlayVisible)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var limitationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("ข้อจำกัด iOS ที่ต้องออกแบบให้ถูกต้อง", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
            Text("iOS ไม่อนุญาตให้แอปทั่วไปดักฟัง system audio จากเพลง/เกมอื่นโดยตรงแบบเงียบ ๆ ต้องใช้ไมค์, SharePlay/Audio Session ที่ได้รับอนุญาต, หรือ ReplayKit Broadcast Extension ที่ผู้ใช้เริ่มเอง ส่วน PiP ของ iOS ต้องผูกกับ video layer; ตัวอย่างนี้ทำ floating overlay ในแอปและเตรียมโครงให้ต่อ extension ได้")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Live transcript")
                .font(.headline)
            Text(audioSession.partialTranscript)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))
            Text("Local translation")
                .font(.headline)
            Text(audioSession.translatedText)
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.purple.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct FloatingTranslationOverlay: View {
    @EnvironmentObject private var audioSession: LocalAudioSessionController

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle().fill(.green).frame(width: 9, height: 9)
                Text("LOCAL • REALTIME")
                    .font(.caption.bold())
                Spacer()
                Text("\(audioSession.latencyMillis)ms")
                    .font(.caption.monospacedDigit())
            }
            Text(audioSession.translatedText)
                .font(.headline)
                .lineLimit(3)
        }
        .padding(14)
        .foregroundStyle(.white)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.18))
        )
        .shadow(radius: 18)
    }
}

struct AppGradient: View {
    var body: some View {
        LinearGradient(
            colors: [Color(red: 0.04, green: 0.06, blue: 0.12), Color(red: 0.16, green: 0.07, blue: 0.28)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(LocalAudioSessionController())
}
