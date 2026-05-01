import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {

    @Published var imageFiles: [URL] = []
    @Published var currentIndex: Int = 0
    @Published var currentFolderURL: URL?
    @Published var isRecording: Bool = false
    @Published var lastTranscription: String = ""
    @Published var lastAction: TagAction?
    @Published var statusMessage: String = "Open a folder to begin"
    @Published var isProcessing: Bool = false
    @Published var actionHistory: [HistoryEntry] = []
    @Published var recentTags: [String] = []
    @Published var lastActionWasTag: Bool = false

    // Editable tag — shown after transcription so user can fix before applying
    @Published var pendingTagText: String = ""
    @Published var showTagEditor: Bool = false

    var lastTagAction: TagAction?
    var lastTagLabel: String = ""

    let whisperService = WhisperService()
    let fileService = FileService()
    let tagParser = TagParser()
    var config: AppConfig = .default

    init() {
        let cfg = AppConfig.load()
        self.config = cfg
        self.whisperService.config = cfg
        Logger.shared.configure(logFileURL: cfg.logFileURL)
    }

    var currentImageURL: URL? {
        guard !imageFiles.isEmpty, currentIndex < imageFiles.count else { return nil }
        return imageFiles[currentIndex]
    }
    var currentImageName: String { currentImageURL?.lastPathComponent ?? "—" }
    var currentFolderName: String { currentFolderURL?.lastPathComponent ?? "—" }
    var hasImages: Bool { !imageFiles.isEmpty }
    var progressText: String { hasImages ? "\(currentIndex + 1) / \(imageFiles.count)" : "" }

    // MARK: - Navigation
    func navigateNext() {
        if hasImages, currentIndex < imageFiles.count - 1 {
            currentIndex += 1
            lastActionWasTag = false
            dismissTagEditor()
        }
    }

    func navigatePrevious() {
        if hasImages, currentIndex > 0 {
            currentIndex -= 1
            lastActionWasTag = false
            dismissTagEditor()
        }
    }

    func smartNavigateBack() {
        if lastActionWasTag && !actionHistory.isEmpty {
            lastActionWasTag = false
            statusMessage = "↩️ Undoing last tag..."
            isProcessing = true
            Task { await performUndo() }
        } else {
            navigatePrevious()
        }
    }

    func dismissTagEditor() {
        showTagEditor = false
        pendingTagText = ""
    }

    // MARK: - Folder Loading
    func loadFolder(_ url: URL) {
        currentFolderURL = url
        let supported: Set<String> = ["jpg","jpeg","png","heic","heif","tiff","tif","gif","webp","bmp","raw","cr2","nef","arw"]
        var found: [URL] = []
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        while let fileURL = enumerator?.nextObject() as? URL {
            if supported.contains(fileURL.pathExtension.lowercased()) {
                found.append(fileURL)
            }
        }
        imageFiles = found.sorted { $0.path < $1.path }
        currentIndex = 0
        lastActionWasTag = false
        dismissTagEditor()
        statusMessage = "Loaded \(imageFiles.count) images"
        Logger.shared.log("Loaded folder: \(url.path) — \(imageFiles.count) images (recursive)")
    }

    // MARK: - Voice Recording
    func startRecording() {
        guard currentImageURL != nil else { statusMessage = "No image selected"; return }
        dismissTagEditor()
        isRecording = true
        statusMessage = "🎙 Recording..."
        whisperService.startRecording()
    }

    func stopRecordingAndProcess() {
        guard isRecording else { return }
        isRecording = false
        isProcessing = true
        statusMessage = "⚙️ Processing..."
        Task {
            do {
                let audioURL = try await whisperService.stopRecording()
                let transcription = try await whisperService.transcribe(audioURL)
                await handleTranscription(transcription)
            } catch {
                await MainActor.run {
                    statusMessage = "Error: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }

    // MARK: - Repeat Last Tag (Shift+Space)
    func repeatLastTag() {
        guard let action = lastTagAction, currentImageURL != nil,
              !isProcessing, !isRecording else {
            statusMessage = lastTagAction == nil ? "No previous tag" : "Busy"
            return
        }
        isProcessing = true
        statusMessage = "⚡ \(lastTagLabel)"
        Task { await executeAction(action, transcription: lastTagLabel) }
    }

    // MARK: - Quick tag from sidebar
    func applyTag(_ tag: String) {
        guard currentImageURL != nil, !isProcessing, !isRecording else { return }
        isProcessing = true
        dismissTagEditor()
        let action = tagParser.parse(text: tag, currentFolder: currentFolderURL, config: config)
        Task { await executeAction(action, transcription: tag) }
    }

    // MARK: - Apply pending tag from editor (user pressed Enter)
    func applyPendingTag() {
        let tag = pendingTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { dismissTagEditor(); return }
        // Add to recent tags immediately so it shows even if manually typed
        addRecentTag(tag)
        applyTag(tag)
    }

    // MARK: - Handle transcription
    func handleTranscription(_ text: String) async {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        lastTranscription = cleaned
        isProcessing = false

        guard !cleaned.isEmpty, currentImageURL != nil else {
            statusMessage = "Nothing detected — press ✏️ to type a tag"
            return
        }

        // Auto-apply the tag directly — user can tap pencil to edit if wrong
        pendingTagText = cleaned
        let action = tagParser.parse(text: cleaned, currentFolder: currentFolderURL, config: config)
        lastAction = action
        Logger.shared.log("Image: \(currentImageURL!.lastPathComponent) | Said: \"\(cleaned)\" | Action: \(action.description)")
        isProcessing = true
        await executeAction(action, transcription: cleaned)
    }

    // MARK: - Open tag editor manually (pencil button)
    func openTagEditor() {
        pendingTagText = lastTranscription
        showTagEditor = true
        statusMessage = "✏️ Edit tag and press Enter"
    }

    // MARK: - Execute action
    func executeAction(_ action: TagAction, transcription: String) async {
        guard let imageURL = currentImageURL else {
            await MainActor.run { isProcessing = false }
            return
        }

        dismissTagEditor()

        switch action {
        case .skip:
            await MainActor.run {
                statusMessage = "⏭ Skipped"
                isProcessing = false
                lastActionWasTag = false
                navigateNext()
            }

        case .delete(let folder):
            do {
                let entry = try await fileService.move(imageURL, toFolder: folder, createIfNeeded: true)
                await MainActor.run {
                    actionHistory.append(entry)
                    lastActionWasTag = true
                    removeCurrentFromList()
                    statusMessage = "🗑 Trashed — press ← to undo"
                    isProcessing = false
                }
            } catch {
                await MainActor.run { statusMessage = "Move failed: \(error.localizedDescription)"; isProcessing = false }
            }

        case .tag(let folderPath):
            do {
                let entry = try await fileService.move(imageURL, toFolder: folderPath, createIfNeeded: true)
                await MainActor.run {
                    actionHistory.append(entry)
                    lastTagAction = action
                    lastTagLabel = transcription
                    lastActionWasTag = true
                    addRecentTag(transcription)
                    removeCurrentFromList()
                    statusMessage = "✅ → \(folderPath.lastPathComponent)  (← to undo)"
                    isProcessing = false
                }
            } catch {
                await MainActor.run { statusMessage = "Move failed: \(error.localizedDescription)"; isProcessing = false }
            }

        case .undo:
            await performUndo()
        }
    }

    // MARK: - Recent tags
    private func addRecentTag(_ tag: String) {
        let t = tag.lowercased().trimmingCharacters(in: .whitespaces)
        recentTags.removeAll { $0 == t }
        recentTags.insert(t, at: 0)
        if recentTags.count > 8 { recentTags = Array(recentTags.prefix(8)) }
    }

    private func removeCurrentFromList() {
        guard !imageFiles.isEmpty else { return }
        imageFiles.remove(at: currentIndex)
        if currentIndex >= imageFiles.count, currentIndex > 0 { currentIndex = imageFiles.count - 1 }
    }

    // MARK: - Output directory
    func setOutputDirectory(_ url: URL) {
        config.baseDirectory = url.path
        whisperService.config = config
        // Persist to config file
        let configPath = ("~/.voicetag/config.json" as NSString).expandingTildeInPath
        if let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
           var dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            dict["baseDirectory"] = url.path
            if let newData = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]) {
                try? newData.write(to: URL(fileURLWithPath: configPath))
            }
        }
        statusMessage = "Output: \(url.lastPathComponent)"
        Logger.shared.log("Output directory changed to: \(url.path)")
    }

    var outputDirectoryURL: URL {
        config.baseDirectoryURL
    }

    // MARK: - Model switching
    func setWhisperMode(_ mode: AppConfig.WhisperMode) {
        config.whisperMode = mode
        whisperService.config = config
        // Persist to config file
        let configPath = ("~/.voicetag/config.json" as NSString).expandingTildeInPath
        if var data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
           var dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            dict["whisperMode"] = mode.rawValue
            if let newData = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]) {
                try? newData.write(to: URL(fileURLWithPath: configPath))
            }
        }
        let modeName: String
        switch mode {
        case .local:  modeName = "Local (whisper.cpp)"
        case .api:    modeName = "OpenAI Whisper"
        case .sarvam: modeName = "Sarvam AI"
        }
        statusMessage = "Model: \(modeName)"
        Logger.shared.log("Switched to model: \(mode.rawValue)")
    }

    // MARK: - Undo
    func performUndo() async {
        guard let last = actionHistory.last else {
            await MainActor.run { statusMessage = "Nothing to undo"; isProcessing = false }
            return
        }
        do {
            try await fileService.undoMove(last)
            await MainActor.run {
                actionHistory.removeLast()
                lastActionWasTag = false
                imageFiles.append(last.originalURL)
                imageFiles.sort { $0.path < $1.path }
                if let idx = imageFiles.firstIndex(of: last.originalURL) { currentIndex = idx }
                statusMessage = "↩️ \(last.originalURL.lastPathComponent) — re-tag it!"
                isProcessing = false
                Logger.shared.log("Undo: restored \(last.originalURL.lastPathComponent)")
            }
        } catch {
            await MainActor.run { statusMessage = "Undo failed: \(error.localizedDescription)"; isProcessing = false }
        }
    }
}
