import Foundation

struct AppConfig: Codable {
    var baseDirectory: String
    var whisperMode: WhisperMode
    var whisperAPIKey: String?
    var sarvamAPIKey: String?
    var whisperModel: String
    var sarvamLanguage: String
    var skipCommands: [String]
    var deleteCommands: [String]
    var undoCommands: [String]
    var trashFolderName: String
    var tagMappings: [String: String]
    var debugMode: Bool
    var logFile: String

    enum WhisperMode: String, Codable {
        case local      // whisper.cpp — offline, no API key needed
        case api        // OpenAI Whisper API
        case sarvam     // Sarvam AI — best for Indian languages & accents
    }

    var baseDirectoryURL: URL {
        URL(fileURLWithPath: (baseDirectory as NSString).expandingTildeInPath)
    }

    var logFileURL: URL {
        URL(fileURLWithPath: (logFile as NSString).expandingTildeInPath)
    }

    static var `default`: AppConfig {
        AppConfig(
            baseDirectory: "~/Pictures/VoiceTagged",
            whisperMode: .local,
            whisperAPIKey: nil,
            sarvamAPIKey: nil,
            whisperModel: "base.en",
            sarvamLanguage: "en-IN",
            skipCommands: ["skip", "next", "pass"],
            deleteCommands: ["delete", "trash", "remove", "discard"],
            undoCommands: ["undo", "go back", "revert"],
            trashFolderName: "Trash_Sorted",
            tagMappings: [:],
            debugMode: false,
            logFile: "~/.voicetag/voicetag.log"
        )
    }

    static func load() -> AppConfig {
        let paths = [
            "~/.voicetag/config.json",
            "~/.config/voicetag/config.json"
        ].map { ($0 as NSString).expandingTildeInPath }

        for path in paths {
            if FileManager.default.fileExists(atPath: path),
               let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
               let config = try? JSONDecoder().decode(AppConfig.self, from: data) {
                return config
            }
        }
        return .default
    }
}
