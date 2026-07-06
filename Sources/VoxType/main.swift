import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var dictation: DictationController!
    private var hotkeys: HotkeyManager!
    private var statusBar: StatusBarController!
    private var accessibilityRetryTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = AppSettings.shared
        _ = HistoryStore.shared

        dictation = DictationController()
        statusBar = StatusBarController(dictation: dictation)
        hotkeys = HotkeyManager(dictation: dictation)

        if PermissionHelper.accessibilityGranted {
            hotkeys.start()
        } else {
            // Keep trying — the event tap can only be created once the
            // user grants Accessibility in System Settings.
            accessibilityRetryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
                guard let self else { return }
                if PermissionHelper.accessibilityGranted {
                    self.hotkeys.start()
                    if self.hotkeys.isRunning {
                        timer.invalidate()
                        self.accessibilityRetryTimer = nil
                    }
                }
            }
        }

        OnboardingWindowController.shared.showIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeys?.stop()
        AppSettings.shared.save()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
app.run()
