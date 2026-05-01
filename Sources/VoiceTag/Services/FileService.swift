import Foundation

// MARK: - FileService

final class FileService {

    /// Move a file to a destination folder, creating the folder if needed.
    /// Returns a HistoryEntry for undo.
    func move(_ sourceURL: URL, toFolder folderURL: URL, createIfNeeded: Bool) async throws -> HistoryEntry {
        return try await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default

            // Create destination folder
            if createIfNeeded {
                try fm.createDirectory(at: folderURL, withIntermediateDirectories: true)
            }

            var destinationURL = folderURL.appendingPathComponent(sourceURL.lastPathComponent)

            // Conflict resolution: append counter if file exists
            if fm.fileExists(atPath: destinationURL.path) {
                let name = sourceURL.deletingPathExtension().lastPathComponent
                let ext = sourceURL.pathExtension
                var counter = 1
                repeat {
                    let newName = counter == 1
                        ? "\(name)_copy.\(ext)"
                        : "\(name)_copy\(counter).\(ext)"
                    destinationURL = folderURL.appendingPathComponent(newName)
                    counter += 1
                } while fm.fileExists(atPath: destinationURL.path) && counter < 100
            }

            try fm.moveItem(at: sourceURL, to: destinationURL)

            Logger.shared.log("Moved \(sourceURL.lastPathComponent) → \(destinationURL.path)")

            return HistoryEntry(
                originalURL: sourceURL,
                destinationURL: destinationURL,
                timestamp: Date()
            )
        }.value
    }

    /// Undo a previous move.
    func undoMove(_ entry: HistoryEntry) async throws {
        try await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default

            guard fm.fileExists(atPath: entry.destinationURL.path) else {
                throw FileServiceError.fileNotFound(entry.destinationURL)
            }

            // Restore to original location
            let originalDir = entry.originalURL.deletingLastPathComponent()
            try fm.createDirectory(at: originalDir, withIntermediateDirectories: true)

            if fm.fileExists(atPath: entry.originalURL.path) {
                // Conflict: rename the undone file slightly
                let name = entry.originalURL.deletingPathExtension().lastPathComponent
                let ext = entry.originalURL.pathExtension
                let restoredURL = originalDir.appendingPathComponent("\(name)_restored.\(ext)")
                try fm.moveItem(at: entry.destinationURL, to: restoredURL)
            } else {
                try fm.moveItem(at: entry.destinationURL, to: entry.originalURL)
            }
        }.value
    }
}

// MARK: - Errors

enum FileServiceError: LocalizedError {
    case fileNotFound(URL)
    case moveFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url): return "File not found: \(url.path)"
        case .moveFailed(let msg): return "Move failed: \(msg)"
        }
    }
}
