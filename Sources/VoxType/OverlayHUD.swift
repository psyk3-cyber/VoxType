import AppKit
import SwiftUI

enum HUDState: Equatable {
    case hidden
    case recording
    case processing
    case notice(String)
}

enum HUDMode {
    case dictation
    case handsFree
    case command
    case prompt
}

final class HUDModel: ObservableObject {
    @Published var state: HUDState = .hidden
    @Published var mode: HUDMode = .dictation
    @Published var transcript: String = ""
    @Published var level: Float = 0
    @Published var processingLabel: String = "Polishing…"
}

/// The floating pill that appears at the bottom of the screen while
/// recording — waveform, live transcript, and status messages.
final class HUDController {
    let model = HUDModel()
    private var panel: NSPanel?
    private var hideWorkItem: DispatchWorkItem?

    func showRecording(mode: HUDMode) {
        hideWorkItem?.cancel()
        model.mode = mode
        model.transcript = ""
        model.level = 0
        model.state = .recording
        show()
    }

    func showProcessing(label: String = "Polishing…") {
        hideWorkItem?.cancel()
        model.processingLabel = label
        model.state = .processing
        show()
    }

    func showNotice(_ text: String, duration: TimeInterval = 2.0) {
        hideWorkItem?.cancel()
        model.state = .notice(text)
        show()
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    func updateTranscript(_ text: String) {
        model.transcript = text
    }

    func updateLevel(_ level: Float) {
        model.level = level
    }

    func hide() {
        hideWorkItem?.cancel()
        model.state = .hidden
        panel?.orderOut(nil)
    }

    private func show() {
        if panel == nil {
            panel = makePanel()
        }
        guard let panel else { return }
        position(panel)
        panel.orderFrontRegardless()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 110),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: HUDView(model: model))
        return panel
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        let x = frame.midX - size.width / 2
        let y = frame.minY + 60
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

// MARK: - SwiftUI view

struct HUDView: View {
    @ObservedObject var model: HUDModel

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            content
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.82))
                        .shadow(color: .black.opacity(0.35), radius: 14, y: 4)
                )
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(model.state == .hidden ? 0 : 1)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .hidden:
            EmptyView()
        case .recording:
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 9, height: 9)
                    Text(headerText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                    Spacer(minLength: 0)
                    WaveformView(level: model.level, color: waveColor)
                        .frame(width: 110, height: 22)
                }
                if !model.transcript.isEmpty {
                    Text(model.transcript)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .truncationMode(.head)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(width: 360)
        case .processing:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text(model.processingLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
            }
        case .notice(let text):
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
                .frame(maxWidth: 360)
        }
    }

    private var headerText: String {
        switch model.mode {
        case .dictation: return "Listening — release to insert · esc to cancel"
        case .handsFree: return "Hands-free — tap shortcut to finish · esc to cancel"
        case .command: return "Command Mode — speak an instruction"
        case .prompt: return "Prompt Mode — talk through your idea naturally"
        }
    }

    private var accentColor: Color {
        switch model.mode {
        case .command: return .purple
        case .prompt: return .cyan
        default: return .red
        }
    }

    private var waveColor: Color {
        switch model.mode {
        case .command: return .purple
        case .prompt: return .cyan
        default: return Color(red: 1, green: 0.4, blue: 0.4)
        }
    }
}

struct WaveformView: View {
    var level: Float
    var color: Color

    private let barCount = 16

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(width: 3, height: barHeight(index))
            }
        }
        .animation(.easeOut(duration: 0.12), value: level)
    }

    private func barHeight(_ index: Int) -> CGFloat {
        // Deterministic per-bar shaping so the waveform looks organic.
        let phase = sin(Double(index) * 1.7 + Double(level) * 6)
        let jitter = 0.55 + 0.45 * abs(phase)
        let height = 4 + CGFloat(level) * 18 * CGFloat(jitter)
        return max(4, min(22, height))
    }
}
