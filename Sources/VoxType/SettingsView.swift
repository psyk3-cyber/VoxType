import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var history = HistoryStore.shared

    var body: some View {
        TabView {
            GeneralTab(settings: settings)
                .tabItem { Label("General", systemImage: "gearshape") }
            PolishTab(settings: settings)
                .tabItem { Label("Polish", systemImage: "wand.and.stars") }
            DictionaryTab(settings: settings)
                .tabItem { Label("Dictionary", systemImage: "character.book.closed") }
            SnippetsTab(settings: settings)
                .tabItem { Label("Snippets", systemImage: "text.badge.plus") }
            AITab(settings: settings)
                .tabItem { Label("AI", systemImage: "sparkles") }
            HistoryTab(history: history)
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
        }
        .frame(width: 560, height: 440)
    }
}

// MARK: - General

struct GeneralTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Picker("Dictation key:", selection: $settings.triggerKey) {
                ForEach(TriggerKey.allCases) { key in
                    Text(key.displayName).tag(key)
                }
            }
            Text("Hold to dictate. Double-tap for hands-free. Hold with ⌃ Control for Command Mode. Hold with ⌥ Option for Prompt Mode — speak naturally and a structured AI prompt is inserted. Esc cancels.")
                .font(.caption)
                .foregroundColor(.secondary)

            if settings.triggerKey == .fn {
                Text("Tip: set System Settings → Keyboard → “Press 🌐 key to” → Do Nothing, so fn doesn’t also trigger macOS features.")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            Divider()

            Picker("Language:", selection: $settings.languageID) {
                ForEach(AppSettings.languageOptions) { option in
                    Text(option.name).tag(option.id)
                }
            }
            Toggle("Prefer on-device transcription (more private, needs downloaded dictation model)", isOn: $settings.preferOnDevice)
            Toggle("Play sounds", isOn: $settings.playSounds)
            Toggle("Launch at login", isOn: $settings.launchAtLogin)
                .onChange(of: settings.launchAtLogin) { enabled in
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        NSLog("Launch at login change failed: \(error)")
                    }
                }
        }
        .padding(20)
    }
}

// MARK: - Polish

struct PolishTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Toggle("Remove filler words (um, uh, hmm…)", isOn: $settings.removeFillers)
            Toggle("Auto-capitalize sentences", isOn: $settings.autoCapitalize)
            Toggle("“Press enter” voice command", isOn: $settings.pressEnterCommandEnabled)
            Text("Say “press enter” at the end of a dictation and VoxType presses Return after inserting your text — handy in chat apps.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
    }
}

// MARK: - Dictionary

struct DictionaryTab: View {
    @ObservedObject var settings: AppSettings
    @State private var newWord = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Names, jargon, and unique spellings. These bias transcription and enforce exact casing in your text.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                TextField("Add a word or name (e.g. Wispr, Caltrain, Nguyen)", text: $newWord)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addWord)
                Button("Add", action: addWord)
                    .disabled(newWord.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            List {
                ForEach(settings.dictionaryWords, id: \.self) { word in
                    HStack {
                        Text(word)
                        Spacer()
                        Button(role: .destructive) {
                            settings.dictionaryWords.removeAll { $0 == word }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .frame(minHeight: 220)
        }
        .padding(20)
    }

    private func addWord() {
        let word = newWord.trimmingCharacters(in: .whitespaces)
        guard !word.isEmpty, !settings.dictionaryWords.contains(word) else { return }
        settings.dictionaryWords.append(word)
        newWord = ""
    }
}

// MARK: - Snippets

struct SnippetsTab: View {
    @ObservedObject var settings: AppSettings
    @State private var newCue = ""
    @State private var newText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Say a cue phrase while dictating and it expands into the full snippet text — e.g. cue “calendar link” → your booking URL.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(alignment: .top) {
                VStack {
                    TextField("Cue phrase", text: $newCue)
                        .textFieldStyle(.roundedBorder)
                    TextField("Expanded text", text: $newText)
                        .textFieldStyle(.roundedBorder)
                }
                Button("Add") {
                    let cue = newCue.trimmingCharacters(in: .whitespaces)
                    let text = newText.trimmingCharacters(in: .whitespaces)
                    guard !cue.isEmpty, !text.isEmpty else { return }
                    settings.snippets.append(Snippet(cue: cue, text: text))
                    newCue = ""
                    newText = ""
                }
                .disabled(newCue.trimmingCharacters(in: .whitespaces).isEmpty ||
                          newText.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            List {
                ForEach(settings.snippets) { snippet in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(snippet.cue).fontWeight(.medium)
                            Text(snippet.text)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            settings.snippets.removeAll { $0.id == snippet.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .frame(minHeight: 200)
        }
        .padding(20)
    }
}

// MARK: - AI

struct AITab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                SecureField("OpenAI API key (sk-…)", text: $settings.openAIKey)
                TextField("Model", text: $settings.openAIModel)
                Toggle("AI Auto-Edits", isOn: $settings.aiPolishEnabled)
                Text("With AI Auto-Edits on, every dictation is rewritten by the model: filler words, false starts, and self-corrections are cleaned up automatically. Command Mode (hold dictation key + ⌃ Control) also uses this key — highlight text and say “make this more concise”, or ask a question with nothing selected.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Section {
                Text("Without a key, VoxType still transcribes on-device with Apple’s speech engine and applies local polish (fillers, dictionary, snippets, capitalization).")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
    }
}

// MARK: - History

struct HistoryTab: View {
    @ObservedObject var history: HistoryStore

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent dictations")
                    .font(.headline)
                Spacer()
                Button("Clear All") { history.clear() }
                    .disabled(history.items.isEmpty)
            }
            List {
                ForEach(history.items) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(Self.formatter.string(from: item.date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("· \(item.appName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(item.text, forType: .string)
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                            .help("Copy")
                        }
                        Text(item.text)
                            .lineLimit(3)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(20)
    }
}

// MARK: - Window controller

final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            w.title = "VoxType Settings"
            w.contentView = NSHostingView(rootView: SettingsView())
            w.center()
            w.isReleasedWhenClosed = false
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
