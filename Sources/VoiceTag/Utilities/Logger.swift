import Foundation

// MARK: - Logger

final class Logger {
    static let shared = Logger()
    private var logURL: URL?
    private let queue = DispatchQueue(label: "voicetag.logger", qos: .utility)

    enum Level: String {
        case info = "INFO"
        case debug = "DEBUG"
        case error = "ERROR"
    }

    func configure(logFileURL: URL) {
        self.logURL = logFileURL
        let dir = logFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Write header
        log("=== VoiceTag Session Started ===", level: .info)
    }

    func log(_ message: String, level: Level = .info) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] [\(level.rawValue)] \(message)\n"
        print(line, terminator: "")
        queue.async { [weak self] in
            guard let url = self?.logURL else { return }
            if let data = line.data(using: .utf8) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                } else {
                    try? data.write(to: url)
                }
            }
        }
    }
}
