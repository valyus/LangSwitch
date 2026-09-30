import Foundation
import AppKit
import CoreGraphics

struct ConversionEntry: Codable, Identifiable {
    let id: UUID
    let originalText: String
    let convertedText: String
    let timestamp: Date
    let langPairId: String

    init(originalText: String, convertedText: String, langPair: LanguagePair) {
        self.id = UUID()
        self.originalText = originalText
        self.convertedText = convertedText
        self.timestamp = Date()
        self.langPairId = langPair.id
    }
}

class ConversionHistory {

    static let shared = ConversionHistory()

    private let maxEntries = 10
    private let defaultsKey = "com.langswitch.conversionHistory"

    private(set) var entries: [ConversionEntry] = []

    private init() {
        loadFromDefaults()
    }

    func add(original: String, converted: String, langPair: LanguagePair) {
        let entry = ConversionEntry(originalText: original, convertedText: converted, langPair: langPair)
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        saveToDefaults()
    }

    func undo(entry: ConversionEntry) {
        // Find the entry and revert it via accessibility
        guard TextAccessibilityHelper.isAccessibilityPermitted() else {
            undoViaClipboard(entry: entry)
            return
        }

        // Try to find and replace the converted text back to original
        if let result = TextAccessibilityHelper.getTextFromBoundary(charCount: entry.convertedText.count) {
            if result.text == entry.convertedText {
                _ = TextAccessibilityHelper.replaceText(range: result.range, with: entry.originalText)
                // Remove from history
                entries.removeAll { $0.id == entry.id }
                saveToDefaults()
            }
        }
    }

    private func undoViaClipboard(entry: ConversionEntry) {
        let pasteboard = NSPasteboard.general
        let savedContents = pasteboard.string(forType: .string)

        let src = CGEventSource(stateID: .hidSystemState)
        let charCount = entry.convertedText.count

        // Select backwards
        for _ in 0..<charCount {
            let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x7B, keyDown: true)
            keyDown?.flags = .maskShift
            keyDown?.post(tap: .cghidEventTap)
            let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x7B, keyDown: false)
            keyUp?.flags = .maskShift
            keyUp?.post(tap: .cghidEventTap)
        }

        // Put original text in clipboard
        pasteboard.clearContents()
        pasteboard.setString(entry.originalText, forType: .string)

        // Paste
        let pasteDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        pasteDown?.flags = .maskCommand
        pasteDown?.post(tap: .cghidEventTap)
        let pasteUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        pasteUp?.flags = .maskCommand
        pasteUp?.post(tap: .cghidEventTap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            pasteboard.clearContents()
            if let saved = savedContents {
                pasteboard.setString(saved, forType: .string)
            }
        }

        entries.removeAll { $0.id == entry.id }
        saveToDefaults()
    }

    func clear() {
        entries.removeAll()
        saveToDefaults()
    }

    // MARK: - Persistence

    private func saveToDefaults() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private func loadFromDefaults() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let loaded = try? JSONDecoder().decode([ConversionEntry].self, from: data) {
            entries = loaded
        }
    }
}
