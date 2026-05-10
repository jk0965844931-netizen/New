import ReplayKit
import SwiftUI

struct BroadcastPickerView: UIViewRepresentable {
    let preferredExtensionBundleIdentifier: String

    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: .zero)
        picker.preferredExtension = preferredExtensionBundleIdentifier
        picker.showsMicrophoneButton = true
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {
        uiView.preferredExtension = preferredExtensionBundleIdentifier
        uiView.showsMicrophoneButton = true
    }
}
