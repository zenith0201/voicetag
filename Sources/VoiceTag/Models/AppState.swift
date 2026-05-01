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

    // Tracks whether the most recent navigation was a tag action
    // so left arrow can undo it instead of just going back
    @Published var lastActionWasTag: Bool = false

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
        }
    }

    func navigatePrevious() {
        if hasImages, currentIndex > 0 {
            currentIndex -= 1
            lastActionWasTag = false
        }
    }

    /// Smart left arrow: if the last action was a tag, undo it and show that image.
    /// Otherwise just go to previous image.
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

    // MARK: - Folder Loading
    func loadFolder(_ url: URL) {
        currentFolderURL = url
        let supported = ["jpg","jpeg","png","heic","heif","tiff","tif","gif","webp","bmp","raw","cr2","nef","arw"]
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
            imageFiles = contents
                .filter { supported.contains($0.pathExtension.lowercased()) }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            currentIndex = 0
            lastActionWasTag = false
            statusMessage = "Loaded \(imageFiles.count) images"
            Logger.shared.log("Loaded folder: \(url.path) — \(imageFiles.count) images")
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }
    }

    // MARK: - Voice Recording
    func startRecording() {
        guard currentImageURL != nil else { statusMessage = "No image selected"; return }
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
        let action = tagParser.parse(text: tag, currentFolder: currentFolderURL, config: config)
        Task { await executeAction(action, transcription: tag) }
    }

    // MARK: - Handle transcription
    func handleTranscription(_ text: String) async {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        lastTranscription = cleaned
        guard !cleaned.isEmpty, let imageURL = currentImageURL else {
            await MainActor.run { statusMessage = "Nothing detected"; isProcessing = false }
            return
        }
        let action = tagParser.parse(text: cleaned, currentFolder: currentFolderURL, config: config)
        lastAction = action
        Logger.shared.log("Image: \(imageURL.lastPathComponent) | Said: \"\(cleaned)\" | Action: \(action.description)")
        await executeAction(action, transcription: cleaned)
    }

    // MARK: - Execute action
    func executeAction(_ action: TagAction, transcription: String) async {
        guard let imageURL = currentImageURL else {
            await MainActor.run { isProcessing = false }
            return
        }
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
                    lastActionWasTag = true  // deletions are also undoable with left arrow
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
                    lastActionWasTag = true  // ← will undo this
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
                // Restore image into current list
                imageFiles.append(last.originalURL)
                imageFiles.sort { $0.lastPathComponent < $1.lastPathComponent }
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
