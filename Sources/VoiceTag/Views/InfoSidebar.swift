import SwiftUI

struct InfoSidebar: View {
    @EnvironmentObject var appState: AppState
    @FocusState private var tagFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statusSection
                Divider()
                if appState.showTagEditor {
                    tagEditorSection
                    Divider()
                }
                modelPickerSection
                Divider()
                outputDirectorySection
                Divider()
                recentTagsSection
                Divider()
                metadataSection
                Divider()
                historySection
                Spacer()
            }
            .padding(16)
        }
    }

    // MARK: - Status
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Status", systemImage: "waveform").font(.headline)

            HStack(spacing: 8) {
                Circle().fill(statusColor).frame(width: 8, height: 8)
                Text(appState.statusMessage)
                    .font(.system(.body, design: .rounded))
                    .lineLimit(2)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            // Last transcription with pencil edit button
            if !appState.lastTranscription.isEmpty && !appState.showTagEditor {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Heard:").font(.caption).foregroundStyle(.secondary)
                        Text("\"\(appState.lastTranscription)\"").font(.body.italic()).lineLimit(2)
                    }
                    Spacer()
                    // Pencil button — opens editor only on demand
                    Button(action: { appState.openTagEditor() }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Edit this tag")
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }

            if !appState.isRecording && !appState.isProcessing && !appState.showTagEditor {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Hold SPACE to tag", systemImage: "mic.circle")
                        .font(.caption).foregroundStyle(.tertiary)
                    if !appState.lastTagLabel.isEmpty {
                        Label("Shift+SPACE → \"\(appState.lastTagLabel)\"", systemImage: "repeat")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - Tag Editor (only shown when pencil is tapped)
    private var tagEditorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Edit Tag", systemImage: "pencil.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Button(action: { appState.dismissTagEditor() }) {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                TextField("Type tag and press Enter...", text: $appState.pendingTagText)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .rounded))
                    .padding(10)
                    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: 1.5))
                    .focused($tagFieldFocused)
                    .onSubmit { appState.applyPendingTag() }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            tagFieldFocused = true
                        }
                    }

                Button(action: { appState.applyPendingTag() }) {
                    Image(systemName: "return")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .help("Apply tag (Enter)")
            }

            Text("All keys work in text field · Enter to apply · Esc to cancel")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
        .onKeyPress(.escape) {
            appState.dismissTagEditor()
            return .handled
        }
    }

    // MARK: - Model Picker
    private var modelPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Voice Model", systemImage: "waveform.badge.mic").font(.headline)
            VStack(spacing: 6) {
                modelButton(mode: .sarvam, icon: "🇮🇳", title: "Sarvam AI",
                           subtitle: "Best for Indian accents & places", badge: "Recommended")
                modelButton(mode: .local, icon: "💻", title: "Local (whisper.cpp)",
                           subtitle: "Offline · No API key needed", badge: nil)
                modelButton(mode: .api, icon: "☁️", title: "OpenAI Whisper",
                           subtitle: "Cloud · Needs API key", badge: nil)
            }
        }
    }

    private func modelButton(mode: AppConfig.WhisperMode, icon: String, title: String, subtitle: String, badge: String?) -> some View {
        let isSelected = appState.config.whisperMode == mode
        return Button(action: { appState.setWhisperMode(mode) }) {
            HStack(spacing: 10) {
                Text(icon).font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isSelected ? Color.accentColor : .primary)
                        if let badge = badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                                .foregroundStyle(.green)
                        }
                    }
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor).font(.system(size: 16))
                }
            }
            .padding(10)
            .background(
                isSelected ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Output Directory
    private var outputDirectorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Output Folder", systemImage: "folder").font(.headline)

            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(Color.accentColor)
                    .font(.system(size: 14))

                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.outputDirectoryURL.lastPathComponent)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(appState.outputDirectoryURL.path
                        .replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Button(action: { showOutputFolderPicker() }) {
                    Text("Change")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help("Choose output folder")
            }
            .padding(10)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func showOutputFolderPicker() {
        let panel = NSOpenPanel()
        panel.title = "Choose Output Folder"
        panel.message = "Sorted photos will be moved here"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            appState.setOutputDirectory(url)
        }
    }

    // MARK: - Recent Tags
    private var recentTagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Recent Tags", systemImage: "tag").font(.headline)
            if appState.recentTags.isEmpty {
                Text("Tags you use will appear here").font(.caption).foregroundStyle(.tertiary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(appState.recentTags, id: \.self) { tag in
                        Button(action: { appState.applyTag(tag) }) {
                            Text(tag)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("Apply tag: \(tag)")
                    }
                }
            }
        }
    }

    // MARK: - Metadata
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Current Image", systemImage: "info.circle").font(.headline)
            if let url = appState.currentImageURL {
                let meta = EXIFReader.read(from: url)
                VStack(alignment: .leading, spacing: 6) {
                    metaRow("File", url.lastPathComponent)
                    metaRow("Folder", url.deletingLastPathComponent().lastPathComponent)
                    if let date = meta.dateTaken {
                        metaRow("Date", DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short))
                    }
                    if let w = meta.width, let h = meta.height { metaRow("Size", "\(w) × \(h)") }
                    if let camera = meta.cameraModel { metaRow("Camera", camera) }
                }
            } else {
                Text("No image selected").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - History
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("History", systemImage: "clock.arrow.circlepath").font(.headline)
                Spacer()
                if !appState.actionHistory.isEmpty {
                    Button("Undo") { Task { await appState.performUndo() } }
                        .font(.caption).buttonStyle(.bordered).controlSize(.mini)
                }
            }
            if appState.actionHistory.isEmpty {
                Text("No actions yet").font(.caption).foregroundStyle(.tertiary)
            } else {
                ForEach(appState.actionHistory.reversed().prefix(8), id: \.timestamp) { entry in
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.originalURL.lastPathComponent)
                                .font(.caption.weight(.medium)).lineLimit(1)
                            Text("→ \(entry.destinationURL.deletingLastPathComponent().lastPathComponent)")
                                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    .padding(6)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label + ":").font(.caption).foregroundStyle(.secondary).frame(width: 56, alignment: .trailing)
            Text(value).font(.caption).lineLimit(2)
        }
    }

    private var statusColor: Color {
        if appState.isRecording { return .red }
        if appState.isProcessing { return .orange }
        if appState.showTagEditor { return .blue }
        return .green
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { $0.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0 }.reduce(0) { $0 + $1 + spacing }
        return CGSize(width: proposal.width ?? 0, height: height)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var x: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, !rows[rows.count - 1].isEmpty { rows.append([]); x = 0 }
            rows[rows.count - 1].append(subview)
            x += size.width + spacing
        }
        return rows
    }
}

// MARK: - Overlays
struct RecordingOverlay: View {
    @State private var scale: CGFloat = 1.0
    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.red.opacity(0.25)).frame(width: 100, height: 100)
                        .scaleEffect(scale)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: scale)
                    Image(systemName: "mic.fill").font(.system(size: 44)).foregroundStyle(.white)
                }
                Text("Listening...").font(.title3.bold()).foregroundStyle(.white)
                Text("Release SPACE to tag").font(.caption).foregroundStyle(.white.opacity(0.7))
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
        .onAppear { scale = 1.2 }
    }
}

struct ProcessingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.2).ignoresSafeArea()
            HStack(spacing: 12) {
                ProgressView().scaleEffect(0.8)
                Text("Transcribing...").font(.subheadline)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
