import Foundation

// MARK: - TagAction

enum TagAction {
    case tag(URL)
    case delete(URL)
    case skip
    case undo

    var description: String {
        switch self {
        case .tag(let url): return "tag → \(url.path)"
        case .delete(let url): return "delete → \(url.path)"
        case .skip: return "skip"
        case .undo: return "undo"
        }
    }
}

// MARK: - HistoryEntry

struct HistoryEntry {
    let originalURL: URL
    let destinationURL: URL
    let timestamp: Date
}

// MARK: - TagParser

final class TagParser {

    /// Convert raw transcription text to a structured TagAction.
    func parse(text: String, currentFolder: URL?, config: AppConfig) -> TagAction {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // --- Special commands ---
        if matchesAny(lower, patterns: config.skipCommands) {
            return .skip
        }
        if matchesAny(lower, patterns: config.undoCommands) {
            return .undo
        }
        if matchesAny(lower, patterns: config.deleteCommands) {
            let trashURL = config.baseDirectoryURL.appendingPathComponent(config.trashFolderName)
            return .delete(trashURL)
        }

        // --- Custom tag mappings ---
        for (pattern, destination) in config.tagMappings {
            if lower.contains(pattern.lowercased()) {
                let destURL = config.baseDirectoryURL.appendingPathComponent(destination)
                return .tag(destURL)
            }
        }

        // --- General tag parsing ---
        let folderPath = buildFolderPath(from: lower, currentFolder: currentFolder, config: config)
        return .tag(folderPath)
    }

    // MARK: - Private Helpers

    private func matchesAny(_ input: String, patterns: [String]) -> Bool {
        patterns.contains { input == $0 || input.hasPrefix($0 + " ") || input.hasSuffix(" " + $0) }
    }

    /// Build a nested folder URL from a spoken phrase.
    /// "mountains pass day 2" → baseDir/Mountains/Day_2
    /// "mountains pass" → baseDir/Mountains
    private func buildFolderPath(from text: String, currentFolder: URL?, config: AppConfig) -> URL {
        // Split on common natural-language separators
        var parts = tokenize(text)

        // If only one word and matches current folder name loosely, use current + subfolder
        if parts.count == 1, let current = currentFolder {
            let currentName = normalize(current.lastPathComponent)
            let normalized = normalize(parts[0])
            if currentName.contains(normalized) || normalized.contains(currentName) {
                return current
            }
        }

        // Detect day-number patterns: "day 1", "day two", "day 3"
        parts = mergeAdjacentDayTokens(parts)

        // Build the path
        var url = config.baseDirectoryURL
        for part in parts {
            url = url.appendingPathComponent(normalize(part))
        }
        return url
    }

    /// Merge "day" + number/word into a single component.
    private func mergeAdjacentDayTokens(_ tokens: [String]) -> [String] {
        var result: [String] = []
        var i = 0
        while i < tokens.count {
            let token = tokens[i]
            if token == "day" && i + 1 < tokens.count {
                let next = tokens[i + 1]
                // Accept numeric or written numbers
                result.append("day_\(next)")
                i += 2
            } else {
                result.append(token)
                i += 1
            }
        }
        return result
    }

    private func tokenize(_ text: String) -> [String] {
        // Remove filler words and split
        let fillers: Set<String> = ["a", "the", "an", "and", "or", "to", "of", "in", "on", "at", "for"]
        return text
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty && !fillers.contains($0) }
    }

    private func normalize(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}
