import Foundation

struct PolishResult {
    var text: String
    var pressEnter: Bool
}

/// Local, instant cleanup of raw dictation: filler removal, dictionary
/// spelling enforcement, snippet expansion, capitalization, and the
/// "press enter" voice command.
enum TextPolisher {

    static let fillerPattern = "\\b(um+|uh+|uhm+|erm+|er|ah+|hm+|mhm|hmm)\\b[,.]?"

    static func polish(_ raw: String, settings: AppSettings) -> PolishResult {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var pressEnter = false

        // 1. "press enter" voice command (only at the very end).
        if settings.pressEnterCommandEnabled {
            let pattern = "[,;:\\s]*press enter[.!?\\s]*$"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..., in: text)
                if regex.firstMatch(in: text, options: [], range: range) != nil {
                    text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
                    pressEnter = true
                    // Restore terminal punctuation if the sentence lost it.
                    let trimmed = text.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty, let last = trimmed.last, !".!?".contains(last) {
                        text = trimmed + "."
                    } else {
                        text = trimmed
                    }
                }
            }
        }

        // 2. Snippet expansion: saying a cue inserts the full snippet text.
        for snippet in settings.snippets where !snippet.cue.trimmingCharacters(in: .whitespaces).isEmpty {
            text = replaceOccurrences(of: snippet.cue, with: snippet.text, in: text)
        }

        // 3. Filler word removal.
        if settings.removeFillers {
            if let regex = try? NSRegularExpression(pattern: fillerPattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..., in: text)
                text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
            }
        }

        // 4. Personal dictionary: enforce exact spellings/casing.
        for word in settings.dictionaryWords where !word.trimmingCharacters(in: .whitespaces).isEmpty {
            text = replaceOccurrences(of: word, with: word, in: text)
        }

        // 5. Whitespace and punctuation tidy-up.
        text = text.replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\s+([,.!?;:])", with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: "([,.!?;:]){2,}", with: "$1", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 6. Capitalization.
        if settings.autoCapitalize {
            text = capitalizeSentences(text)
        }

        return PolishResult(text: text, pressEnter: pressEnter)
    }

    /// Case-insensitive whole-phrase replacement.
    private static func replaceOccurrences(of phrase: String, with replacement: String, in text: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: phrase)
        let pattern = "\\b\(escaped)\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        let template = NSRegularExpression.escapedTemplate(for: replacement)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: template)
    }

    private static func capitalizeSentences(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        var result = ""
        var capitalizeNext = true
        for char in text {
            if capitalizeNext, char.isLetter {
                result.append(Character(String(char).uppercased()))
                capitalizeNext = false
            } else {
                result.append(char)
                if ".!?".contains(char) {
                    capitalizeNext = true
                } else if char == "\n" {
                    capitalizeNext = true
                }
            }
        }
        return result
    }
}
