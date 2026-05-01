import Foundation
import AVFoundation

@MainActor
final class WhisperService: NSObject, ObservableObject {

    var config: AppConfig = .default
    private var ffmpegProcess: Process?
    private var currentTempURL: URL?

    func startRecording() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        currentTempURL = tempURL
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        process.arguments = ["-f", "avfoundation", "-i", ":2", "-ar", "16000", "-ac", "1", "-y", tempURL.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        ffmpegProcess = process
        try? process.run()
        Logger.shared.log("Recording started: \(tempURL.path)")
    }

    func stopRecording() async throws -> URL {
        guard let process = ffmpegProcess, let tempURL = currentTempURL else {
            throw WhisperError.recordingFailed("No recording in progress")
        }
        process.terminate()
        try await Task.sleep(nanoseconds: 300_000_000)
        ffmpegProcess = nil
        guard FileManager.default.fileExists(atPath: tempURL.path) else {
            throw WhisperError.emptyAudio
        }
        let size = (try? FileManager.default.attributesOfItem(atPath: tempURL.path)[.size] as? Int) ?? 0
        Logger.shared.log("Recording stopped: \(tempURL.path) size: \(size) bytes")
        return tempURL
    }

    func transcribe(_ audioURL: URL) async throws -> String {
        switch config.whisperMode {
        case .local:  return try await transcribeLocal(audioURL)
        case .api:    return try await transcribeAPI(audioURL)
        }
    }

    private func transcribeLocal(_ audioURL: URL) async throws -> String {
        let whisperPaths = [
            "\(NSHomeDirectory())/.voicetag/whisper-cpp",
            "/usr/local/bin/whisper-cpp",
            "/opt/homebrew/bin/whisper-cpp"
        ]
        guard let whisperBin = whisperPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            throw WhisperError.binaryNotFound
        }
        let modelPath = "\(NSHomeDirectory())/.voicetag/models/ggml-\(config.whisperModel).bin"
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw WhisperError.modelNotFound(config.whisperModel)
        }
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: whisperBin)
            process.arguments = ["-m", modelPath, "-f", audioURL.path, "-l", "en", "-t", "4"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            process.terminationHandler = { _ in
                let raw = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let text = raw.components(separatedBy: .newlines).compactMap { line -> String? in
                    let t = line.trimmingCharacters(in: .whitespaces)
                    if t.isEmpty { return nil }
                    if t.hasPrefix("["), let r = t.range(of: "]   ") {
                        let x = String(t[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                        return x.isEmpty ? nil : x
                    }
                    if t.hasPrefix("[") { return nil }
                    return t
                }.joined(separator: " ")
                Logger.shared.log("Whisper output: \(text)")
                continuation.resume(returning: text)
            }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }
    }

    private func transcribeAPI(_ audioURL: URL) async throws -> String {
        guard let apiKey = config.whisperAPIKey, !apiKey.isEmpty else { throw WhisperError.missingAPIKey }
        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let audioData = try Data(contentsOf: audioURL)
        var body = Data()
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"model\"\r\n\r\nwhisper-1\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\nContent-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        let (data, _) = try await URLSession.shared.data(for: request)
        struct R: Codable { let text: String }
        return try JSONDecoder().decode(R.self, from: data).text
    }
}

enum WhisperError: LocalizedError {
    case recordingFailed(String), emptyAudio, binaryNotFound, modelNotFound(String), transcriptionFailed(String), missingAPIKey, apiError(String)
    var errorDescription: String? {
        switch self {
        case .recordingFailed(let m): return "Recording failed: \(m)"
        case .emptyAudio: return "No audio captured"
        case .binaryNotFound: return "whisper.cpp not found — run setup.sh"
        case .modelNotFound(let m): return "Model '\(m)' not found — run setup.sh"
        case .transcriptionFailed(let m): return "Transcription failed: \(m)"
        case .missingAPIKey: return "OpenAI API key not set"
        case .apiError(let m): return "API error: \(m)"
        }
    }
}
