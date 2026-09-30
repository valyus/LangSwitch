import AppKit
import Carbon

struct HotkeyCombo: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt64  // CGEventFlags raw value

    static let defaultCombo = HotkeyCombo(
        keyCode: 0x31, // Space
        modifiers: CGEventFlags.maskAlternate.rawValue | CGEventFlags.maskControl.rawValue | CGEventFlags.maskShift.rawValue
    ) // ⌃⌥⇧ Space

    /// Convert CGEventFlags modifiers to Carbon modifier mask for RegisterEventHotKey.
    var carbonModifiers: UInt32 {
        var mods: UInt32 = 0
        let flags = CGEventFlags(rawValue: modifiers)
        if flags.contains(.maskCommand)   { mods |= UInt32(cmdKey) }
        if flags.contains(.maskShift)     { mods |= UInt32(shiftKey) }
        if flags.contains(.maskAlternate) { mods |= UInt32(optionKey) }
        if flags.contains(.maskControl)   { mods |= UInt32(controlKey) }
        return mods
    }

    var displayString: String {
        var parts: [String] = []
        let flags = CGEventFlags(rawValue: modifiers)
        if flags.contains(.maskControl)   { parts.append("⌃") }
        if flags.contains(.maskAlternate) { parts.append("⌥") }
        if flags.contains(.maskShift)     { parts.append("⇧") }
        if flags.contains(.maskCommand)   { parts.append("⌘") }
        parts.append(HotkeyManager.keyCodeToName(keyCode))
        return parts.joined()
    }
}

class HotkeyManager: NSObject {

    var onHotkeyTriggered: (() -> Void)?
    var onConflict: (() -> Void)?
    var hasConflict: Bool = false

    // Carbon hotkey (primary — no Accessibility permission needed)
    private var carbonHotkeyRef: EventHotKeyRef?
    private var carbonEventHandlerRef: EventHandlerRef?

    // CGEventTap (secondary — requires Accessibility)
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // NSEvent monitor (last resort)
    private var globalMonitor: Any?

    var currentCombo: HotkeyCombo {
        get {
            if let data = UserDefaults.standard.data(forKey: "com.langswitch.hotkey"),
               let combo = try? JSONDecoder().decode(HotkeyCombo.self, from: data) {
                return combo
            }
            return HotkeyCombo.defaultCombo
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "com.langswitch.hotkey")
            }
        }
    }

    func register() {
        unregister()

        let combo = currentCombo

        // ── Primary: Carbon RegisterEventHotKey ─────────────────────────────
        // Works without Accessibility permission; fires before system shortcuts.
        let hotKeyID = EventHotKeyID(signature: 0x4C535748 /* 'LSWH' */, id: 1)
        var hotKeyRef: EventHotKeyRef?
        let regStatus = RegisterEventHotKey(
            UInt32(combo.keyCode),
            combo.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        print("[LangSwitch] RegisterEventHotKey status=\(regStatus) ref=\(String(describing: hotKeyRef))")
        if regStatus == noErr, let ref = hotKeyRef {
            carbonHotkeyRef = ref
            var eventSpec = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind:  UInt32(kEventHotKeyPressed)
            )
            // Plain C callback — no captures allowed, context via userData only.
            let handlerStatus = InstallEventHandler(
                GetApplicationEventTarget(),
                { (_, _, userData) -> OSStatus in
                    print("[LangSwitch] Carbon hotkey fired")
                    guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                    DispatchQueue.main.async { manager.onHotkeyTriggered?() }
                    return noErr
                },
                1,
                &eventSpec,
                Unmanaged.passUnretained(self).toOpaque(),
                &carbonEventHandlerRef
            )
            print("[LangSwitch] InstallEventHandler status=\(handlerStatus)")
            hasConflict = false
            return
        }

        // ── Secondary: CGEventTap (requires Accessibility) ──────────────────
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        if let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleCGEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) {
            eventTap = tap
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            hasConflict = false
            return
        }

        // ── Last resort: NSEvent passive global monitor ──────────────────────
        // Cannot intercept system shortcuts, but works for non-conflicting combos.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            self.handleNSEvent(event)
        }
        hasConflict = false
    }

    func unregister() {
        // Carbon
        if let ref = carbonHotkeyRef {
            UnregisterEventHotKey(ref)
            carbonHotkeyRef = nil
        }
        if let ref = carbonEventHandlerRef {
            RemoveEventHandler(ref)
            carbonEventHandlerRef = nil
        }
        // CGEventTap
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        // NSEvent monitor
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }

    func reregister(with combo: HotkeyCombo) {
        currentCombo = combo
        register()
    }

    // MARK: - Event handling

    private func handleNSEvent(_ event: NSEvent) {
        let keyCode = event.keyCode
        let flags = event.modifierFlags
        let combo = currentCombo

        var cgFlags = CGEventFlags()
        if flags.contains(.command) { cgFlags.insert(.maskCommand) }
        if flags.contains(.option)  { cgFlags.insert(.maskAlternate) }
        if flags.contains(.shift)   { cgFlags.insert(.maskShift) }
        if flags.contains(.control) { cgFlags.insert(.maskControl) }

        let comboFlags = CGEventFlags(rawValue: combo.modifiers)
            .intersection([.maskCommand, .maskAlternate, .maskShift, .maskControl])

        if keyCode == combo.keyCode &&
           cgFlags.intersection([.maskCommand, .maskAlternate, .maskShift, .maskControl]) == comboFlags {
            onHotkeyTriggered?()
        }
    }

    private func handleCGEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else { return Unmanaged.passRetained(event) }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let combo = currentCombo

        let relevantFlags = flags.intersection([.maskCommand, .maskAlternate, .maskShift, .maskControl])
        let comboFlags = CGEventFlags(rawValue: combo.modifiers)
            .intersection([.maskCommand, .maskAlternate, .maskShift, .maskControl])

        if keyCode == combo.keyCode && relevantFlags == comboFlags {
            DispatchQueue.main.async { [weak self] in
                self?.onHotkeyTriggered?()
            }
            return nil // consume
        }
        return Unmanaged.passRetained(event)
    }

    // MARK: - Key name lookup

    static func keyCodeToName(_ keyCode: UInt16) -> String {
        let map: [UInt16: String] = [
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
            0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
            0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E", 0x0F: "R",
            0x10: "Y", 0x11: "T", 0x12: "1", 0x13: "2", 0x14: "3",
            0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=", 0x19: "9",
            0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0", 0x1E: "]",
            0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I", 0x23: "P",
            0x24: "↩", 0x25: "L", 0x26: "J", 0x27: "'", 0x28: "K",
            0x29: ";", 0x2A: "\\", 0x2B: ",", 0x2C: "/", 0x2D: "N",
            0x2E: "M", 0x2F: ".", 0x30: "⇥", 0x31: "Space", 0x32: "`",
            0x33: "⌫", 0x35: "⎋", 0x37: "⌘", 0x38: "⇧", 0x39: "⇪",
            0x3A: "⌥", 0x3B: "⌃", 0x7A: "F1", 0x78: "F2", 0x63: "F3",
            0x76: "F4", 0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8",
            0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
        ]
        return map[keyCode] ?? "0x\(String(keyCode, radix: 16).uppercased())"
    }
}

