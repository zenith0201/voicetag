import SwiftUI
import AppKit
import AVFoundation

// MARK: - Setup Wizard
// Shows on first launch. Guides user through all required setup steps.

struct SetupWizard: View {
    @Binding var isComplete: Bool
    @StateObject private var vm = SetupViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            wizardHeader

            Divider()

            // Step content
            ScrollView {
                VStack(spacing: 0) {
                    switch vm.currentStep {
                    case .welcome:      WelcomeStep(vm: vm)
                    case .dependencies: DependenciesStep(vm: vm)
                    case .backend:      BackendStep(vm: vm)
                    case .apiKey:       APIKeyStep(vm: vm)
                    case .outputFolder: OutputFolderStep(vm: vm)
                    case .permissions:  PermissionsStep(vm: vm)
                    case .done:         DoneStep(vm: vm, isComplete: $isComplete)
                    }
                }
                .padding(32)
                .frame(maxWidth: 520)
            }
            .frame(maxWidth: .infinity)

            Divider()

            // Navigation buttons
            wizardFooter
        }
        .frame(width: 600, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header
    private var wizardHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(SetupStep.allCases.enumerated()), id: \.element) { index, step in
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(stepColor(step))
                            .frame(width: 24, height: 24)
                        if vm.completedSteps.contains(step) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(vm.currentStep == step ? .white : .secondary)
                        }
                    }
                    if index < SetupStep.allCases.count - 1 {
                        Rectangle()
                            .fill(vm.completedSteps.contains(step) ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
    }

    private func stepColor(_ step: SetupStep) -> Color {
        if vm.completedSteps.contains(step) { return .accentColor }
        if vm.currentStep == step { return .accentColor }
        return Color.secondary.opacity(0.3)
    }

    // MARK: - Footer
    private var wizardFooter: some View {
        HStack {
            if vm.currentStep != .welcome && vm.currentStep != .done {
                Button("Back") { vm.goBack() }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if vm.currentStep != .done {
                Button(action: { vm.goNext() }) {
                    HStack(spacing: 6) {
                        Text(vm.nextButtonTitle)
                        if vm.isWorking {
                            ProgressView().scaleEffect(0.6).frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "arrow.right")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isNextDisabled)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
    }
}

// MARK: - Step Views

struct WelcomeStep: View {
    @ObservedObject var vm: SetupViewModel
    var body: some View {
        VStack(spacing: 24) {
            Image("AppIcon", bundle: nil)
                .resizable()
                .frame(width: 80, height: 80)
                .cornerRadius(18)
                .shadow(radius: 8)

            VStack(spacing: 8) {
                Text("Welcome to VoiceTag")
                    .font(.largeTitle.bold())
                Text("Sort hundreds of photos in minutes — just speak.\nThis wizard will set everything up in under 2 minutes.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                featureRow("🎙", "Hold SPACE, say a tag, release — photo moves instantly")
                featureRow("🇮🇳", "Powered by Sarvam AI — built for Indian accents")
                featureRow("📴", "Works offline with local whisper.cpp model")
                featureRow("↩️", "Smart undo — press ← to re-tag any photo")
            }
            .padding(16)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func featureRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Text(icon).font(.title3)
            Text(text).font(.callout).foregroundStyle(.secondary)
        }
    }
}

struct DependenciesStep: View {
    @ObservedObject var vm: SetupViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader("Check Dependencies", subtitle: "VoiceTag needs a few tools installed.")

            VStack(spacing: 10) {
                dependencyRow(
                    name: "ffmpeg",
                    description: "Audio recording",
                    status: vm.ffmpegStatus,
                    fixAction: { vm.installFFmpeg() },
                    fixLabel: "Install via Homebrew"
                )
                dependencyRow(
                    name: "whisper.cpp",
                    description: "Local speech recognition",
                    status: vm.whisperStatus,
                    fixAction: { vm.buildWhisper() },
                    fixLabel: "Build (takes ~2 min)"
                )
                dependencyRow(
                    name: "Whisper model",
                    description: "base.en (~150MB)",
                    status: vm.modelStatus,
                    fixAction: { vm.downloadModel() },
                    fixLabel: "Download"
                )
            }

            if vm.dependencyLog.count > 0 {
                ScrollView {
                    Text(vm.dependencyLog.joined(separator: "\n"))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 80)
                .padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }

            Text("whisper.cpp is only needed if you choose Local mode. You can skip if using Sarvam AI.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func dependencyRow(name: String, description: String, status: DependencyStatus, fixAction: @escaping () -> Void, fixLabel: String) -> some View {
        HStack(spacing: 12) {
            statusIcon(status)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.callout.weight(.semibold))
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if status == .missing {
                Button(fixLabel, action: fixAction)
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            } else if status == .installing {
                ProgressView().scaleEffect(0.7)
            }
        }
        .padding(12)
        .background(
            status == .ok ? Color.green.opacity(0.06) : Color.primary.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 8)
        )
    }

    private func statusIcon(_ status: DependencyStatus) -> some View {
        Group {
            switch status {
            case .ok:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .missing:
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            case .installing:
                Image(systemName: "arrow.down.circle.fill").foregroundStyle(.orange)
            case .unknown:
                Image(systemName: "questionmark.circle.fill").foregroundStyle(.secondary)
            }
        }
        .font(.title3)
    }
}

struct BackendStep: View {
    @ObservedObject var vm: SetupViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader("Choose Voice Model", subtitle: "You can change this anytime from the sidebar.")

            VStack(spacing: 10) {
                backendOption(
                    mode: .sarvam,
                    icon: "🇮🇳",
                    title: "Sarvam AI",
                    description: "Best for Indian accents, place names, and Hinglish. Requires a free API key.",
                    badge: "Recommended"
                )
                backendOption(
                    mode: .local,
                    icon: "💻",
                    title: "Local (whisper.cpp)",
                    description: "Works fully offline. No API key needed. Uses Apple Silicon GPU.",
                    badge: nil
                )
                backendOption(
                    mode: .api,
                    icon: "☁️",
                    title: "OpenAI Whisper",
                    description: "Cloud-based. Good general accuracy. Requires OpenAI API key.",
                    badge: nil
                )
            }
        }
    }

    private func backendOption(mode: AppConfig.WhisperMode, icon: String, title: String, description: String, badge: String?) -> some View {
        let isSelected = vm.selectedBackend == mode
        return Button(action: { vm.selectedBackend = mode }) {
            HStack(alignment: .top, spacing: 12) {
                Text(icon).font(.title2)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title).font(.callout.weight(.semibold))
                            .foregroundStyle(isSelected ? Color.accentColor : .primary)
                        if let badge = badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                                .foregroundStyle(.green)
                        }
                    }
                    Text(description).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor).font(.title3)
                }
            }
            .padding(14)
            .background(
                isSelected ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

struct APIKeyStep: View {
    @ObservedObject var vm: SetupViewModel
    @State private var showKey = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader(
                vm.selectedBackend == .sarvam ? "Sarvam AI API Key" : "OpenAI API Key",
                subtitle: vm.selectedBackend == .sarvam
                    ? "Get your free key at dashboard.sarvam.ai — starts with ₹1,000 free credits."
                    : "Get your key at platform.openai.com"
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("API Key").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Group {
                        if showKey {
                            TextField("Paste your API key here", text: $vm.apiKey)
                        } else {
                            SecureField("Paste your API key here", text: $vm.apiKey)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))

                    Button(action: { showKey.toggle() }) {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(vm.apiKey.isEmpty ? 0 : 0.5), lineWidth: 1)
                )
            }

            if vm.selectedBackend == .sarvam {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Language").font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $vm.sarvamLanguage) {
                        Text("English (India) — en-IN").tag("en-IN")
                        Text("Hindi — hi-IN").tag("hi-IN")
                        Text("Kannada — kn-IN").tag("kn-IN")
                        Text("Tamil — ta-IN").tag("ta-IN")
                        Text("Telugu — te-IN").tag("te-IN")
                        Text("Malayalam — ml-IN").tag("ml-IN")
                        Text("Marathi — mr-IN").tag("mr-IN")
                        Text("Bengali — bn-IN").tag("bn-IN")
                        Text("Gujarati — gu-IN").tag("gu-IN")
                        Text("Punjabi — pa-IN").tag("pa-IN")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "lock.fill").foregroundStyle(.secondary).font(.caption)
                Text("Your key is stored locally in ~/.voicetag/config.json and never uploaded anywhere.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            if vm.selectedBackend == .sarvam {
                Link("Get free Sarvam AI key →", destination: URL(string: "https://dashboard.sarvam.ai")!)
                    .font(.callout)
            } else {
                Link("Get OpenAI API key →", destination: URL(string: "https://platform.openai.com/api-keys")!)
                    .font(.callout)
            }
        }
    }
}

