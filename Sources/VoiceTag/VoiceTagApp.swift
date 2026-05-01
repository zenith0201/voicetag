import SwiftUI

@main
struct VoiceTagApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 650)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Navigation") {
                Button("Previous Image") {
                    appState.navigatePrevious()
                }
                .keyboardShortcut(.leftArrow, modifiers: [])

                Button("Next Image") {
                    appState.navigateNext()
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
            }
        }
    }
}
