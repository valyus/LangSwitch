import AppKit
import ApplicationServices

struct TextResult {
    let text: String
    let range: NSRange
}

class TextAccessibilityHelper {

    static func isAccessibilityPermitted() -> Bool {
        // AXIsProcessTrusted() is the authoritative check. The previous "functional probe"
        // caused false positives: when no element is focused it returns .noValue (not
        // .apiDisabled), making the probe think AX works even when it doesn't.
        // CGEvent injection and AX API writes all fail without real trust.
        return AXIsProcessTrusted()
    }

    static func requestAccessibilityPermissions() {
        // Register the current binary (creates the list entry if absent).
        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
        // Always open the panel directly — if the entry already exists but is disabled,
        // AXIsProcessTrustedWithOptions shows no dialog, so we must open Settings ourselves.
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static func getTextFromBoundary(charCount: Int) -> TextResult? {
        let systemElement = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemElement, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focusedRef = focusedRef else { return nil }
        let focused = focusedRef as! AXUIElement

        // Get cursor position
        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let rangeRef = rangeRef else { return nil }
        var cfRange = CFRange(location: 0, length: 0)
        guard AXValueGetValue(rangeRef as! AXValue, .cfRange, &cfRange) else { return nil }

        let cursorPos = cfRange.location + cfRange.length
        let startPos = max(0, cursorPos - charCount)
        let count = cursorPos - startPos
        guard count > 0 else { return nil }

        // Try: temporarily set selection to desired range, then read kAXSelectedTextAttribute
        var selectCFRange = CFRange(location: startPos, length: count)
        if let axSelectRange = AXValueCreate(.cfRange, &selectCFRange),
           AXUIElementSetAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, axSelectRange) == .success {
            var selectedRef: CFTypeRef?
            let readResult = AXUIElementCopyAttributeValue(focused, kAXSelectedTextAttribute as CFString, &selectedRef)
            // Restore cursor (deselect)
            var restoreCFRange = CFRange(location: cursorPos, length: 0)
            if let axRestore = AXValueCreate(.cfRange, &restoreCFRange) {
                AXUIElementSetAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, axRestore)
            }
            if readResult == .success, let text = selectedRef as? String, !text.isEmpty {
                return TextResult(text: text, range: NSRange(location: startPos, length: count))
            }
        }

        // Fallback: read full kAXValueAttribute
        var textRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused, kAXValueAttribute as CFString, &textRef) == .success,
              let fullText = textRef as? String else { return nil }
        let startIndex = fullText.index(fullText.startIndex, offsetBy: startPos, limitedBy: fullText.endIndex) ?? fullText.startIndex
        let endIndex = fullText.index(fullText.startIndex, offsetBy: cursorPos, limitedBy: fullText.endIndex) ?? fullText.endIndex
        let substring = String(fullText[startIndex..<endIndex])
        guard !substring.isEmpty else { return nil }
        return TextResult(text: substring, range: NSRange(location: startPos, length: count))
    }

    static func replaceText(range: NSRange, with newText: String) -> Bool {
        let systemElement = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemElement, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focusedRef = focusedRef else { return false }
        let focused = focusedRef as! AXUIElement

        var cfRange = CFRange(location: range.location, length: range.length)
        guard let axRange = AXValueCreate(.cfRange, &cfRange) else { return false }
        guard AXUIElementSetAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, axRange) == .success else { return false }

        // Try direct AX write first
        if AXUIElementSetAttributeValue(focused, kAXSelectedTextAttribute as CFString, newText as CFString) == .success {
            return true
        }

        // Fallback: clipboard paste
        let pb = NSPasteboard.general
        let saved = pb.string(forType: .string)
        pb.clearContents()
        pb.setString(newText, forType: .string)
        let src = CGEventSource(stateID: .hidSystemState)
        let pasteDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        pasteDown?.flags = .maskCommand
        pasteDown?.post(tap: .cghidEventTap)
        let pasteUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        pasteUp?.flags = .maskCommand
        pasteUp?.post(tap: .cghidEventTap)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            pb.clearContents()
            if let s = saved { pb.setString(s, forType: .string) }
        }
        return true
    }
}
