import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var keyboardMonitor = KeyboardMonitor()
    @State private var showingFolderPicker = false
    @State private var isDraggingOver = false

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()

            if appState.hasImages {
                HStack(spacing: 0) {
                    ImageViewerPanel()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Divider()
                    InfoSidebar()
                        .frame(width: 260)
                }
            } else {
                emptyState
            }

            if appState.isRecording { RecordingOverlay() }
            if appState.isProcessing { ProcessingOverlay() }
        }
        .onAppear { setupKeyboardMonitor() }
        .onDisappear { keyboardMonitor.stop() }
        .fileImporter(isPresented: $showingFolderPicker, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first { appState.loadFolder(url) }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
            handleDrop(providers: providers)
        }
        .overlay(isDraggingOver ? RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: 3).padding(4) : nil)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: { showingFolderPicker = true }) {
                    Label("Open Folder", systemImage: "folder.badge.plus")
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                if appState.hasImages {
                    Button(action: { Task { await appState.performUndo() } }) {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(appState.actionHistory.isEmpty)
                    Divider()
                    Text(appState.progressText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.stack")
                .font(.system(size: 72))
                .foregroundStyle(.tertiary)

            VStack(spacing: 8) {
                Text("VoiceTag").font(.largeTitle.bold())
                Text("Voice-controlled photo sorting for macOS")
                    .font(.title3).foregroundStyle(.secondary)
            }

            Button(action: { showingFolderPicker = true }) {
                Label("Open Folder", systemImage: "folder.badge.plus")
                    .padding(.horizontal, 20).padding(.vertical, 10)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("o", modifiers: .command)

            Text("Or drag a folder here").font(.caption).foregroundStyle(.tertiary)

            quickHelpView
        }
        .frame(maxWidth: 480).padding()
    }

    private var quickHelpView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Reference").font(.headline).padding(.bottom, 4)
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    helpRow("← →", "Navigate images")
                    helpRow("Hold SPACE", "Record voice tag")
                    helpRow("Shift+SPACE", "Repeat last tag")
                    helpRow("⌘Z", "Undo last action")
                }
                VStack(alignment: .leading, spacing: 8) {
                    helpRow("\"skip\"", "Skip, no action")
                    helpRow("\"delete\"", "Move to trash")
                    helpRow("\"undo\"", "Undo via voice")
                    helpRow("Enter", "Apply edited tag")
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: 420)
    }

    private func helpRow(_ key: String, _ desc: String) -> some View {
        HStack(spacing: 6) {
            Text(key)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            Text(desc).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Keyboard setup
    private func setupKeyboardMonitor() {
        keyboardMonitor.onSpaceDown = {
            // Block mic if tag editor is open — user is typing
            guard !appState.showTagEditor else { return }
            guard !appState.isRecording, !appState.isProcessing else { return }
            appState.startRecording()
        }
        keyboardMonitor.onSpaceUp = {
            guard !appState.showTagEditor else { return }
            guard appState.isRecording else { return }
            appState.stopRecordingAndProcess()
        }
        keyboardMonitor.onShiftSpaceDown = {
            guard !appState.showTagEditor else { return }
            appState.repeatLastTag()
        }
        keyboardMonitor.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                DispatchQueue.main.async { appState.loadFolder(url) }
            }
        }
        return true
    }
}
