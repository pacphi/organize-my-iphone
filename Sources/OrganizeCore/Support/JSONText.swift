import Foundation

/// Finds JSON inside text that may carry extra noise around it.
///
/// Command-line tools sometimes print warnings before their JSON, and language models like to
/// wrap JSON in prose or code fences. This pulls out the first parseable document.
public enum JSONText {
    public static func extract(from text: String) -> JSONValue? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }
        if let value = try? JSONValue.parse(trimmed) {
            return value
        }

        let objectCandidate = slice(trimmed, from: "{", to: "}")
        let arrayCandidate = slice(trimmed, from: "[", to: "]")

        // Prefer whichever bracket opens first, then fall back to the other.
        var candidates: [(start: String.Index, text: String)] = []
        if let objectCandidate { candidates.append(objectCandidate) }
        if let arrayCandidate { candidates.append(arrayCandidate) }
        candidates.sort { $0.start < $1.start }

        for candidate in candidates {
            if let value = try? JSONValue.parse(candidate.text) {
                return value
            }
        }
        return nil
    }

    private static func slice(
        _ text: String,
        from open: Character,
        to close: Character
    ) -> (start: String.Index, text: String)? {
        guard let start = text.firstIndex(of: open), let end = text.lastIndex(of: close), start < end else {
            return nil
        }
        return (start, String(text[start...end]))
    }
}
