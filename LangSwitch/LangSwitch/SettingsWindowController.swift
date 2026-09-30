import AppKit
import ServiceManagement

class SettingsWindowController: NSWindowController {

    var onClosed: (() -> Void)?

    private var tabView: NSTabView!
    private var accessibilityPollTimer: Timer?

    // General tab
    private var loginItemToggle: NSButton!
    private var notificationsToggle: NSButton!
    private var accessibilityStatusLabel: NSTextField!

    // Languages tab
    private var langTableView: NSTableView!

    // Shortcuts tab
    private var hotkeyRecorder: HotkeyRecorderField!

    // Exclusions tab
    private var exclusionsTableView: NSTableView!
    private var exclusionsList: [String] = []

    // History tab section
    private var historyTableView: NSTableView!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "LangSwitch Settings"
        window.center()
        self.init(window: window)
        setupUI()
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        window?.delegate = self

        // Update status when user flips the Accessibility toggle.
        // Use a wrapper that adds a 0.5s delay — the notification fires before the OS
        // updates the trust state, so querying AXIsProcessTrusted() immediately returns
        // the old value.
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.refreshAccessibilityStatus()
            }
        }

        // 2-second polling timer as a backup.
        accessibilityPollTimer = Timer.scheduledTimer(
            timeInterval: 2.0,
            target: self,
            selector: #selector(refreshAccessibilityStatus),
            userInfo: nil,
            repeats: true
        )
    }

    @objc func refreshAccessibilityStatus() {
        let granted = TextAccessibilityHelper.isAccessibilityPermitted()
        print("[LangSwitch] AXIsProcessTrusted = \(granted), pid = \(ProcessInfo.processInfo.processIdentifier), path = \(Bundle.main.bundleURL.path)")
        if granted {
            accessibilityStatusLabel?.stringValue = "✅ Granted — direct text replacement"
            accessibilityStatusLabel?.textColor = .systemGreen
        } else {
            accessibilityStatusLabel?.stringValue = "⚠️ Not granted — clipboard method used (works)"
            accessibilityStatusLabel?.textColor = .systemOrange
        }
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tabView)

        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            tabView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])

        tabView.addTabViewItem(makeGeneralTab())
        tabView.addTabViewItem(makeLanguagesTab())
        tabView.addTabViewItem(makeShortcutsTab())
        tabView.addTabViewItem(makeExclusionsTab())
    }

    // MARK: - General Tab

    private func makeGeneralTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "general")
        item.label = "General"

        let view = NSView()
        item.view = view

        loginItemToggle = NSButton(checkboxWithTitle: "Start at Login", target: self, action: #selector(toggleLoginItem))
        loginItemToggle.translatesAutoresizingMaskIntoConstraints = false
        loginItemToggle.state = isLoginItemEnabled() ? .on : .off

        notificationsToggle = NSButton(checkboxWithTitle: "Show notifications after conversion", target: self, action: #selector(toggleNotifications))
        notificationsToggle.translatesAutoresizingMaskIntoConstraints = false
        notificationsToggle.state = UserDefaults.standard.bool(forKey: "com.langswitch.showNotifications") ? .on : .off

        let accessibilityLabel = NSTextField(labelWithString: "Accessibility Permission:")
        accessibilityLabel.translatesAutoresizingMaskIntoConstraints = false
        accessibilityLabel.font = NSFont.systemFont(ofSize: 13)

        accessibilityStatusLabel = NSTextField(labelWithString: "")
        accessibilityStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        refreshAccessibilityStatus()

        let openSettingsButton = NSButton(title: "Open System Settings", target: self, action: #selector(openAccessibilitySettings))
        openSettingsButton.translatesAutoresizingMaskIntoConstraints = false
        openSettingsButton.bezelStyle = .rounded

        let restartButton = NSButton(title: "Restart LangSwitch", target: self, action: #selector(restartApp))
        restartButton.translatesAutoresizingMaskIntoConstraints = false
        restartButton.bezelStyle = .rounded

        let restartHint = NSTextField(labelWithString: "Required after granting permission")
        restartHint.translatesAutoresizingMaskIntoConstraints = false
        restartHint.font = NSFont.systemFont(ofSize: 11)
        restartHint.textColor = .secondaryLabelColor

        view.addSubview(loginItemToggle)
        view.addSubview(notificationsToggle)
        view.addSubview(accessibilityLabel)
        view.addSubview(accessibilityStatusLabel)
        view.addSubview(openSettingsButton)
        view.addSubview(restartButton)
        view.addSubview(restartHint)

        NSLayoutConstraint.activate([
            loginItemToggle.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            loginItemToggle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            notificationsToggle.topAnchor.constraint(equalTo: loginItemToggle.bottomAnchor, constant: 12),
            notificationsToggle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            accessibilityLabel.topAnchor.constraint(equalTo: notificationsToggle.bottomAnchor, constant: 24),
            accessibilityLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            accessibilityStatusLabel.centerYAnchor.constraint(equalTo: accessibilityLabel.centerYAnchor),
            accessibilityStatusLabel.leadingAnchor.constraint(equalTo: accessibilityLabel.trailingAnchor, constant: 8),

            openSettingsButton.topAnchor.constraint(equalTo: accessibilityLabel.bottomAnchor, constant: 12),
            openSettingsButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            restartButton.centerYAnchor.constraint(equalTo: openSettingsButton.centerYAnchor),
            restartButton.leadingAnchor.constraint(equalTo: openSettingsButton.trailingAnchor, constant: 8),

            restartHint.topAnchor.constraint(equalTo: openSettingsButton.bottomAnchor, constant: 4),
            restartHint.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
        ])

        return item
    }

    // MARK: - Languages Tab

    private func makeLanguagesTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "languages")
        item.label = "Languages"

        let view = NSView()
        item.view = view

        let label = NSTextField(labelWithString: "Active language pair:")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 13)
        view.addSubview(label)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        view.addSubview(scrollView)

        let tableView = NSTableView()
        tableView.headerView = nil
        tableView.rowHeight = 36
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tag = 1 // Languages table

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("lang"))
        col.title = "Language Pair"
        col.minWidth = 200
        tableView.addTableColumn(col)
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.usesAlternatingRowBackgroundColors = true

        scrollView.documentView = tableView
        langTableView = tableView

        tableView.reloadData()

        // Select current
        let langManager = LanguageManager.shared
        if let idx = langManager.availablePairs.firstIndex(of: langManager.selectedPair) {
            tableView.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
        }

        let applyButton = NSButton(title: "Apply", target: self, action: #selector(applyLanguagePair))
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        applyButton.bezelStyle = .rounded
        view.addSubview(applyButton)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            scrollView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.heightAnchor.constraint(equalToConstant: 160),

            applyButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 12),
            applyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])

        return item
    }

    // MARK: - Shortcuts Tab

    private func makeShortcutsTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "shortcuts")
        item.label = "Shortcuts"

        let view = NSView()
        item.view = view

        let label = NSTextField(labelWithString: "Convert & switch language:")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 13)
        view.addSubview(label)

        let recorder = HotkeyRecorderField()
        recorder.translatesAutoresizingMaskIntoConstraints = false
        recorder.combo = HotkeyManager().currentCombo
        view.addSubview(recorder)
        hotkeyRecorder = recorder

        let hintLabel = NSTextField(labelWithString: "Click the field and press your desired key combination to change it.")
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.font = NSFont.systemFont(ofSize: 11)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.maximumNumberOfLines = 2
        view.addSubview(hintLabel)

        let applyButton = NSButton(title: "Apply Shortcut", target: self, action: #selector(applyHotkey))
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        applyButton.bezelStyle = .rounded
        view.addSubview(applyButton)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            recorder.centerYAnchor.constraint(equalTo: label.centerYAnchor),
            recorder.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 12),
            recorder.widthAnchor.constraint(equalToConstant: 180),
            recorder.heightAnchor.constraint(equalToConstant: 28),

            hintLabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            hintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            applyButton.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 16),
            applyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
        ])

        return item
    }

    // MARK: - Exclusions Tab

    private func makeExclusionsTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "exclusions")
        item.label = "Exclusions"

        let view = NSView()
        item.view = view

        exclusionsList = UserDefaults.standard.stringArray(forKey: "com.langswitch.excludedBundleIDs") ?? []

        let label = NSTextField(labelWithString: "Excluded apps (bundle IDs):")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 13)
        view.addSubview(label)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        view.addSubview(scrollView)

        let tableView = NSTableView()
        tableView.headerView = nil
        tableView.rowHeight = 24
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tag = 2 // Exclusions table

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("bundleID"))
        col.title = "Bundle ID"
        tableView.addTableColumn(col)

        scrollView.documentView = tableView
        exclusionsTableView = tableView

        let addButton = NSButton(title: "+ Add", target: self, action: #selector(addExclusion))
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.bezelStyle = .rounded

        let removeButton = NSButton(title: "Remove", target: self, action: #selector(removeExclusion))
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.bezelStyle = .rounded

        view.addSubview(addButton)
        view.addSubview(removeButton)

        // History section
        let historyLabel = NSTextField(labelWithString: "Conversion History:")
        historyLabel.translatesAutoresizingMaskIntoConstraints = false
        historyLabel.font = NSFont.systemFont(ofSize: 13)
        view.addSubview(historyLabel)

        let clearButton = NSButton(title: "Clear History", target: self, action: #selector(clearHistory))
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.bezelStyle = .rounded
        view.addSubview(clearButton)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            scrollView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.heightAnchor.constraint(equalToConstant: 100),

            addButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 8),
            addButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            removeButton.centerYAnchor.constraint(equalTo: addButton.centerYAnchor),
            removeButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 8),

            historyLabel.topAnchor.constraint(equalTo: addButton.bottomAnchor, constant: 20),
            historyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            clearButton.centerYAnchor.constraint(equalTo: historyLabel.centerYAnchor),
            clearButton.leadingAnchor.constraint(equalTo: historyLabel.trailingAnchor, constant: 12),
        ])

        return item
    }

    // MARK: - Actions

    @objc private func toggleLoginItem(_ sender: NSButton) {
        let enable = sender.state == .on
        setLoginItemEnabled(enable)
    }

    @objc private func toggleNotifications(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "com.langswitch.showNotifications")
    }

    @objc private func openAccessibilitySettings() {
        TextAccessibilityHelper.requestAccessibilityPermissions()
    }

    @objc private func restartApp() {
        let path = Bundle.main.bundleURL.path
        // Launch a detached shell that waits 1 s then reopens the app.
        // The shell process outlives this process, so the open command
        // runs even after NSApp.terminate() kills us.
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "sleep 1 && open '\(path)'"]
        try? task.run()
        NSApp.terminate(nil)
    }

    @objc private func applyLanguagePair() {
        let row = langTableView.selectedRow
        guard row >= 0 else { return }
        LanguageManager.shared.selectedPair = LanguageManager.shared.availablePairs[row]
    }

    @objc private func applyHotkey() {
        let combo = hotkeyRecorder.combo
        // Find the app delegate's hotkey manager and re-register
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.hotkeyManager?.reregister(with: combo)
        }
    }

    @objc private func addExclusion() {
        let alert = NSAlert()
        alert.messageText = "Add App Exclusion"
        alert.informativeText = "Enter the bundle ID of the app to exclude (e.g. com.apple.Terminal):"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        input.placeholderString = "com.example.App"
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {
            let bundleID = input.stringValue.trimmingCharacters(in: .whitespaces)
            if !bundleID.isEmpty && !exclusionsList.contains(bundleID) {
                exclusionsList.append(bundleID)
                UserDefaults.standard.set(exclusionsList, forKey: "com.langswitch.excludedBundleIDs")
                exclusionsTableView.reloadData()
            }
        }
    }

    @objc private func removeExclusion() {
        let row = exclusionsTableView.selectedRow
        guard row >= 0 else { return }
        exclusionsList.remove(at: row)
        UserDefaults.standard.set(exclusionsList, forKey: "com.langswitch.excludedBundleIDs")
        exclusionsTableView.reloadData()
    }

    @objc private func clearHistory() {
        ConversionHistory.shared.clear()
    }

    // MARK: - Login Item

    private func isLoginItemEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    private func setLoginItemEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to set login item: \(error)")
            }
        }
    }

}

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = nil
        DistributedNotificationCenter.default().removeObserver(self)
        onClosed?()
    }
}

