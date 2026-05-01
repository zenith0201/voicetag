import SwiftUI
import AppKit

struct ImageViewerPanel: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack {
                    Color.black
                    if let url = appState.currentImageURL,
                       let nsImage = NSImage(contentsOf: url) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .id(url)
                            .transition(.opacity.animation(.easeInOut(duration: 0.12)))
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 64))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            navigationBar.background(.ultraThickMaterial)
        }
        .focusable()
        .onKeyPress(.leftArrow) {
            // Block navigation when tag editor is open
            guard !appState.showTagEditor else { return .ignored }
            appState.smartNavigateBack()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            guard !appState.showTagEditor else { return .ignored }
            appState.navigateNext()
            return .handled
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 16) {
            Button(action: {
                guard !appState.showTagEditor else { return }
                appState.smartNavigateBack()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    if appState.lastActionWasTag {
                        Text("Undo").font(.caption).foregroundStyle(.orange)
                    }
                }
                .frame(minWidth: 44, minHeight: 32)
            }
            .buttonStyle(.borderless)
            .disabled(appState.showTagEditor)
            .help(appState.lastActionWasTag ? "Undo last tag" : "Previous image")

            Spacer()

            VStack(spacing: 2) {
                Text(appState.currentImageName)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1).truncationMode(.middle)
                if let url = appState.currentImageURL,
                   let dateStr = EXIFReader.formattedDate(url) {
                    Text(dateStr).font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: {
                guard !appState.showTagEditor else { return }
                appState.navigateNext()
            }) {
                Image(systemName: "chevron.right").frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
            .disabled(appState.currentIndex >= appState.imageFiles.count - 1 || appState.showTagEditor)
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
    }
}
