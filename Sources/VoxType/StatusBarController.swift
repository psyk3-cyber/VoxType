import AppKit

/// The menu bar item — VoxType's home base.
final class StatusBarController: NSObject, NSMenuDelegate {

    private let statusItem: NSStatusItem
    private let dictation: DictationController

    init(dictation: DictationController) {
        self.dictation = dictation
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        updateIcon()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        dictation.onStateChange = { [weak self] in
            DispatchQueue.main.async { self?.updateIcon() }
        }
    }

    func updateIcon() {
        guard let button = statusItem.button else { return }
        let symbolName: String
        switch dictation.state {
        case .idle: symbolName = "waveform"
        case .recording: symbolName = "waveform.badge.mic"
        case .processing: symbolName = "waveform.badge.magnifyingglass"
        }
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "VoxType")
        image?.isTemplate = true
        button.image = image
        if case .recording = dictation.state {
            button.contentTintColor = .systemRed
        } else {
            button.contentTintColor = nil
        }
    }

    // Build the menu fresh each time it opens so state labels are current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let statusText: String
        switch dictation.state {
        case .idle: statusText = "VoxType — Ready"
        case .recording: statusText = dictation.isHandsFree ? "Listening (hands-free)…" : "Listening…"
        case .processing: statusText = "Processing…"
        }
        let statusLine = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)

        let hint = NSMenuItem(
            title: "Hold \(AppSettings.shared.triggerKey.displayName) to dictate",
            action: nil, keyEquivalent: ""
        )
        hint.isEnabled = false
        menu.addItem(hint)

        menu.addItem(.separator())

        let handsFreeTitle = (dictation.isRecording && dictation.isHandsFree)
            ? "Stop Hands-Free Dictation"
            : "Start Hands-Free Dictation"
        let handsFree = NSMenuItem(title: handsFreeTitle, action: #selector(toggleHandsFree), keyEquivalent: "")
        handsFree.target = self
        menu.addItem(handsFree)

        if dictation.isRecording {
            let cancel = NSMenuItem(title: "Cancel Dictation", action: #selector(cancelDictation), keyEquivalent: "")
            cancel.target = self
            menu.addItem(cancel)
        }

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let permissions = NSMenuItem(title: "Permissions & Setup…", action: #selector(openOnboarding), keyEquivalent: "")
        permissions.target = self
        menu.addItem(permissions)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit VoxType", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    @objc private func toggleHandsFree() {
        dictation.toggleHandsFree()
    }

    @objc private func cancelDictation() {
        dictation.cancelRecording()
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func openOnboarding() {
        OnboardingWindowController.shared.show()
    }
}
