import Foundation
import AVFoundation

// MARK: - WhisperService

/// Manages audio capture and transcription via whisper.cpp (local) or OpenAI API.
@MainActor
final class WhisperService: NSObject, ObservableObject {

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var audioBuffer: [AVAudioPCMBuffer] = []
    private var tempAudioURL: URL?
    private var isEngineRunning = false

    // Public config hook - set before use
    var config: AppConfig = .default

    // MARK: - Recording

    func startRecording() {
        audioBuffer.removeAll()
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        let engine = AVAudioEngine()
        audioEngine = engine
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.audioBuffer.append(buffer)
        }

        do {
            try engine.start()
            isEngineRunning = true
        } catch {
            Logger.shared.log("Audio engine start error: \(error)", level: .error)
        }
    }

    /// Stop recording, write to temp WAV, return URL
    func stopRecording() async throws -> URL {
        guard let engine = audioEngine, isEngineRunning else {
            throw WhisperError.recordingFailed("Engine not running")
        }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isEngineRunning = false

        guard !audioBuffer.isEmpty else {
            throw WhisperError.emptyAudio
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        try writePCMBuffers(audioBuffer, to: tempURL)
        tempAudioURL = tempURL
        audioEngine = nil
        return tempURL
    }

    // MARK: - Transcription

    func transcribe(_ audioURL: URL) async throws -> String {
        switch config.whisperMode {
        case .local:
            return try await transcribeLocal(audioURL)
        case .api:
            return try await transcribeAPI(audioURL)
        }
    }

    // MARK: - Local (whisper.cpp)

    private func transcribeLocal(_ audioURL: URL) async throws -> String {
        // Locate whisper.cpp main binary
        let whisperPaths = [
            "/usr/local/bin/whisper-cpp",
            "/opt/homebrew/bin/whisper-cpp",
            "\(NSHomeDirectory())/.voicetag/whisper-cpp/main",
            "./whisper-cpp/main"
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
                "--output-txt",
                "--no-timestamps",
                "--language", "en",
                "--threads", "4",
                "--best-of", "1"
            ]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            process.terminationHandler = { proc in
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let text = String(data: data, encoding: .utf8) ?? ""
                let cleaned = text
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && !$0.hasPrefix("[") }
                    .joined(separator: " ")

                if proc.terminationStatus == 0 {
                    continuation.resume(returning: cleaned)
                } else {
                    let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errText = String(data: errData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: WhisperError.transcriptionFailed(errText))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - API (OpenAI)

    private func transcribeAPI(_ audioURL: URL) async throws -> String {
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
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw WhisperError.apiError("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        struct WhisperResponse: Codable { let text: String }
        let decoded = try JSONDecoder().decode(WhisperResponse.self, from: data)
        return decoded.text
    }

    // MARK: - WAV Writer

    private func writePCMBuffers(_ buffers: [AVAudioPCMBuffer], to url: URL) throws {
        guard let firstBuffer = buffers.first else { return }
        let format = firstBuffer.format

        // Resample to 16kHz mono (Whisper's preferred format)
        let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: true
        )!

        let outputFile = try AVAudioFile(forWriting: url, settings: outputFormat.settings)

        for buffer in buffers {
            // If format matches, write directly; otherwise convert
            if buffer.format.sampleRate == 16000 && buffer.format.channelCount == 1 {
                try outputFile.write(from: buffer)
            } else {
                guard let converter = AVAudioConverter(from: format, to: outputFormat) else { continue }
                let frameCapacity = AVAudioFrameCount(
                    Double(buffer.frameLength) * 16000.0 / format.sampleRate
                )
                guard let convertedBuffer = AVAudioPCMBuffer(
                    pcmFormat: outputFormat,
                    frameCapacity: frameCapacity
                ) else { continue }

                let isDoneRef = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
                isDoneRef.initialize(to: false)
                let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                    if isDoneRef.pointee {
                        outStatus.pointee = .noDataNow
                        return nil
                    }
                    isDoneRef.pointee = true
                    outStatus.pointee = .haveData
                    return buffer
                }

                var error: NSError?
                converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
                isDoneRef.deallocate()
                if error == nil {
                    try outputFile.write(from: convertedBuffer)
                }
            }
        }
        _ = outputFile // ensures flush/close on deinit
    }
}

// MARK: - Errors

enum WhisperError: LocalizedError {
    case recordingFailed(String)
    case emptyAudio
    case binaryNotFound
    case modelNotFound(String)
    case transcriptionFailed(String)
    case missingAPIKey
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .recordingFailed(let msg): return "Recording failed: \(msg)"
        case .emptyAudio: return "No audio was captured"
        case .binaryNotFound: return "whisper.cpp binary not found. Run setup.sh"
        case .modelNotFound(let m): return "Whisper model '\(m)' not found. Run setup.sh"
        case .transcriptionFailed(let msg): return "Transcription failed: \(msg)"
        case .missingAPIKey: return "OpenAI API key not set in config"
        case .apiError(let msg): return "API error: \(msg)"
        }
    }
}
