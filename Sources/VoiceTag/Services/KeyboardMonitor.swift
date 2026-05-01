import AppKit
import Carbon

final class KeyboardMonitor {

    var onSpaceDown: (() -> Void)?
    var onSpaceUp: (() -> Void)?
    var onShiftSpaceDown: (() -> Void)?  // repeat last tag

    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var spaceIsDown = false

    func start() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self = self else { return event }
            if event.keyCode == UInt16(kVK_Space) {
                self.handleSpaceEvent(event)
                return nil
            }
            return event
        }

        if AXIsProcessTrusted() {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
                guard let self = self else { return }
                if event.keyCode == UInt16(kVK_Space) { self.handleSpaceEvent(event) }
            }
        } else {
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
            AXIsProcessTrustedWithOptions(options)
        }
    }

    func stop() {
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        localMonitor = nil
        globalMonitor = nil
    }

    private func handleSpaceEvent(_ event: NSEvent) {
        let shiftHeld = event.modifierFlags.contains(.shift)

        if event.type == .keyDown && !event.isARepeat && !spaceIsDown {
            spaceIsDown = true
            DispatchQueue.main.async {
                if shiftHeld {
                    self.onShiftSpaceDown?()
                } else {
                    self.onSpaceDown?()
                }
            }
        } else if event.type == .keyUp && spaceIsDown {
            spaceIsDown = false
            // Only trigger stopRecording for regular space (not shift+space)
            if !shiftHeld {
                DispatchQueue.main.async { self.onSpaceUp?() }
            }
        }
    }

    deinit { stop() }
}
