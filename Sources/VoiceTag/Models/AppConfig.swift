import Foundation

// MARK: - AppConfig

struct AppConfig: Codable {
    var baseDirectory: String
    var whisperMode: WhisperMode
    var whisperAPIKey: String?
    var whisperModel: String
    var skipCommands: [String]
    var deleteCommands: [String]
    var undoCommands: [String]
    var trashFolderName: String
    var tagMappings: [String: String]   // phrase → relative folder path
    var debugMode: Bool
    var logFile: String

    enum WhisperMode: String, Codable {
        case local   // whisper.cpp via subprocess
        case api     // OpenAI Whisper API
    }

    // Computed helpers
    var baseDirectoryURL: URL {
        URL(fileURLWithPath: (baseDirectory as NSString).expandingTildeInPath)
    }

    var logFileURL: URL {
        URL(fileURLWithPath: (logFile as NSString).expandingTildeInPath)
    }

    // MARK: - Defaults
    static var `default`: AppConfig {
        AppConfig(
            baseDirectory: "~/Pictures/VoiceTagged",
            whisperMode: .local,
            whisperAPIKey: nil,
            whisperModel: "base.en",
            skipCommands: ["skip", "next", "pass"],
            deleteCommands: ["delete", "trash", "remove", "discard"],
            undoCommands: ["undo", "go back", "revert"],
            trashFolderName: "Trash_Sorted",
            tagMappings: [:],
            debugMode: false,
            logFile: "~/.voicetag/voicetag.log"
        )
    }

    // MARK: - Load from disk
    static func load() -> AppConfig {
        let configPaths = [
            "~/.voicetag/config.json",
            "~/.config/voicetag/config.json",
            "./voicetag.config.json"
        ].map { ($0 as NSString).expandingTildeInPath }

        for path in configPaths {
            if FileManager.default.fileExists(atPath: path),
               let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
               let config = try? JSONDecoder().decode(AppConfig.self, from: data) {
                print("[Config] Loaded from \(path)")
                return config
            }
        }

        print("[Config] No config found, using defaults. Run 'voicetag --init-config' to create one.")
        return .default
    }

    // MARK: - Save default config
    func saveDefault() throws {
        let configDir = ("~/.voicetag" as NSString).expandingTildeInPath
        try FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true)
        let configPath = configDir + "/config.json"
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: URL(fileURLWithPath: configPath))
        print("[Config] Written to \(configPath)")
    }
}
