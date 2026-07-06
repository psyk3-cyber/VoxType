import SwiftUI
import AppKit
import Combine

/// First-run permission checklist: Microphone, Speech Recognition,
/// and Accessibility (needed for the global hotkey and pasting).
struct OnboardingView: View {
    @State private var micGranted = PermissionHelper.microphoneGranted
    @State private var speechGranted = PermissionHelper.speechGranted
    @State private var axGranted = PermissionHelper.accessibilityGranted

    var onComplete: () -> Void

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading) {
                    Text("Welcome to VoxType")
                        .font(.title2).bold()
                    Text("Hold the fn key and speak — your words appear in any app.")
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            permissionRow(
                title: "Microphone",
                detail: "Captures your voice while the hotkey is held.",
                granted: micGranted,
                action: {
                    PermissionHelper.requestMicrophone { granted in
                        micGranted = granted
                        if !granted { PermissionHelper.openMicrophoneSettings() }
                    }
                }
            )

            permissionRow(
                title: "Speech Recognition",
                detail: "Transcribes your voice with Apple’s speech engine.",
                granted: speechGranted,
                action: {
                    PermissionHelper.requestSpeech { granted in
                        speechGranted = granted
                        if !granted { PermissionHelper.openSpeechSettings() }
                    }
                }
            )

            permissionRow(
                title: "Accessibility",
                detail: "Lets VoxType watch the fn key globally and paste text into other apps.",
                granted: axGranted,
                action: {
                    PermissionHelper.promptAccessibility()
                    PermissionHelper.openAccessibilitySettings()
                }
            )

            Divider()

            Text("Recommended: System Settings → Keyboard → “Press 🌐 key to” → **Do Nothing**, so fn is reserved for VoxType.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Spacer()
                Button(allGranted ? "Start Flowing" : "Continue Anyway") {
                    onComplete()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 520)
        .onReceive(timer) { _ in
            micGranted = PermissionHelper.microphoneGranted
            speechGranted = PermissionHelper.speechGranted
            axGranted = PermissionHelper.accessibilityGranted
        }
    }

    private var allGranted: Bool { micGranted && speechGranted && axGranted }

    @ViewBuilder
    private func permissionRow(title: String, detail: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundColor(granted ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if !granted {
                Button("Grant", action: action)
            }
        }
    }
}

final class OnboardingWindowController {
    static let shared = OnboardingWindowController()
    private var window: NSWindow?

    func showIfNeeded() {
        guard !PermissionHelper.allGranted else { return }
        show()
    }

    func show() {
        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 460),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            w.title = "VoxType Setup"
            w.contentView = NSHostingView(rootView: OnboardingView { [weak self] in
                self?.window?.close()
            })
            w.center()
            w.isReleasedWhenClosed = false
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