struct OutputFolderStep: View {
    @ObservedObject var vm: SetupViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader("Output Folder", subtitle: "Where should sorted photos be moved?")

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "folder.fill.badge.plus")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(vm.outputFolder.lastPathComponent)
                            .font(.callout.weight(.semibold))
                        Text(vm.outputFolder.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                            .font(.caption).foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Button("Choose...") { vm.pickOutputFolder() }
                        .buttonStyle(.bordered)
                }
                .padding(16)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("How folders are created:").font(.caption.weight(.semibold))
                Text("""
                Say "Mountains Pass Day 2" →
                \(vm.outputFolder.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))/Mountains/Day_2/
                
                Say "family" →
                \(vm.outputFolder.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))/Family/
                """)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct PermissionsStep: View {
    @ObservedObject var vm: SetupViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader("Grant Permissions", subtitle: "VoiceTag needs microphone access to hear your voice tags.")

            VStack(spacing: 10) {
                permissionRow(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "Required — to record your voice tags",
                    status: vm.micPermission,
                    action: { vm.requestMicPermission() },
                    actionLabel: "Grant Access"
                )
                permissionRow(
                    icon: "hand.raised.fill",
                    title: "Accessibility",
                    description: "Optional — for global SPACE key detection",
                    status: vm.accessibilityPermission,
                    action: { vm.openAccessibilitySettings() },
                    actionLabel: "Open Settings"
                )
            }

            Text("If a permission dialog doesn't appear, go to System Settings → Privacy & Security.")
                .font(.caption).foregroundStyle(.tertiary)
        }
    }

    private func permissionRow(icon: String, title: String, description: String, status: PermissionStatus, action: @escaping () -> Void, actionLabel: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(status == .granted ? .green : Color.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(description).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            if status == .granted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
            } else {
                Button(actionLabel, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(
            status == .granted ? Color.green.opacity(0.06) : Color.primary.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 8)
        )
    }
}

