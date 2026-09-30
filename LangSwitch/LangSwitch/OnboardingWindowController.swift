import AppKit

class OnboardingWindowController: NSWindowController {

    var onCompleted: (() -> Void)?
    private var currentPage: Int = 0
    private let totalPages = 5

    private var containerView: NSView!
    private var titleLabel: NSTextField!
    private var subtitleLabel: NSTextField!
    private var contentView: NSView!
    private var backButton: NSButton!
    private var nextButton: NSButton!
    private var pageIndicator: NSTextField!

    // Page-specific views
    private var languageTableView: NSTableView?
    private var accessibilityStatusLabel: NSTextField?
    private var accessibilityCheckTimer: Timer?
    private var hotkeyField: HotkeyRecorderField?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to LangSwitch"
        window.center()
        window.isMovableByWindowBackground = true
        self.init(window: window)
        setupUI()
        showPage(0)
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        // Background
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        // Container
        containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 30),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -30),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])

        // Title
        titleLabel = makeLabel(fontSize: 22, weight: .bold)
        containerView.addSubview(titleLabel)

        // Subtitle
        subtitleLabel = makeLabel(fontSize: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.maximumNumberOfLines = 3
        containerView.addSubview(subtitleLabel)

        // Content area
        self.contentView = NSView()
        self.contentView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(self.contentView)

        // Page indicator
        pageIndicator = makeLabel(fontSize: 11, weight: .regular)
        pageIndicator.textColor = .tertiaryLabelColor
        pageIndicator.alignment = .center
        containerView.addSubview(pageIndicator)

        // Navigation buttons
        backButton = NSButton(title: "Back", target: self, action: #selector(goBack))
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.bezelStyle = .rounded

        nextButton = NSButton(title: "Next", target: self, action: #selector(goNext))
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.bezelStyle = .rounded
        nextButton.keyEquivalent = "\r"

        containerView.addSubview(backButton)
        containerView.addSubview(nextButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            self.contentView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            self.contentView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            self.contentView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            self.contentView.bottomAnchor.constraint(equalTo: pageIndicator.topAnchor, constant: -16),

            pageIndicator.bottomAnchor.constraint(equalTo: backButton.topAnchor, constant: -12),
            pageIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            backButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            backButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 80),

            nextButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            nextButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 100),
        ])
    }

    private func makeLabel(fontSize: CGFloat, weight: NSFont.Weight) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: fontSize, weight: weight)
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        return label
    }

    // MARK: - Pages

    private func showPage(_ index: Int) {
        currentPage = index

        // Clear content
        contentView.subviews.forEach { $0.removeFromSuperview() }
        languageTableView = nil
        accessibilityStatusLabel = nil
        accessibilityCheckTimer?.invalidate()
        accessibilityCheckTimer = nil
        hotkeyField = nil
        NotificationCenter.default.removeObserver(self, name: NSApplication.didBecomeActiveNotification, object: nil)

        pageIndicator.stringValue = (0..<totalPages).map { $0 == index ? "●" : "○" }.joined(separator: " ")

        backButton.isHidden = (index == 0)
        nextButton.title = (index == totalPages - 1) ? "Done" : "Next"

        switch index {
        case 0: setupPage0()
        case 1: setupPage1()
        case 2: setupPage2()
        case 3: setupPage3()
        case 4: setupPage4()
        default: break
        }
    }

    private func setupPage0() {
        titleLabel.stringValue = "Welcome to LangSwitch"
        subtitleLabel.stringValue = "LangSwitch instantly fixes text typed in the wrong keyboard layout — right where you typed it."

        let iconLabel = NSTextField(labelWithString: "⌨️")
        iconLabel.font = NSFont.systemFont(ofSize: 48)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.isEditable = false
        iconLabel.isBordered = false
        iconLabel.backgroundColor = .clear
        contentView.addSubview(iconLabel)

        let descLabel = makeLabel(fontSize: 13, weight: .regular)
        descLabel.stringValue = "1. Type with the wrong language active\n2. Press ⌥ Space\n3. Text is instantly corrected"
        descLabel.maximumNumberOfLines = 5
        descLabel.lineBreakMode = .byWordWrapping
        contentView.addSubview(descLabel)

        NSLayoutConstraint.activate([
            iconLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),

            descLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 16),
            descLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            descLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }

    private func setupPage1() {
        titleLabel.stringValue = "Choose Language Pair"
        subtitleLabel.stringValue = "Select the language pair you switch between most often."

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        contentView.addSubview(scrollView)

        let tableView = NSTableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.headerView = nil
        tableView.rowHeight = 36
        tableView.delegate = self
        tableView.dataSource = self

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("lang"))
        col.title = "Language Pair"
        tableView.addTableColumn(col)

        scrollView.documentView = tableView
        languageTableView = tableView

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        // Select current pair
        let langManager = LanguageManager.shared
        if let idx = langManager.availablePairs.firstIndex(of: langManager.selectedPair) {
            tableView.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
        }
    }

    private func setupPage2() {
        titleLabel.stringValue = "Accessibility Access"
        subtitleLabel.stringValue = "LangSwitch needs Accessibility permission to read and replace text."

        let statusLabel = makeLabel(fontSize: 13, weight: .regular)
        statusLabel.maximumNumberOfLines = 2
        contentView.addSubview(statusLabel)
        accessibilityStatusLabel = statusLabel

        let openButton = NSButton(title: "Open System Settings", target: self, action: #selector(openAccessibilitySettings))
        openButton.translatesAutoresizingMaskIntoConstraints = false
        openButton.bezelStyle = .rounded
        contentView.addSubview(openButton)

        let refreshButton = NSButton(title: "Check Again", target: self, action: #selector(recheckAccessibility))
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.bezelStyle = .rounded
        contentView.addSubview(refreshButton)

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            openButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            openButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            refreshButton.topAnchor.constraint(equalTo: openButton.bottomAnchor, constant: 8),
            refreshButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ])

        updateAccessibilityStatus()

        // Poll every second and auto-advance when granted
        accessibilityCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateAccessibilityStatus()
        }

        // Also re-check when app regains focus (user returns from System Settings)
        NotificationCenter.default.addObserver(self,
            selector: #selector(recheckAccessibility),
            name: NSApplication.didBecomeActiveNotification,
            object: nil)
    }

    private func updateAccessibilityStatus() {
        let granted = TextAccessibilityHelper.isAccessibilityPermitted()
        if granted {
            accessibilityStatusLabel?.stringValue = "✅ Accessibility access granted!"
            accessibilityStatusLabel?.textColor = .systemGreen
            accessibilityCheckTimer?.invalidate()
            accessibilityCheckTimer = nil
        } else {
            accessibilityStatusLabel?.stringValue = "⚠️ Accessibility access not yet granted. Click the button below to open System Settings."
            accessibilityStatusLabel?.textColor = .systemOrange
        }
    }

    @objc private func recheckAccessibility() {
        guard currentPage == 2 else { return }
        updateAccessibilityStatus()
    }

    @objc private func openAccessibilitySettings() {
        TextAccessibilityHelper.requestAccessibilityPermissions()
    }

    private func setupPage3() {
        titleLabel.stringValue = "Keyboard Shortcut"
        subtitleLabel.stringValue = "The default shortcut is ⌥ Space. You can change it here or later in Settings."

        let currentLabel = makeLabel(fontSize: 13, weight: .regular)
        currentLabel.stringValue = "Current shortcut:"
        contentView.addSubview(currentLabel)

        let recorder = HotkeyRecorderField()
        recorder.translatesAutoresizingMaskIntoConstraints = false
        recorder.combo = HotkeyManager().currentCombo
        contentView.addSubview(recorder)
        hotkeyField = recorder

        let hintLabel = makeLabel(fontSize: 11, weight: .regular)
        hintLabel.stringValue = "Click the field and press your desired key combination."
        hintLabel.textColor = .secondaryLabelColor
        contentView.addSubview(hintLabel)

        NSLayoutConstraint.activate([
            currentLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            currentLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),

            recorder.topAnchor.constraint(equalTo: currentLabel.bottomAnchor, constant: 8),
            recorder.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            recorder.widthAnchor.constraint(equalToConstant: 200),
            recorder.heightAnchor.constraint(equalToConstant: 28),

            hintLabel.topAnchor.constraint(equalTo: recorder.bottomAnchor, constant: 8),
            hintLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        ])
    }

    private func setupPage4() {
        titleLabel.stringValue = "All Set!"
        subtitleLabel.stringValue = "LangSwitch is ready to use. Look for the language indicator in your menu bar."

        let readyLabel = makeLabel(fontSize: 13, weight: .regular)
        readyLabel.stringValue = "• Press ⌥ Space anytime to convert text\n• Click the menu bar icon to switch languages\n• Access Settings to customize your experience"
        readyLabel.maximumNumberOfLines = 5
        readyLabel.lineBreakMode = .byWordWrapping
        contentView.addSubview(readyLabel)

        NSLayoutConstraint.activate([
            readyLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            readyLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            readyLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }

    // MARK: - Navigation

    @objc private func goBack() {
        if currentPage > 0 {
            showPage(currentPage - 1)
        }
    }

    @objc private func goNext() {
        if currentPage < totalPages - 1 {
            // Save state before moving on
            if currentPage == 1, let tv = languageTableView {
                let row = tv.selectedRow
                if row >= 0 {
                    LanguageManager.shared.selectedPair = LanguageManager.shared.availablePairs[row]
                }
            }
            if currentPage == 3, let recorder = hotkeyField {
                let manager = HotkeyManager()
                manager.reregister(with: recorder.combo)
            }
            showPage(currentPage + 1)
        } else {
            // Done
            accessibilityCheckTimer?.invalidate()
            window?.close()
            onCompleted?()
        }
    }
}

// MARK: - NSTableViewDataSource, NSTableViewDelegate

extension OnboardingWindowController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return LanguageManager.shared.availablePairs.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let pair = LanguageManager.shared.availablePairs[row]
        let cell = NSTableCellView()
        let label = NSTextField(labelWithString: "\(pair.flagA) \(pair.nameA) ↔ \(pair.flagB) \(pair.nameB)")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 13)
        cell.addSubview(label)
        cell.textField = label
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
        ])
        return cell
    }
}
