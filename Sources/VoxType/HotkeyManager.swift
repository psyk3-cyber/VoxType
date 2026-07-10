import AppKit
import CoreGraphics

/// Global hotkey handling via a CGEvent tap:
/// - Hold trigger key (default: fn)          → push-to-talk dictation
/// - Double-tap trigger key                  → hands-free dictation (tap again to finish)
/// - Hold trigger + Ctrl                     → Command Mode
/// - Hold trigger + Option                   → Prompt Mode
/// - Esc                                     → cancel
final class HotkeyManager {

    private weak var dictation: DictationController?
    private let settings = AppSettings.shared

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Trigger state
    private var triggerIsDown = false
    private var triggerDownAt = Date.distantPast
    private var lastQuickTapAt = Date.distantPast
    private var startedHandsFreeOnThisPress = false

    private let doubleTapWindow: TimeInterval = 0.4
    private let quickTapMax: TimeInterval = 0.3

    init(dictation: DictationController) {
        self.dictation = dictation
    }

    // MARK: - Event tap

    func start() {
        guard eventTap == nil else { return }

        let mask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
            manager.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: refcon
        ) else {
            NSLog("VoxType: failed to create event tap — check Accessibility permission.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    var isRunning: Bool { eventTap != nil }

    // MARK: - Event handling

    private func handle(type: CGEventType, event: CGEvent) {
        // macOS disables taps that stall; re-enable.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        if type == .keyDown {
            // Esc cancels an in-flight recording.
            if keyCode == 53, dictation?.isRecording == true {
                DispatchQueue.main.async { [weak self] in
                    self?.dictation?.cancelRecording()
                }
            }
            return
        }

        guard type == .flagsChanged else { return }

        let trigger = settings.triggerKey
        let flags = event.flags

        // Ctrl added while dictating → upgrade to Command Mode.
        if (keyCode == 59 || keyCode == 62), flags.contains(.maskControl),
           dictation?.isRecording == true {
            DispatchQueue.main.async { [weak self] in
                self?.dictation?.upgradeToCommandMode()
            }
            return
        }

        // Option added while dictating → upgrade to Prompt Mode.
        // (Right Option is skipped when it's the trigger key itself.)
        if (keyCode == 58 || (keyCode == 61 && trigger != .rightOption)),
           flags.contains(.maskAlternate),
           dictation?.isRecording == true {
            DispatchQueue.main.async { [weak self] in
                self?.dictation?.upgradeToPromptMode()
            }
            return
        }

        guard keyCode == trigger.keyCode else { return }
        let isDown = flags.contains(trigger.flagMask)

        // Detect a held Option without being fooled by the trigger key
        // itself when the trigger IS Right Option (device bit 0x0020 =
        // left Option only).
        let optionHeld: Bool = (trigger == .rightOption)
            ? flags.contains(CGEventFlags(rawValue: 0x0020))
            : flags.contains(.maskAlternate)

        if isDown && !triggerIsDown {
            triggerIsDown = true
            triggerDownAt = Date()
            startedHandsFreeOnThisPress = false
            DispatchQueue.main.async { [weak self] in
                self?.triggerPressed(withControl: flags.contains(.maskControl),
                                     withOption: optionHeld)
            }
        } else if !isDown && triggerIsDown {
            triggerIsDown = false
            let heldFor = Date().timeIntervalSince(triggerDownAt)
            DispatchQueue.main.async { [weak self] in
                self?.triggerReleased(heldFor: heldFor)
            }
        }
    }

    // MARK: - Gesture logic (main thread)

    private func triggerPressed(withControl: Bool, withOption: Bool) {
        guard let dictation else { return }

        // A press while hands-free is active ends the session.
        if dictation.isRecording && dictation.isHandsFree {
            dictation.finishRecording()
            startedHandsFreeOnThisPress = true // swallow the matching release
            return
        }

        // Second tap of a double-tap → hands-free.
        if Date().timeIntervalSince(lastQuickTapAt) < doubleTapWindow {
            lastQuickTapAt = .distantPast
            dictation.startRecording(mode: .dictation, handsFree: true)
            startedHandsFreeOnThisPress = true
            return
        }

        // Normal push-to-talk, or straight into Command Mode (Ctrl) /
        // Prompt Mode (Option).
        let mode: DictationController.Mode =
            withControl ? .command : (withOption ? .prompt : .dictation)
        dictation.startRecording(mode: mode, handsFree: false)
    }

    private func triggerReleased(heldFor: TimeInterval) {
        guard let dictation else { return }

        // Releases tied to hands-free start/stop are ignored.
        if startedHandsFreeOnThisPress {
            startedHandsFreeOnThisPress = false
            return
        }

        guard dictation.isRecording, !dictation.isHandsFree else { return }

        if heldFor < quickTapMax {
            // Too quick to be dictation — treat as first tap of a
            // potential double-tap and discard the audio. A quick
            // Command/Prompt Mode tap should NOT arm the double-tap gesture.
            let wasModified = dictation.isModifierRecording
            dictation.abortQuietly()
            if !wasModified {
                lastQuickTapAt = Date()
            }
        } else {
            dictation.finishRecording()
        }
    }
}