struct DoneStep: View {
    @ObservedObject var vm: SetupViewModel
    @Binding var isComplete: Bool

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 8) {
                Text("You're all set! 🎉")
                    .font(.largeTitle.bold())
                Text("VoiceTag is ready to go.\nOpen a photo folder and start sorting with your voice.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 10) {
                quickTip("Hold SPACE to record, release to tag")
                quickTip("Press ← right after tagging to undo")
                quickTip("Tap ✏️ in sidebar to fix a wrong tag")
                quickTip("Shift+Space repeats last tag instantly")
            }
            .padding(16)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            .frame(maxWidth: 360)

            Button(action: {
                vm.saveConfig()
                UserDefaults.standard.set(true, forKey: "setupComplete")
                isComplete = true
            }) {
                Text("Start Tagging")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 40)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
    }

    private func quickTip(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.caption).foregroundStyle(.orange)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Shared helpers
private func stepHeader(_ title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title).font(.title2.bold())
        Text(subtitle).font(.callout).foregroundStyle(.secondary)
    }
}

// MARK: - ViewModel

enum SetupStep: CaseIterable, Hashable {
    case welcome, dependencies, backend, apiKey, outputFolder, permissions, done
}

enum DependencyStatus { case unknown, ok, missing, installing }
enum PermissionStatus { case unknown, granted, denied }

@MainActor
final class SetupViewModel: ObservableObject {

    @Published var currentStep: SetupStep = .welcome
    @Published var completedSteps: Set<SetupStep> = []

    // Dependencies
    @Published var ffmpegStatus: DependencyStatus = .unknown
    @Published var whisperStatus: DependencyStatus = .unknown
    @Published var modelStatus: DependencyStatus = .unknown
    @Published var dependencyLog: [String] = []
    @Published var isWorking = false

    // Backend
    @Published var selectedBackend: AppConfig.WhisperMode = .sarvam

    // API Key
    @Published var apiKey: String = ""
    @Published var sarvamLanguage: String = "en-IN"

    // Output folder
    @Published var outputFolder: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Pictures/VoiceTagged")

    // Permissions
    @Published var micPermission: PermissionStatus = .unknown
    @Published var accessibilityPermission: PermissionStatus = .unknown

    var nextButtonTitle: String {
        switch currentStep {
        case .welcome: return "Get Started"
        case .dependencies: return allDepsOk ? "Continue" : "Check Again"
        case .backend: return "Continue"
        case .apiKey: return apiKey.isEmpty ? "Skip" : "Continue"
        case .outputFolder: return "Continue"
        case .permissions: return "Continue"
        case .done: return "Done"
        }
    }

    var isNextDisabled: Bool {
        isWorking
    }

    var allDepsOk: Bool {
        ffmpegStatus == .ok &&
        (selectedBackend != .local || (whisperStatus == .ok && modelStatus == .ok))
    }

    func goNext() {
        completedSteps.insert(currentStep)
        switch currentStep {
        case .welcome:
            checkDependencies()
            currentStep = .dependencies
        case .dependencies:
            currentStep = .backend
        case .backend:
            currentStep = selectedBackend == .local ? .outputFolder : .apiKey
        case .apiKey:
            currentStep = .outputFolder
        case .outputFolder:
            checkPermissions()
            currentStep = .permissions
        case .permissions:
            currentStep = .done
        case .done:
            break
        }
    }

