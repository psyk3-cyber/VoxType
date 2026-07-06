import AppKit
import Speech

/// Orchestrates the whole dictation pipeline:
/// record → transcribe → polish → insert into the frontmost app.
final class DictationController: ObservableObject {

    enum Mode {
        case dictation
        case command
    }

    enum State {
        case idle
        case recording(Mode)
        case processing
    }

    @Published private(set) var state: State = .idle
    private(set) var isHandsFree = false

    let hud = HUDController()
    private let transcriber = TranscriptionService()
    private let settings = AppSettings.shared
    private var recordingStartedAt = Date()
    private var sessionLimitTimer: Timer?

    var onStateChange: (() -> Void)?

    var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    var isBusy: Bool {
        if case .idle = state { return false }
        return true
    }

    var isCommandRecording: Bool {
        if case .recording(.command) = state { return true }
        return false
    }

    init() {
        transcriber.onPartial = { [weak self] text in
            self?.hud.updateTranscript(text)
        }
        transcriber.onLevel = { [weak self] level in
            self?.hud.updateLevel(level)
        }
    }

    // MARK: - Recording lifecycle

    func startRecording(mode: Mode, handsFree: Bool) {
        guard case .idle = state else {
            hud.showNotice("Still processing the previous dictation…")
            return
        }
        guard PermissionHelper.microphoneGranted, PermissionHelper.speechGranted else {
            hud.showNotice("Grant Microphone and Speech Recognition permissions first.")
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        do {
            try transcriber.start(
                locale: settings.locale,
                preferOnDevice: settings.preferOnDevice,
                contextualStrings: settings.contextualStrings
            )
        } catch {
            hud.showNotice(error.localizedDescription, duration: 3)
            return
        }

        isHandsFree = handsFree
        recordingStartedAt = Date()
        state = .recording(mode)
        onStateChange?()

        let hudMode: HUDMode = (mode == .command) ? .command : (handsFree ? .handsFree : .dictation)
        hud.showRecording(mode: hudMode)
        playSound("Pop")

        // Mirror Wispr Flow's 20-minute session cap.
        sessionLimitTimer?.invalidate()
        sessionLimitTimer = Timer.scheduledTimer(withTimeInterval: 20 * 60, repeats: false) { [weak self] _ in
            self?.finishRecording()
        }
    }

    /// Upgrade an in-progress dictation to Command Mode (Ctrl added
    /// right after the trigger went down).
    func upgradeToCommandMode() {
        guard case .recording(.dictation) = state,
              Date().timeIntervalSince(recordingStartedAt) < 0.6 else { return }
        state = .recording(.command)
        hud.showRecording(mode: .command)
        onStateChange?()
    }

    func finishRecording() {
        guard case .recording(let mode) = state else { return }
        sessionLimitTimer?.invalidate()
        state = .processing
        onStateChange?()
        hud.showProcessing()
        playSound("Bottle")

        let frontApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"

        transcriber.stop { [weak self] transcript in
            guard let self else { return }
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                self.hud.showNotice("Didn't catch anything.")
                self.becomeIdle()
                return
            }
            switch mode {
            case .dictation:
                self.handleDictation(trimmed, frontApp: frontApp)
            case .command:
                self.handleCommand(trimmed)
            }
        }
    }

    func cancelRecording() {
        guard isRecording else { return }
        sessionLimitTimer?.invalidate()
        transcriber.cancel()
        hud.hide()
        becomeIdle()
        playSound("Basso")
    }

    /// Cancel silently (used when a quick tap turns out to be the first
    /// half of a double-tap).
    func abortQuietly() {
        guard isRecording else { return }
        sessionLimitTimer?.invalidate()
        transcriber.cancel()
        hud.hide()
        becomeIdle()
    }

    func toggleHandsFree() {
        if isRecording {
            finishRecording()
        } else {
            startRecording(mode: .dictation, handsFree: true)
        }
    }

    private func becomeIdle() {
        state = .idle
        isHandsFree = false
        onStateChange?()
    }

    // MARK: - Dictation pipeline

    private func handleDictation(_ transcript: String, frontApp: String) {
        let local = TextPolisher.polish(transcript, settings: settings)

        if settings.aiPolishEnabled && !settings.openAIKey.isEmpty {
            Task { @MainActor in
                var finalText = local.text
                do {
                    let polished = try await LLMService.polishDictation(local.text)
                    if !polished.isEmpty { finalText = polished }
                } catch {
                    // Fall back to the locally polished text.
                }
                self.deliver(finalText, pressEnter: local.pressEnter, frontApp: frontApp)
            }
        } else {
            deliver(local.text, pressEnter: local.pressEnter, frontApp: frontApp)
        }
    }

    private func deliver(_ text: String, pressEnter: Bool, frontApp: String) {
        hud.hide()
        TextInserter.insert(text, pressEnter: pressEnter) { [weak self] in
            guard let self else { return }
            HistoryStore.shared.add(text: text, appName: frontApp)
            self.playSound("Tink")
            self.becomeIdle()
        }
    }

    // MARK: - Command Mode pipeline

    private func handleCommand(_ instruction: String) {
        guard !settings.openAIKey.isEmpty else {
            hud.showNotice("Command Mode needs an OpenAI API key (Settings → AI).", duration: 3.5)
            becomeIdle()
            return
        }
        TextInserter.fetchSelectedText { [weak self] selection in
            guard let self else { return }
            Task { @MainActor in
                do {
                    let result: String
                    if let selection, !selection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        result = try await LLMService.transform(selection: selection, instruction: instruction)
                        if result == selection {
                            self.hud.showNotice("Your text looks good!")
                            self.becomeIdle()
                            return
                        }
                    } else {
                        result = try await LLMService.generate(instruction: instruction)
                    }
                    self.hud.hide()
                    TextInserter.insert(result, pressEnter: false) {
                        self.becomeIdle()
                    }
                    HistoryStore.shared.add(text: result, appName: "Command Mode")
                    self.playSound("Tink")
                } catch {
                    self.hud.showNotice(error.localizedDescription, duration: 3.5)
                    self.becomeIdle()
                }
            }
        }
    }

    private func playSound(_ name: String) {
        guard settings.playSounds else { return }
        NSSound(named: name)?.play()
    }
}
