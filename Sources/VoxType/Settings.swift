import Foundation
import CoreGraphics
import Combine

// MARK: - Models

struct Snippet: Codable, Identifiable, Equatable {
    var id = UUID()
    var cue: String
    var text: String
}

struct HistoryItem: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var text: String
    var appName: String
}

enum TriggerKey: String, Codable, CaseIterable, Identifiable {
    case fn
    case rightCommand
    case rightOption

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fn: return "fn (Globe)"
        case .rightCommand: return "Right ⌘ Command"
        case .rightOption: return "Right ⌥ Option"
        }
    }

    var keyCode: Int64 {
        switch self {
        case .fn: return 63
        case .rightCommand: return 54
        case .rightOption: return 61
        }
    }

    /// Device-specific flag bits so releasing the RIGHT modifier is
    /// detected even while the left one is held (NX_DEVICER*KEYMASK).
    var flagMask: CGEventFlags {
        switch self {
        case .fn: return .maskSecondaryFn
        case .rightCommand: return CGEventFlags(rawValue: 0x0010)
        case .rightOption: return CGEventFlags(rawValue: 0x0040)
        }
    }
}

// MARK: - Settings

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var triggerKey: TriggerKey = .fn { didSet { save() } }
    @Published var languageID: String = "auto" { didSet { save() } }
    @Published var preferOnDevice: Bool = false { didSet { save() } }
    @Published var playSounds: Bool = true { didSet { save() } }
    @Published var launchAtLogin: Bool = false { didSet { save() } }

    // Polish
    @Published var removeFillers: Bool = true { didSet { save() } }
    @Published var autoCapitalize: Bool = true { didSet { save() } }
    @Published var pressEnterCommandEnabled: Bool = true { didSet { save() } }

    // AI
    @Published var aiPolishEnabled: Bool = false { didSet { save() } }
    @Published var openAIKey: String = "" { didSet { save() } }
    @Published var openAIModel: String = "gpt-4o-mini" { didSet { save() } }

    // Personalization
    @Published var dictionaryWords: [String] = [] { didSet { save() } }
    @Published var snippets: [Snippet] = [] { didSet { save() } }

    var locale: Locale {
        languageID == "auto" ? Locale.current : Locale(identifier: languageID)
    }

    var contextualStrings: [String] {
        dictionaryWords + snippets.map { $0.cue }
    }

    struct LanguageOption: Identifiable {
        let id: String
        let name: String
    }

    static let languageOptions: [LanguageOption] = [
        .init(id: "auto", name: "Automatic (System)"),
        .init(id: "en-US", name: "English (US)"),
        .init(id: "en-GB", name: "English (UK)"),
        .init(id: "es-ES", name: "Español"),
        .init(id: "fr-FR", name: "Français"),
        .init(id: "de-DE", name: "Deutsch"),
        .init(id: "it-IT", name: "Italiano"),
        .init(id: "pt-BR", name: "Português (BR)"),
        .init(id: "nl-NL", name: "Nederlands"),
        .init(id: "hi-IN", name: "हिन्दी"),
        .init(id: "zh-CN", name: "中文 (简体)"),
        .init(id: "ja-JP", name: "日本語"),
        .init(id: "ko-KR", name: "한국어"),
        .init(id: "ar-SA", name: "العربية")
    ]

    // MARK: Persistence

    private struct Snapshot: Codable {
        var triggerKey: TriggerKey
        var languageID: String
        var preferOnDevice: Bool
        var playSounds: Bool
        var launchAtLogin: Bool
        var removeFillers: Bool
        var autoCapitalize: Bool
        var pressEnterCommandEnabled: Bool
        var aiPolishEnabled: Bool
        var openAIKey: String
        var openAIModel: String
        var dictionaryWords: [String]
        var snippets: [Snippet]
    }

    private var loading = false

    static var storageDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("VoxType", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var fileURL: URL {
        Self.storageDirectory.appendingPathComponent("settings.json")
    }

    private init() {
        load()
    }

    private func load() {
        loading = true
        defer { loading = false }
        guard let data = try? Data(contentsOf: fileURL),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        triggerKey = snap.triggerKey
        languageID = snap.languageID
        preferOnDevice = snap.preferOnDevice
        playSounds = snap.playSounds
        launchAtLogin = snap.launchAtLogin
        removeFillers = snap.removeFillers
        autoCapitalize = snap.autoCapitalize
        pressEnterCommandEnabled = snap.pressEnterCommandEnabled
        aiPolishEnabled = snap.aiPolishEnabled
        openAIKey = snap.openAIKey
        openAIModel = snap.openAIModel
        dictionaryWords = snap.dictionaryWords
        snippets = snap.snippets
    }

    func save() {
        guard !loading else { return }
        let snap = Snapshot(
            triggerKey: triggerKey,
            languageID: languageID,
            preferOnDevice: preferOnDevice,
            playSounds: playSounds,
            launchAtLogin: launchAtLogin,
            removeFillers: removeFillers,
            autoCapitalize: autoCapitalize,
            pressEnterCommandEnabled: pressEnterCommandEnabled,
            aiPolishEnabled: aiPolishEnabled,
            openAIKey: openAIKey,
            openAIModel: openAIModel,
            dictionaryWords: dictionaryWords,
            snippets: snippets
        )
        if let data = try? JSONEncoder().encode(snap) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}

// MARK: - History

final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var items: [HistoryItem] = []

    private var fileURL: URL {
        AppSettings.storageDirectory.appendingPathComponent("history.json")
    }

    private init() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            items = decoded
        }
    }

    func add(text: String, appName: String) {
        DispatchQueue.main.async {
            self.items.insert(HistoryItem(date: Date(), text: text, appName: appName), at: 0)
            if self.items.count > 200 {
                self.items.removeLast(self.items.count - 200)
            }
            self.persist()
        }
    }

    func clear() {
        items = []
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
