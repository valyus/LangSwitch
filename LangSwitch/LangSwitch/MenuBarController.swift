import AppKit
import Carbon

class MenuBarController: NSObject {

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?

    var onSettingsRequested: (() -> Void)?
    var onQuitRequested: (() -> Void)?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateDisplay()
        buildMenu()

        // Observe LangSwitch-triggered language changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageChanged),
            name: .languageDidChange,
            object: nil
        )
        // Also observe TIS changes so display updates when user switches layouts manually
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(languageChanged),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil
        )
    }

    func updateDisplay() {
        let langManager = LanguageManager.shared
        let button = statusItem?.button

        let code = langManager.currentCode()
        button?.title = code
        button?.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        button?.toolTip = "LangSwitch - \(langManager.currentFlag())"
        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()
        let langManager = LanguageManager.shared
        let pair = langManager.selectedPair
        // Use the actual TIS source, not stale currentLang
        let actualLayout = langManager.actualCurrentLayout()
        let isLangA = actualLayout == pair.langA

        // Title
        let titleItem = NSMenuItem(title: "LangSwitch", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        // Current language
        let currentFlag = isLangA ? pair.flagA : pair.flagB
        let currentName = isLangA ? pair.nameA : pair.nameB
        let currentItem = NSMenuItem(title: "\(currentFlag) \(currentName) (active)", action: nil, keyEquivalent: "")
        currentItem.isEnabled = false
        menu.addItem(currentItem)

        // Switch to other
        let otherFlag = isLangA ? pair.flagB : pair.flagA
        let otherName = isLangA ? pair.nameB : pair.nameA
        let switchItem = NSMenuItem(
            title: "Switch to \(otherFlag) \(otherName)",
            action: #selector(switchLanguage),
            keyEquivalent: ""
        )
        switchItem.target = self
        menu.addItem(switchItem)

        menu.addItem(NSMenuItem.separator())

        // Last conversions
        let history = ConversionHistory.shared.entries
        if !history.isEmpty {
            let historyTitle = NSMenuItem(title: "Recent Conversions:", action: nil, keyEquivalent: "")
            historyTitle.isEnabled = false
            menu.addItem(historyTitle)

            let recentEntries = history.prefix(5)
            for (index, entry) in recentEntries.enumerated() {
                let truncated = entry.convertedText.count > 30
                    ? String(entry.convertedText.prefix(30)) + "..."
                    : entry.convertedText
                let item = NSMenuItem(
                    title: "  \"\(truncated)\"",
                    action: #selector(undoConversion(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.tag = index
                menu.addItem(item)
            }

            menu.addItem(NSMenuItem.separator())
        }

        // Test trigger
        let testItem = NSMenuItem(title: "Test Conversion (manual)", action: #selector(testTrigger), keyEquivalent: "")
        testItem.target = self
        menu.addItem(testItem)

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit LangSwitch", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.menu = menu
        statusItem?.menu = menu
    }

    /// Briefly flash the menu bar icon to indicate the hotkey was detected but no text boundary was found.
    func flashNoText() {
        flash("∅")
    }

    /// Briefly show a message in the menu bar status icon, then restore the original title.
    func flash(_ text: String, duration: TimeInterval = 0.7) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let button = self.statusItem?.button
            let original = button?.title ?? ""
            button?.title = text
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                guard let self = self else { return }
                // Only restore if it hasn't been changed again
                if self.statusItem?.button?.title == text {
                    button?.title = original
                }
            }
        }
    }

    @objc private func languageChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.updateDisplay()
        }
    }

    @objc private func switchLanguage() {
        LanguageManager.shared.toggleLanguage()
        updateDisplay()
    }

    @objc private func undoConversion(_ sender: NSMenuItem) {
        let index = sender.tag
        let history = ConversionHistory.shared.entries
        guard index < history.count else { return }
        let entry = history[index]
        ConversionHistory.shared.undo(entry: entry)
    }

    var onTestRequested: (() -> Void)?

    @objc private func testTrigger() {
        onTestRequested?()
    }

    @objc private func openSettings() {
        onSettingsRequested?()
    }

    @objc private func quit() {
        onQuitRequested?()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }
}

extension Notification.Name {
    static let languageDidChange = Notification.Name("com.langswitch.languageDidChange")
}