extension SettingsWindowController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        switch tableView.tag {
        case 1: return LanguageManager.shared.availablePairs.count
        case 2: return exclusionsList.count
        default: return 0
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("cell")
        var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView

        if cell == nil {
            cell = NSTableCellView(frame: .zero)
            let label = NSTextField(labelWithString: "")
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = NSFont.systemFont(ofSize: 13)
            label.identifier = NSUserInterfaceItemIdentifier("cellLabel")
            cell!.addSubview(label)
            cell!.textField = label
            NSLayoutConstraint.activate([
                label.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                label.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 8),
                label.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -8),
            ])
            cell!.identifier = identifier
        }

        switch tableView.tag {
        case 1:
            let pair = LanguageManager.shared.availablePairs[row]
            cell!.textField?.stringValue = "\(pair.flagA) \(pair.nameA) ↔ \(pair.flagB) \(pair.nameB)"
        case 2:
            cell!.textField?.stringValue = exclusionsList[row]
        default:
            break
        }

        return cell
    }
}

// MARK: - HotkeyRecorderField

class HotkeyRecorderField: NSTextField {

    var combo: HotkeyCombo = HotkeyManager.defaultComboStatic {
        didSet {
            stringValue = combo.displayString
        }
    }

    private var isRecording = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isEditable = false
        isSelectable = false
        isBordered = true
        isBezeled = true
        bezelStyle = .roundedBezel
        alignment = .center
        stringValue = combo.displayString
        placeholderString = "Click to record"
    }

    override func mouseDown(with event: NSEvent) {
        isRecording = true
        stringValue = "Press keys..."
        window?.makeFirstResponder(self)
    }

    override var acceptsFirstResponder: Bool { return true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let flags = event.modifierFlags
        let keyCode = event.keyCode

        // Require at least one modifier
        let hasModifier = flags.contains(.command) || flags.contains(.option) ||
                          flags.contains(.control) || flags.contains(.shift)

        if hasModifier {
            var cgFlags = CGEventFlags()
            if flags.contains(.command) { cgFlags.insert(.maskCommand) }
            if flags.contains(.option) { cgFlags.insert(.maskAlternate) }
            if flags.contains(.shift) { cgFlags.insert(.maskShift) }
            if flags.contains(.control) { cgFlags.insert(.maskControl) }

            combo = HotkeyCombo(keyCode: keyCode, modifiers: cgFlags.rawValue)
            isRecording = false
        } else if event.keyCode == 0x35 { // Escape
            isRecording = false
            stringValue = combo.displayString
        }
    }

    override func flagsChanged(with event: NSEvent) {
        if isRecording {
            let flags = event.modifierFlags
            var parts: [String] = []
            if flags.contains(.control) { parts.append("⌃") }
            if flags.contains(.option) { parts.append("⌥") }
            if flags.contains(.shift) { parts.append("⇧") }
            if flags.contains(.command) { parts.append("⌘") }
            if !parts.isEmpty {
                stringValue = parts.joined() + "..."
            }
        }
    }
}

extension HotkeyManager {
    static var defaultComboStatic: HotkeyCombo {
        return HotkeyCombo.defaultCombo
    }
}
