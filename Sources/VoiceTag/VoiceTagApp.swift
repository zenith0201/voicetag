import SwiftUI

@main
struct VoiceTagApp: App {
    @StateObject private var appState = AppState()
    @State private var setupComplete = UserDefaults.standard.bool(forKey: "setupComplete")

    var body: some Scene {
        WindowGroup {
            Group {
                if setupComplete {
                    ContentView()
                        .environmentObject(appState)
                        .frame(minWidth: 900, minHeight: 650)
                } else {
                    SetupWizard(isComplete: $setupComplete)
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Navigation") {
                Button("Previous Image") { appState.navigatePrevious() }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button("Next Image") { appState.navigateNext() }
                    .keyboardShortcut(.rightArrow, modifiers: [])
            }
        }
    }
}
