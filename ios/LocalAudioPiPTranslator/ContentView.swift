import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var audioSession: LocalAudioSessionController
    @StateObject private var pipSubtitleController = PiPSubtitleController()

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    controls
                    subtitleStyleCard
                    viitorPipelineCard
                    limitationCard
                    transcriptCard
                    historyCard
                    Spacer(minLength: 140)
                }
                .padding(20)
            }
            .background(AppGradient().ignoresSafeArea())

            if audioSession.isOverlayVisible {
                FloatingTranslationOverlay()
                    .environmentObject(audioSession)
                    .padding()
            }

            if pipSubtitleController.showsSafeMovableOverlay {
                DraggableSubtitleOverlay(
                    translatedText: audioSession.translatedText,
                    transcript: audioSession.partialTranscript,
                    onClose: { pipSubtitleController.hideSafeMovableOverlay() }
                )
                .padding()
            }
        }
        .onChange(of: audioSession.translatedText) { newValue in
            pipSubtitleController.updateSubtitle(newValue, transcript: audioSession.partialTranscript)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Screen Broadcast PiP Translator")
                .font(.largeTitle.bold())
            Text("แนว ViiTor-style: เริ่มจาก Screen Recording/Broadcast ของ iOS แล้วแสดงซับใน System PiP ที่ผู้ใช้ลากขยับได้แบบ YouTube")
                .foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Input source", selection: $audioSession.captureMode) {
                ForEach(LocalAudioSessionController.CaptureMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                Picker("From", selection: $audioSession.sourceLanguageId) {
                    ForEach(LocalAudioSessionController.sourceLanguages) { language in
                        Text(language.title).tag(language.id)
                    }
                }
                Picker("To", selection: $audioSession.targetLanguageId) {
                    ForEach(LocalAudioSessionController.targetLanguages) { language in
                        Text(language.title).tag(language.id)
                    }
                }
            }
            .pickerStyle(.menu)

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

                Button("Demo subtitle") {
                    audioSession.simulateGameLine()
                }
                .buttonStyle(.bordered)
            }

            Toggle("Show floating subtitles", isOn: $audioSession.isOverlayVisible)
            Toggle("Speak translated voice", isOn: $audioSession.shouldSpeakTranslation)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var subtitleStyleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Subtitle style", systemImage: "captions.bubble.fill")
                .font(.headline)
            Slider(value: $audioSession.subtitleFontSize, in: 14...34, step: 1) {
                Text("Font size")
            } minimumValueLabel: {
                Text("A")
            } maximumValueLabel: {
                Text("A+")
            }
            Picker("Background", selection: $audioSession.subtitleBackground) {
                Text("Dark").tag("Dark")
                Text("Purple").tag("Purple")
                Text("Clear").tag("Clear")
            }
            .pickerStyle(.segmented)
            Text("ปรับซับลอยแบบที่แอปแปลสดนิยมมี: ขนาดตัวอักษร, สีพื้นหลัง, และเปิด/ปิดเสียงแปล")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var viitorPipelineCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Screen Recording + movable System PiP", systemImage: "pip.enter")
                .font(.headline)

            Text("1) ผู้ใช้เริ่ม Screen Recording/Broadcast ผ่านปุ่มของ iOS  2) Broadcast Upload Extension รับเฟรมหน้าจอและ app audio ที่มากับ broadcast  3) แอปอ่านซับผ่าน App Group  4) เปิด System PiP จริงที่ iOS ให้ผู้ใช้ลาก/ขยับได้เหมือน YouTube PiP")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                BroadcastPickerView(preferredExtensionBundleIdentifier: "dev.local.audio-pip-translator.broadcast")
                    .frame(width: 52, height: 52)
                    .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Screen Broadcast")
                        .font(.subheadline.bold())
                    Text("กดเพื่อเปิด Screen Recording picker ทางการของ ReplayKit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack {
                Button("Import screen subtitles") {
                    audioSession.startBroadcastImport()
                }
                .buttonStyle(.borderedProminent)

                Button("Refresh once") {
                    audioSession.loadLatestBroadcastSubtitle()
                }
                .buttonStyle(.bordered)

                Button("Stop import") {
                    audioSession.stopBroadcastImport()
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Button("Show safe movable subtitles") {
                    pipSubtitleController.updateSubtitle(audioSession.translatedText, transcript: audioSession.partialTranscript)
                    pipSubtitleController.showSafeMovableOverlay()
                }
                .buttonStyle(.borderedProminent)

                Button("Try System PiP") {
                    pipSubtitleController.allowsExperimentalSystemPiP = true
                    pipSubtitleController.updateSubtitle(audioSession.translatedText, transcript: audioSession.partialTranscript)
                    pipSubtitleController.startPictureInPicture()
                }
                .buttonStyle(.bordered)

                Button("Stop") {
                    pipSubtitleController.stopPictureInPicture()
                }
                .buttonStyle(.bordered)
            }

            Text(audioSession.broadcastStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(pipSubtitleController.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Experimental System PiP (may black-screen on some unsigned builds)", isOn: $pipSubtitleController.allowsExperimentalSystemPiP)
                .font(.caption)
            Text(pipSubtitleController.systemPiPDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            PiPSubtitlePreviewView(controller: pipSubtitleController)
                .frame(height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.18))
                )
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var limitationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("ทำให้ใกล้ ViiTor โดยไม่ฝืนข้อจำกัด iOS", systemImage: "checkmark.shield.fill")
                .font(.headline)
            Text("โหมดหลักคือ Screen Recording/Broadcast: ผู้ใช้กดเริ่มเองผ่าน ReplayKit แล้วระบบส่งเฟรมหน้าจอพร้อมเสียงของแอปที่ broadcast มาให้ extension ส่วนซับลอยใช้ System Picture-in-Picture จริง ไม่ใช่ overlay เถื่อน จึงลาก/ขยับได้ตามกฎ iOS เหมือน YouTube PiP")
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

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Conversation history")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    audioSession.clearHistory()
                }
                .buttonStyle(.bordered)
            }

            if audioSession.history.isEmpty {
                Text("ยังไม่มีซับที่แปล กด Demo subtitle หรือเริ่ม Screen Broadcast")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(audioSession.history) { entry in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(entry.mode.rawValue)
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(entry.timestamp, style: .time)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Text(entry.source)
                            .font(.callout)
                        Text(entry.translated)
                            .font(.headline)
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct DraggableSubtitleOverlay: View {
    let translatedText: String
    let transcript: String
    let onClose: () -> Void

    @State private var offset = CGSize(width: 0, height: -120)
    @State private var dragStart = CGSize.zero

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(.green).frame(width: 9, height: 9)
                Text("SAFE MOVABLE SUBTITLES")
                    .font(.caption.bold())
                Spacer()
                Button("×", action: onClose)
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)
            }
            Text(translatedText.isEmpty ? "รอคำแปลจาก Screen Broadcast…" : translatedText)
                .font(.title3.bold())
                .lineLimit(3)
            Text(transcript.isEmpty ? "ลากกล่องนี้ไปตำแหน่งที่ต้องการได้" : transcript)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(2)
        }
        .padding(14)
        .foregroundStyle(.white)
        .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.18))
        )
        .shadow(radius: 20)
        .frame(maxWidth: 430)
        .offset(offset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    offset = CGSize(width: dragStart.width + value.translation.width, height: dragStart.height + value.translation.height)
                }
                .onEnded { _ in
                    dragStart = offset
                }
        )
        .transition(.scale.combined(with: .opacity))
    }
}

struct FloatingTranslationOverlay: View {
    @EnvironmentObject private var audioSession: LocalAudioSessionController

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle().fill(.green).frame(width: 9, height: 9)
                Text("LOCAL • VOICE • REALTIME")
                    .font(.caption.bold())
                Spacer()
                Text("\(audioSession.latencyMillis)ms")
                    .font(.caption.monospacedDigit())
            }
            Text(audioSession.translatedText)
                .font(.system(size: audioSession.subtitleFontSize, weight: .bold, design: .rounded))
                .lineLimit(4)
            Text(audioSession.partialTranscript)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(2)
        }
        .padding(14)
        .foregroundStyle(.white)
        .background(overlayBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.18))
        )
        .shadow(radius: 18)
    }

    private var overlayBackground: Color {
        switch audioSession.subtitleBackground {
        case "Purple": return Color.purple.opacity(0.78)
        case "Clear": return Color.black.opacity(0.35)
        default: return Color.black.opacity(0.78)
        }
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

#if DEBUG
#Preview {
    ContentView()
        .environmentObject(LocalAudioSessionController())
}
#endif
