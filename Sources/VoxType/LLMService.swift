import Foundation

enum LLMError: LocalizedError {
    case missingKey
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "Add an OpenAI API key in Settings → AI to use this feature."
        case .badResponse(let message):
            return "AI request failed: \(message)"
        }
    }
}

/// Minimal OpenAI Chat Completions client used for AI Auto-Edits
/// (polish) and Command Mode transformations.
enum LLMService {

    static func complete(system: String, user: String) async throws -> String {
        let settings = AppSettings.shared
        let key = settings.openAIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw LLMError.missingKey }

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": settings.openAIModel,
            "temperature": 0.3,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LLMError.badResponse("No HTTP response")
        }
        guard http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.badResponse("HTTP \(http.statusCode) \(text.prefix(200))")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.badResponse("Unexpected response shape")
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: High-level operations

    /// AI Auto-Edits: turn raw dictation into clean, well-formatted text.
    static func polishDictation(_ raw: String) async throws -> String {
        let system = """
        You clean up raw voice dictation. Rewrite the user's dictated text into clear, \
        polished writing while preserving their meaning, tone, and voice. Remove filler \
        words, false starts, and repeated words. Apply the speaker's self-corrections \
        (e.g. "no wait, make that Tuesday" means use Tuesday). Format lists as lists when \
        the speaker enumerates items. Fix punctuation and capitalization. Do NOT add new \
        information, do NOT answer questions in the text, do NOT wrap the output in quotes. \
        Output only the cleaned text.
        """
        return try await complete(system: system, user: raw)
    }

    /// Command Mode with a text selection: transform the selection per the instruction.
    static func transform(selection: String, instruction: String) async throws -> String {
        let system = """
        You are a text editing engine. The user gives you a piece of text and a spoken \
        instruction. Apply the instruction to the text and output ONLY the resulting text, \
        with no preamble, explanation, or quotes.
        """
        let user = "Instruction: \(instruction)\n\nText:\n\(selection)"
        return try await complete(system: system, user: user)
    }

    /// Command Mode without a selection: generate content or answer inline.
    static func generate(instruction: String) async throws -> String {
        let system = """
        You are an inline writing assistant. The user speaks a request; produce the text \
        that should be inserted at their cursor. Output ONLY that text, with no preamble, \
        explanation, or quotes. Keep answers concise.
        """
        return try await complete(system: system, user: instruction)
    }
}
