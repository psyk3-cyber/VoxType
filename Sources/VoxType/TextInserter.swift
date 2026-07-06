import AppKit
import CoreGraphics

/// Inserts text into whatever app currently has keyboard focus by
/// pasting via the clipboard (the same approach Wispr Flow uses),
/// then restores the previous clipboard contents.
enum TextInserter {

    static func insert(_ text: String, pressEnter: Bool, completion: (() -> Void)? = nil) {
        let pasteboard = NSPasteboard.general
        let savedString = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Give the pasteboard a beat to sync, then paste.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            postKeystroke(keyCode: 9, flags: .maskCommand) // Cmd+V

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if pressEnter {
                    postKeystroke(keyCode: 36) // Return
                }
                // Restore the user's old clipboard.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    if let savedString {
                        pasteboard.clearContents()
                        pasteboard.setString(savedString, forType: .string)
                    }
                    completion?()
                }
            }
        }
    }

    /// Reads the currently selected text in the frontmost app by
    /// simulating Cmd+C. Returns nil if nothing was copied.
    static func fetchSelectedText(completion: @escaping (String?) -> Void) {
        let pasteboard = NSPasteboard.general
        let savedString = pasteboard.string(forType: .string)
        let changeCountBefore = pasteboard.changeCount

        postKeystroke(keyCode: 8, flags: .maskCommand) // Cmd+C

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            var selected: String?
            if pasteboard.changeCount != changeCountBefore {
                selected = pasteboard.string(forType: .string)
            }
            // Restore the previous clipboard.
            if let savedString {
                pasteboard.clearContents()
                pasteboard.setString(savedString, forType: .string)
            }
            completion(selected)
        }
    }

    static func postKeystroke(keyCode: CGKeyCode, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
