import SwiftUI

struct InfoSidebar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statusSection
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
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(appState.statusMessage)
                    .font(.system(.body, design: .rounded))
                    .lineLimit(2)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            if !appState.lastTranscription.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Heard:").font(.caption).foregroundStyle(.secondary)
                    Text("\"\(appState.lastTranscription)\"")
                        .font(.body.italic())
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }

            if !appState.isRecording && !appState.isProcessing {
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

    // MARK: - Recent Tags
    private var recentTagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Recent Tags", systemImage: "tag").font(.headline)

            if appState.recentTags.isEmpty {
                Text("Tags you use will appear here")
                    .font(.caption).foregroundStyle(.tertiary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(appState.recentTags, id: \.self) { tag in
                        Button(action: { appState.applyTag(tag) }) {
                            Text(tag)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
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
                    if let w = meta.width, let h = meta.height {
                        metaRow("Size", "\(w) × \(h)")
                    }
                    if let camera = meta.cameraModel {
                        metaRow("Camera", camera)
                    }
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
        return .green
    }
}

// MARK: - Flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        return CGSize(width: proposal.width ?? 0, height: rows.map { $0.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0 }.reduce(0) { $0 + $1 + spacing })
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
            if x + size.width > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([])
                x = 0
            }
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
