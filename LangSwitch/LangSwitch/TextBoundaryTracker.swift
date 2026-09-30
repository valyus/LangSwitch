import AppKit
import Carbon

class TextBoundaryTracker: NSObject {

    private(set) var boundaryOffset: Int = 0
    private let maxChars = 2000

    /// Called whenever the boundary is reset (cursor move, app switch, delete, etc.).
    /// Not called when `resetBoundary()` is invoked by the conversion itself.
    var onBoundaryReset: (() -> Void)?

    private var keystrokeEventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var keystrokeMonitor: Any?

    func start() {
        setupInputSourceNotification()
        setupWorkspaceNotifications()
        setupKeystrokeObserver()
    }

    func stop() {
        if let tap = keystrokeEventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        keystrokeEventTap = nil
        runLoopSource = nil
        if let monitor = keystrokeMonitor {
            NSEvent.removeMonitor(monitor)
            keystrokeMonitor = nil
        }
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }

    func resetBoundary() {
        boundaryOffset = 0
        onBoundaryReset?()
    }

    // MARK: - Input Source Notification

    private func setupInputSourceNotification() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourceChanged),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil
        )
    }

    @objc private func inputSourceChanged() {
        resetBoundary()
    }

    // MARK: - Workspace Notifications

    private func setupWorkspaceNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appActivated),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDeactivated),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
    }

    @objc private func appActivated(_ notification: Notification) {
        resetBoundary()
    }

    @objc private func appDeactivated(_ notification: Notification) {
        resetBoundary()
    }

    // MARK: - Keystroke Observer (passive)

    private func setupKeystrokeObserver() {
        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue)

        // Try CGEventTap first (requires Accessibility)
        if let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let tracker = Unmanaged<TextBoundaryTracker>.fromOpaque(refcon).takeUnretainedValue()
                tracker.handlePassiveEvent(type: type, event: event)
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) {
            keystrokeEventTap = tap
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            return
        }

        // Fallback: NSEvent global monitor — works without Accessibility
        keystrokeMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return }
            self.handleNSKeyEvent(event)
        }
    }

    private func handlePassiveEvent(type: CGEventType, event: CGEvent) {
        switch type {
        case .keyDown:
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags

            // Arrow keys or modifier-heavy combos → reset boundary
            let arrowKeys: Set<UInt16> = [0x7B, 0x7C, 0x7D, 0x7E] // left, right, down, up
            let isArrow = arrowKeys.contains(keyCode)

            // Delete / backspace → reset
            let deleteKeys: Set<UInt16> = [0x33, 0x75] // backspace, forward delete
            let isDelete = deleteKeys.contains(keyCode)

            // Home/End/PgUp/PgDown → reset
            let navigationKeys: Set<UInt16> = [0x73, 0x77, 0x74, 0x79] // home, end, pgup, pgdn
            let isNavigation = navigationKeys.contains(keyCode)

            // Escape → reset
            let isEscape = (keyCode == 0x35)

            // Return/Enter → reset
            let isReturn = (keyCode == 0x24 || keyCode == 0x4C)

            // Command combos (paste, cut, etc.) → reset
            let hasCommand = flags.contains(.maskCommand)

            if isArrow || isDelete || isNavigation || isEscape || isReturn || hasCommand {
                DispatchQueue.main.async { [weak self] in
                    self?.resetBoundary()
                }
                return
            }

            // Regular typing - increment counter
            // Check it's a printable character (not a function key, not a pure modifier)
            let functionKeys: Set<UInt16> = [
                0x7A, 0x78, 0x63, 0x76, 0x60, 0x61, 0x62, 0x64,
                0x65, 0x6D, 0x67, 0x6F, 0x69, 0x6B, 0x71
            ]
            let modifierKeys: Set<UInt16> = [0x37, 0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F]
            let isSpecial = functionKeys.contains(keyCode) || modifierKeys.contains(keyCode)

            if !isSpecial && !flags.contains(.maskCommand) && !flags.contains(.maskControl) {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if self.boundaryOffset < self.maxChars {
                        self.boundaryOffset += 1
                    } else {
                        self.resetBoundary()
                    }
                }
            }

        case .leftMouseDown, .rightMouseDown:
            DispatchQueue.main.async { [weak self] in
                self?.resetBoundary()
            }

        default:
            break
        }
    }

    private func handleNSKeyEvent(_ event: NSEvent) {
        switch event.type {
        case .keyDown:
            let keyCode = event.keyCode
            let flags = event.modifierFlags

            let arrowKeys: Set<UInt16> = [0x7B, 0x7C, 0x7D, 0x7E]
            let deleteKeys: Set<UInt16> = [0x33, 0x75]
            let navigationKeys: Set<UInt16> = [0x73, 0x77, 0x74, 0x79]

            if arrowKeys.contains(keyCode) || deleteKeys.contains(keyCode) ||
               navigationKeys.contains(keyCode) || keyCode == 0x35 ||
               keyCode == 0x24 || keyCode == 0x4C ||
               flags.contains(.command) {
                resetBoundary()
                return
            }

            let functionKeys: Set<UInt16> = [0x7A,0x78,0x63,0x76,0x60,0x61,0x62,0x64,0x65,0x6D,0x67,0x6F,0x69,0x6B,0x71]
            let modifierKeys: Set<UInt16> = [0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E,0x3F]

            if !functionKeys.contains(keyCode) && !modifierKeys.contains(keyCode) &&
               !flags.contains(.command) && !flags.contains(.control) {
                if boundaryOffset < maxChars { boundaryOffset += 1 } else { resetBoundary() }
            }

        case .leftMouseDown, .rightMouseDown:
            resetBoundary()

        default:
            break
        }
    }

    deinit {
        stop()
    }
}
