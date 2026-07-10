import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Prompt Mode engine: turns rambling natural speech into a clear,
/// well-structured prompt for an AI assistant.
///
/// Engine priority:
/// 1. Apple's on-device foundation model (macOS 26+ with Apple
///    Intelligence) — free, private, works offline.
/// 2. The user's OpenAI key, if one is configured in Settings → AI.
/// 3. A local rule-based formatter — always available, no model needed.
enum PromptComposer {

    static let instructions = """
    You turn rambling spoken thoughts into a clear, well-structured prompt for an AI \
    assistant. Rewrite the user's speech as a direct, specific request: state the goal \
    first, then any context, requirements, and constraints they mentioned. Apply their \
    self-corrections (e.g. "no wait, use Python" means use Python). Use bullet points \
    when they list several things. Keep their language and intent. Do NOT answer the \
    request, do NOT invent requirements they didn't say, do NOT wrap the output in \
    quotes. Output only the rewritten prompt.
    """

    static func compose(_ raw: String) async -> String {
        // 1. Apple on-device model — free and private.
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability {
                do {
                    let session = LanguageModelSession(instructions: instructions)
                    let response = try await session.respond(to: raw)
                    let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty { return text }
                } catch {
                    // Fall through to the next engine.
                }
            }
        }
        #endif

        // 2. User's OpenAI key, if configured.
        let key = AppSettings.shared.openAIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            if let text = try? await LLMService.complete(system: instructions, user: raw),
               !text.isEmpty {
                return text
            }
        }

        // 3. Rule-based fallback.
        return ruleBased(raw)
    }

    // MARK: - Rule-based fallback

    /// No model available: clean the transcript locally and shape it
    /// into a simple goal + details structure.
    static func ruleBased(_ raw: String) -> String {
        let polished = TextPolisher.polish(raw, settings: AppSettings.shared).text
        let sentences = splitSentences(polished)
        guard sentences.count > 2 else { return polished }

        let goal = sentences[0]
        let details = sentences.dropFirst().map { "- \($0)" }.joined(separator: "\n")
        return goal + "\n\nDetails:\n" + details
    }

    private static func splitSentences(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        for char in text {
            current.append(char)
            if char == "." || char == "?" || char == "!" {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { result.append(trimmed) }
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { result.append(tail) }
        return result
    }
}