    func goBack() {
        switch currentStep {
        case .dependencies: currentStep = .welcome
        case .backend: currentStep = .dependencies
        case .apiKey: currentStep = .backend
        case .outputFolder: currentStep = selectedBackend == .local ? .backend : .apiKey
        case .permissions: currentStep = .outputFolder
        case .done: currentStep = .permissions
        default: break
        }
    }

    // MARK: - Dependency checks

    func checkDependencies() {
        ffmpegStatus = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/ffmpeg") ? .ok : .missing
        let whisperBin = "\(NSHomeDirectory())/.voicetag/whisper-cpp"
        whisperStatus = FileManager.default.fileExists(atPath: whisperBin) ? .ok : .missing
        let modelPath = "\(NSHomeDirectory())/.voicetag/models/ggml-base.en.bin"
        modelStatus = FileManager.default.fileExists(atPath: modelPath) ? .ok : .missing
    }

    func installFFmpeg() {
        ffmpegStatus = .installing
        dependencyLog.append("Installing ffmpeg via Homebrew...")
        Task {
            let result = await runCommand("/opt/homebrew/bin/brew", args: ["install", "ffmpeg"])
            ffmpegStatus = result ? .ok : .missing
            dependencyLog.append(result ? "✓ ffmpeg installed" : "✗ Install failed. Run: brew install ffmpeg")
        }
    }

    func buildWhisper() {
        whisperStatus = .installing
        dependencyLog.append("Building whisper.cpp...")
        Task {
            let setupPath = Bundle.main.bundlePath + "/../../../setup.sh"
            let fallback = FileManager.default.currentDirectoryPath + "/setup.sh"
            let script = FileManager.default.fileExists(atPath: setupPath) ? setupPath : fallback
            let result = await runCommand("/bin/bash", args: [script, "--model", "base.en"])
            whisperStatus = result ? .ok : .missing
            modelStatus = result ? .ok : .missing
            dependencyLog.append(result ? "✓ whisper.cpp built and model downloaded" : "✗ Build failed. Run ./setup.sh manually")
        }
    }

    func downloadModel() {
        modelStatus = .installing
        dependencyLog.append("Downloading base.en model (~150MB)...")
        Task {
            let modelsDir = "\(NSHomeDirectory())/.voicetag/models"
            try? FileManager.default.createDirectory(atPath: modelsDir, withIntermediateDirectories: true)
            let modelURL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"
            let dest = "\(modelsDir)/ggml-base.en.bin"
            let result = await runCommand("/usr/bin/curl", args: ["-L", "-o", dest, modelURL])
            modelStatus = result ? .ok : .missing
            dependencyLog.append(result ? "✓ Model downloaded" : "✗ Download failed")
        }
    }

    // MARK: - Output folder

    func pickOutputFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Output Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        if panel.runModal() == .OK, let url = panel.url {
            outputFolder = url
        }
    }

    // MARK: - Permissions

    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: micPermission = .granted
        case .denied, .restricted: micPermission = .denied
        default: micPermission = .unknown
        }
        accessibilityPermission = AXIsProcessTrusted() ? .granted : .unknown
    }

    func requestMicPermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                self.micPermission = granted ? .granted : .denied
            }
        }
    }

    func openAccessibilitySettings() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        AXIsProcessTrustedWithOptions(options)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.accessibilityPermission = AXIsProcessTrusted() ? .granted : .unknown
        }
    }

    // MARK: - Save config

    func saveConfig() {
        let configDir = "\(NSHomeDirectory())/.voicetag"
        let configPath = "\(configDir)/config.json"
        try? FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true)

        var config = AppConfig.default
        config.baseDirectory = outputFolder.path
        config.whisperMode = selectedBackend
        config.sarvamLanguage = sarvamLanguage

        switch selectedBackend {
        case .sarvam: config.sarvamAPIKey = apiKey.isEmpty ? nil : apiKey
        case .api: config.whisperAPIKey = apiKey.isEmpty ? nil : apiKey
        case .local: break
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(config) {
            try? data.write(to: URL(fileURLWithPath: configPath))
        }

        // Create output folder
        try? FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
    }

    // MARK: - Shell helper

    private func runCommand(_ executable: String, args: [String]) async -> Bool {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = args
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            process.terminationHandler = { p in
                continuation.resume(returning: p.terminationStatus == 0)
            }
            do { try process.run() } catch { continuation.resume(returning: false) }
        }
    }
}
