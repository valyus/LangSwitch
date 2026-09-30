import AppKit
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {

    var menuBarController: MenuBarController?
    var hotkeyManager: HotkeyManager?
    var textBoundaryTracker: TextBoundaryTracker?
    var onboardingWindowController: OnboardingWindowController?
    var settingsWindowController: SettingsWindowController?

    private var accessibilityWasGranted = false
    private var accessibilityCheckTimer: Timer?
    private var lastAccessibilityAlertDate: Date = .distantPast
    private var pendingUndoEntry: ConversionEntry?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (also set via LSUIElement but belt-and-suspenders)
        NSApp.setActivationPolicy(.accessory)

        // Migrate old default hotkey (⌃⌥ Space) which conflicts with macOS "Select previous
        // input source" shortcut — replace with ⌃⌥⇧ Space which has no system conflict.
        let oldConflicting = HotkeyCombo(
            keyCode: 0x31,
            modifiers: CGEventFlags.maskAlternate.rawValue | CGEventFlags.maskControl.rawValue
        )
        if let data = UserDefaults.standard.data(forKey: "com.langswitch.hotkey"),
           let stored = try? JSONDecoder().decode(HotkeyCombo.self, from: data),
           stored == oldConflicting {
            UserDefaults.standard.removeObject(forKey: "com.langswitch.hotkey")
        }

        // First run check
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "com.langswitch.hasLaunchedBefore")
        if !hasLaunchedBefore {
            showOnboarding()
        }

        setupComponents()

        // Track current state so we can detect transitions.
        accessibilityWasGranted = AXIsProcessTrusted()

        // React when the user toggles the Accessibility switch.
        // macOS posts "com.apple.accessibility.api" the moment the toggle changes.
        // We add a 0.5s delay before querying AXIsProcessTrusted() because the
        // notification fires slightly before the OS updates the trust state — querying
        // immediately returns the old value.
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                let granted = AXIsProcessTrusted()
                if granted && !self.accessibilityWasGranted {
                    // Permission just granted — upgrade from NSEvent fallback to CGEventTap.
                    self.accessibilityWasGranted = true
                    self.hotkeyManager?.register()
                    self.textBoundaryTracker?.stop()
                    self.textBoundaryTracker?.start()
                    self.menuBarController?.updateDisplay()
                }
                self.accessibilityWasGranted = granted
            }
        }

        // 2-second polling timer as backup for environments where the
        // distributed notification is delayed or not delivered.
        accessibilityCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let granted = AXIsProcessTrusted()
            if granted && !self.accessibilityWasGranted {
                self.accessibilityWasGranted = true
                self.hotkeyManager?.register()
                self.textBoundaryTracker?.stop()
                self.textBoundaryTracker?.start()
                self.menuBarController?.updateDisplay()
            } else {
                self.accessibilityWasGranted = granted
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        accessibilityCheckTimer?.invalidate()
        hotkeyManager?.unregister()
    }

    private func setupComponents() {
        textBoundaryTracker = TextBoundaryTracker()
        textBoundaryTracker?.onBoundaryReset = { [weak self] in
            self?.pendingUndoEntry = nil
        }
        textBoundaryTracker?.start()

        hotkeyManager = HotkeyManager()
        hotkeyManager?.onHotkeyTriggered = { [weak self] in
            guard let self = self else { return }
            let capturedCount = self.textBoundaryTracker?.boundaryOffset ?? 0
            self.convertAndReplace(capturedCount: capturedCount)
        }
        hotkeyManager?.onConflict = { [weak self] in
            self?.showHotkeyConflictAlert()
        }
        hotkeyManager?.register()

        menuBarController = MenuBarController()
        menuBarController?.onSettingsRequested = { [weak self] in
            self?.showSettings()
        }
        menuBarController?.onQuitRequested = {
            NSApp.terminate(nil)
        }
        menuBarController?.onTestRequested = { [weak self] in
            guard let self = self else { return }
            let capturedCount = self.textBoundaryTracker?.boundaryOffset ?? 0
            print("[LangSwitch] Manual test triggered, count=\(capturedCount)")
            self.convertAndReplace(capturedCount: max(capturedCount, 1))
        }
        menuBarController?.setup()
    }

    func requestAccessibilityIfNeeded() {
        if !TextAccessibilityHelper.isAccessibilityPermitted() {
            TextAccessibilityHelper.requestAccessibilityPermissions()
        }
    }

    // MARK: - Core Conversion

    func convertAndReplace(capturedCount: Int) {
        // If the last action was a conversion, pressing the shortcut again undoes it.
        if let entry = pendingUndoEntry {
            pendingUndoEntry = nil
            undoLastConversion(entry: entry)
            return
        }

        // Use 30 as a sensible default when tracking hasn't counted anything.
        let effectiveCount = capturedCount > 0 ? capturedCount : 30

        // Check if app should be excluded
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let excludedBundleIDs = UserDefaults.standard.stringArray(forKey: "com.langswitch.excludedBundleIDs") ?? []
            if let bundleID = frontApp.bundleIdentifier, excludedBundleIDs.contains(bundleID) {
                return
            }
        }

        performConversion(charCount: effectiveCount)
    }

    func performConversion(charCount: Int) {
        let langManager = LanguageManager.shared
        let pair = langManager.selectedPair
        // Use the ACTUAL active input source — currentLang is stale when the user
        // switches layouts manually outside of LangSwitch.
        let sourceLayout = langManager.actualCurrentLayout()
        let targetLayout = sourceLayout == pair.langA ? pair.langB : pair.langA
        print("[LangSwitch] performConversion: charCount=\(charCount) source=\(sourceLayout) target=\(targetLayout)")

        menuBarController?.flash("…")

        // Try accessibility first
        if TextAccessibilityHelper.isAccessibilityPermitted() {
            if let result = TextAccessibilityHelper.getTextFromBoundary(charCount: charCount) {
                print("[LangSwitch] AX read: '\(result.text)'")
                let converted = TextConverter.shared.convert(result.text, from: sourceLayout, to: targetLayout)
                print("[LangSwitch] AX converted: '\(converted)'")
                if converted != result.text {
                    if TextAccessibilityHelper.replaceText(range: result.range, with: converted) {
                        ConversionHistory.shared.add(original: result.text, converted: converted, langPair: pair)
                        // Suppress onBoundaryReset so it doesn't clear the undo entry we're about to set.
                        let savedReset = textBoundaryTracker?.onBoundaryReset
                        textBoundaryTracker?.onBoundaryReset = nil
                        textBoundaryTracker?.resetBoundary()
                        textBoundaryTracker?.onBoundaryReset = savedReset
                        pendingUndoEntry = ConversionEntry(originalText: result.text, convertedText: converted, langPair: pair)
                        langManager.toggleLanguage()
                        menuBarController?.flash("✓")
                        menuBarController?.updateDisplay()
                        return
                    }
                }
            }
        }

        // Fallback: clipboard-based replacement
        clipboardFallback(charCount: charCount, sourceLayout: sourceLayout, targetLayout: targetLayout, pair: pair)
    }

    private func clipboardFallback(charCount: Int, sourceLayout: String, targetLayout: String, pair: LanguagePair) {
        let langManager = LanguageManager.shared
        let src = CGEventSource(stateID: .hidSystemState)
        // Capture the target PID *before* any async work — the frontmost app may change by then.
        let targetPid = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? pid_t(-1)

        func postKey(_ vk: CGKeyCode, flags: CGEventFlags) {
            guard let down = CGEvent(keyboardEventSource: src, virtualKey: vk, keyDown: true),
                  let up   = CGEvent(keyboardEventSource: src, virtualKey: vk, keyDown: false) else { return }
            down.flags = flags
            up.flags   = flags
            if targetPid > 0 {
                down.postToPid(targetPid)
                up.postToPid(targetPid)
            } else {
                down.post(tap: .cghidEventTap)
                up.post(tap: .cghidEventTap)
            }
        }

        let pb = NSPasteboard.general
        let savedClipboard = pb.string(forType: .string)
        let changeCountBefore = pb.changeCount

        // Step 1: Post Shift+Left × N to select the last N characters.
        let selectCount = min(charCount, 300)
        for _ in 0..<selectCount {
            postKey(0x7B, flags: .maskShift) // Shift+Left
        }

        // Step 2: Give the target app time to process the selection events before
        // posting Cmd+C. Without this delay the app may not have moved the selection
        // yet when the copy command arrives, so the clipboard stays unchanged.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            postKey(0x08, flags: .maskCommand) // Cmd+C
        }

        // Step 3: After another delay, read the clipboard and convert.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
            guard let self = self else { return }

            guard NSPasteboard.general.changeCount != changeCountBefore else {
                print("[LangSwitch] clipboardFallback: clipboard unchanged after Cmd+C")
                postKey(0x7C, flags: [])
                self.menuBarController?.flash("✗")
                return
            }

            let copied = NSPasteboard.general.string(forType: .string) ?? ""
            guard !copied.isEmpty else {
                postKey(0x7C, flags: [])
                self.menuBarController?.flash("✗")
                return
            }
            print("[LangSwitch] clipboardFallback: copied='\(copied)'")

            let converted = TextConverter.shared.convert(copied, from: sourceLayout, to: targetLayout)
            print("[LangSwitch] clipboardFallback: converted='\(converted)'")
            guard converted != copied else {
                postKey(0x7C, flags: [])
                self.menuBarController?.flash("✗")
                return
            }

            // Text is still selected from Shift+Left above — paste replaces selection
            pb.clearContents()
            pb.setString(converted, forType: .string)
            postKey(0x09, flags: .maskCommand) // Cmd+V

            // Restore original clipboard after paste completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                pb.clearContents()
                if let s = savedClipboard { pb.setString(s, forType: .string) }
            }

            ConversionHistory.shared.add(original: copied, converted: converted, langPair: pair)
            // Suppress onBoundaryReset so it doesn't clear the undo entry we're about to set.
            let savedReset = self.textBoundaryTracker?.onBoundaryReset
            self.textBoundaryTracker?.onBoundaryReset = nil
            self.textBoundaryTracker?.resetBoundary()
            self.textBoundaryTracker?.onBoundaryReset = savedReset
            self.pendingUndoEntry = ConversionEntry(originalText: copied, convertedText: converted, langPair: pair)
            langManager.toggleLanguage()
            self.menuBarController?.flash("✓")
            self.menuBarController?.updateDisplay()
        }
    }

    // MARK: - Undo Last Conversion

    private func undoLastConversion(entry: ConversionEntry) {
        let langManager = LanguageManager.shared
        menuBarController?.flash("…")

        // Try accessibility path first
        if TextAccessibilityHelper.isAccessibilityPermitted(),
           let result = TextAccessibilityHelper.getTextFromBoundary(charCount: entry.convertedText.count),
           result.text == entry.convertedText {
            if TextAccessibilityHelper.replaceText(range: result.range, with: entry.originalText) {
                langManager.toggleLanguage()
                textBoundaryTracker?.resetBoundary()
                menuBarController?.flash("↺")
                menuBarController?.updateDisplay()
                return
            }
        }

        // Clipboard fallback
        let src = CGEventSource(stateID: .hidSystemState)
        let targetPid = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? pid_t(-1)

        func postKey(_ vk: CGKeyCode, flags: CGEventFlags) {
            guard let down = CGEvent(keyboardEventSource: src, virtualKey: vk, keyDown: true),
                  let up   = CGEvent(keyboardEventSource: src, virtualKey: vk, keyDown: false) else { return }
            down.flags = flags; up.flags = flags
            if targetPid > 0 { down.postToPid(targetPid); up.postToPid(targetPid) }
            else { down.post(tap: .cghidEventTap); up.post(tap: .cghidEventTap) }
        }

        let pb = NSPasteboard.general
        let savedClipboard = pb.string(forType: .string)
        let selectCount = min(entry.convertedText.count, 300)

        for _ in 0..<selectCount {
            postKey(0x7B, flags: .maskShift) // Shift+Left to select
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self else { return }
            pb.clearContents()
            pb.setString(entry.originalText, forType: .string)
            postKey(0x09, flags: .maskCommand) // Cmd+V

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                pb.clearContents()
                if let s = savedClipboard { pb.setString(s, forType: .string) }
            }

            langManager.toggleLanguage()
            self.textBoundaryTracker?.resetBoundary()
            self.menuBarController?.flash("↺")
            self.menuBarController?.updateDisplay()
        }
    }

    // MARK: - Window Management

    func showOnboarding() {
        onboardingWindowController = OnboardingWindowController()
        onboardingWindowController?.onCompleted = { [weak self] in
            UserDefaults.standard.set(true, forKey: "com.langswitch.hasLaunchedBefore")
            self?.requestAccessibilityIfNeeded()
            self?.onboardingWindowController = nil
        }
        onboardingWindowController?.showWindow(nil)
        onboardingWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
            settingsWindowController?.onClosed = { [weak self] in
                self?.settingsWindowController = nil
            }
        }
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showAccessibilityRequiredAlert() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = """
                LangSwitch needs Accessibility access to read and replace text.

                Steps to fix right now:
                1. Click "Open Settings" — enable LangSwitch in the Accessibility list
                2. Come back and click "Restart App" — macOS only applies the grant after a full restart

                Permanent fix (recommended):
                In Xcode → LangSwitch target → Signing & Capabilities, set a Team \
                (your Apple ID). This gives the app a stable code signature so you \
                only need to grant permission once, not after every rebuild.
                """
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Open Settings")   // .alertFirstButtonReturn
            alert.addButton(withTitle: "Restart App")     // .alertSecondButtonReturn
            alert.addButton(withTitle: "Dismiss")         // .alertThirdButtonReturn
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                TextAccessibilityHelper.requestAccessibilityPermissions()
            } else if response == .alertSecondButtonReturn {
                self.relaunchApp()
            }
        }
    }

    /// Quit and immediately reopen this app so a freshly granted Accessibility
    /// permission takes effect (macOS requires a full restart for the grant to apply).
    private func relaunchApp() {
        let bundleURL = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = false
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: config) { _, _ in }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.terminate(nil)
        }
    }

    private func showHotkeyConflictAlert() {
        DispatchQueue.main.async {
            let combo = self.hotkeyManager?.currentCombo.displayString ?? "the hotkey"
            let alert = NSAlert()
            alert.messageText = "Hotkey Conflict"
            alert.informativeText = "\(combo) is already registered by another application. Please choose a different shortcut in Settings."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "OK")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.showSettings()
            }
        }
    }
}
