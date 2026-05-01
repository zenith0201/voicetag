import Foundation
import AVFoundation

// MARK: - WhisperService
// Supports three transcription backends:
//   local  → whisper.cpp (offline, Apple Silicon optimized)
//   api    → OpenAI Whisper API
//   sarvam → Sarvam AI (best for Indian languages & accents)

@MainActor
final class WhisperService: NSObject, ObservableObject {

    var config: AppConfig = .default
    private var ffmpegProcess: Process?
    private var currentTempURL: URL?

    // MARK: - Recording

    func startRecording() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        currentTempURL = tempURL
        let micIndex = detectMicIndex()
        Logger.shared.log("Using mic index: \(micIndex)")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        process.arguments = ["-f", "avfoundation", "-i", ":\(micIndex)",
                             "-ar", "16000", "-ac", "1", "-y", tempURL.path]
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

    // MARK: - Transcription router

    func transcribe(_ audioURL: URL) async throws -> String {
        switch config.whisperMode {
        case .local:   return try await transcribeLocal(audioURL)
        case .api:     return try await transcribeOpenAI(audioURL)
        case .sarvam:  return try await transcribeSarvam(audioURL)
        }
    }

    // MARK: - Backend: whisper.cpp (local, offline)

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
            process.arguments = [
                "-m", modelPath,
                "-f", audioURL.path,
                "-l", "en",
                "-t", "4",
                "--prompt", "Beach, Mountains, City Trip, Day 1, Day 2, Day 3, landscape, family, delete, skip, undo"
            ]
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
                continuation.resume(returning: text)
            }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }
    }

    // MARK: - Backend: OpenAI Whisper API

    private func transcribeOpenAI(_ audioURL: URL) async throws -> String {
        guard let apiKey = config.whisperAPIKey, !apiKey.isEmpty else {
            throw WhisperError.missingAPIKey
        }
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
        let result = try JSONDecoder().decode(R.self, from: data)
        Logger.shared.log("OpenAI Whisper output: \(result.text)")
        return result.text
    }

    // MARK: - Backend: Sarvam AI (best for Indian languages)

    private func transcribeSarvam(_ audioURL: URL) async throws -> String {
        guard let apiKey = config.sarvamAPIKey, !apiKey.isEmpty else {
            throw WhisperError.missingSarvamKey
        }

        let url = URL(string: "https://api.sarvam.ai/speech-to-text")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue(apiKey, forHTTPHeaderField: "api-subscription-key")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let audioData = try Data(contentsOf: audioURL)
        var body = Data()

        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\nContent-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"model\"\r\n\r\nsaaras:v3\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"mode\"\r\n\r\ntranscribe\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"language_code\"\r\n\r\n\(config.sarvamLanguage)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errText = String(data: data, encoding: .utf8) ?? "Unknown"
            Logger.shared.log("Sarvam error \(httpResponse.statusCode): \(errText)", level: .error)
            throw WhisperError.apiError("Sarvam \(httpResponse.statusCode): \(errText)")
        }

        struct SarvamResponse: Codable { let transcript: String }
        let result = try JSONDecoder().decode(SarvamResponse.self, from: data)
        Logger.shared.log("Sarvam output: \(result.transcript)")
        return result.transcript
    }

    // MARK: - Mic detection

    private func detectMicIndex() -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        p.arguments = ["-f", "avfoundation", "-list_devices", "true", "-i", ""]
        let pipe = Pipe()
        p.standardError = pipe
        p.standardOutput = Pipe()
        try? p.run()
        p.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        for line in output.components(separatedBy: .newlines) {
            let lower = line.lowercased()
            if lower.contains("macbook") && lower.contains("micro") {
                if let range = line.range(of: #"\[(\d+)\]"#, options: .regularExpression),
                   let numRange = line[range].range(of: #"\d+"#, options: .regularExpression) {
                    return String(line[range][numRange])
                }
            }
        }
        return "2"
    }
}

// MARK: - Errors

enum WhisperError: LocalizedError {
    case recordingFailed(String), emptyAudio, binaryNotFound
    case modelNotFound(String), transcriptionFailed(String)
    case missingAPIKey, missingSarvamKey, apiError(String)

    var errorDescription: String? {
        switch self {
        case .recordingFailed(let m):     return "Recording failed: \(m)"
        case .emptyAudio:                 return "No audio captured"
        case .binaryNotFound:             return "whisper.cpp not found — run setup.sh"
        case .modelNotFound(let m):       return "Model '\(m)' not found — run setup.sh"
        case .transcriptionFailed(let m): return "Transcription failed: \(m)"
        case .missingAPIKey:              return "OpenAI API key not set in config"
        case .missingSarvamKey:           return "Sarvam API key not set in config"
        case .apiError(let m):            return "API error: \(m)"
        }
    }
}
