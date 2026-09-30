import AppKit
import Carbon

struct LanguagePair: Codable, Equatable {
    let id: String
    let langA: String
    let langB: String
    let nameA: String
    let nameB: String
    let flagA: String
    let flagB: String
    let inputSourceIdA: String
    let inputSourceIdB: String
}

class LanguageManager: ObservableObject {

    static let shared = LanguageManager()

    let supportedPairs: [LanguagePair] = [
        LanguagePair(
            id: "en-ru",
            langA: "en", langB: "ru",
            nameA: "English", nameB: "Russian",
            flagA: "🇬🇧", flagB: "🇷🇺",
            inputSourceIdA: "com.apple.keylayout.US",
            inputSourceIdB: "com.apple.inputmethod.Russian-IlyaBirmanTypography"
        ),
        LanguagePair(
            id: "en-uk",
            langA: "en", langB: "uk",
            nameA: "English", nameB: "Ukrainian",
            flagA: "🇬🇧", flagB: "🇺🇦",
            inputSourceIdA: "com.apple.keylayout.US",
            inputSourceIdB: "com.apple.inputmethod.Ukrainian"
        ),
        LanguagePair(
            id: "en-de",
            langA: "en", langB: "de",
            nameA: "English", nameB: "German",
            flagA: "🇬🇧", flagB: "🇩🇪",
            inputSourceIdA: "com.apple.keylayout.US",
            inputSourceIdB: "com.apple.keylayout.German"
        ),
        LanguagePair(
            id: "en-fr",
            langA: "en", langB: "fr",
            nameA: "English", nameB: "French",
            flagA: "🇬🇧", flagB: "🇫🇷",
            inputSourceIdA: "com.apple.keylayout.US",
            inputSourceIdB: "com.apple.keylayout.French"
        )
    ]

    /// Only the pairs where at least one side is enabled in the user's input menu.
    var availablePairs: [LanguagePair] {
        guard let rawList = TISCreateInputSourceList(nil, false),
              let sourceList = rawList.takeRetainedValue() as? [TISInputSource] else {
            return supportedPairs
        }

        var enabledIDs = Set<String>()
        for source in sourceList {
            if let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
                let id = Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
                enabledIDs.insert(id)
            }
        }

        let filtered = supportedPairs.filter {
            enabledIDs.contains($0.inputSourceIdA) || enabledIDs.contains($0.inputSourceIdB)
        }
        return filtered.isEmpty ? supportedPairs : filtered
    }

    var selectedPair: LanguagePair {
        get {
            if let data = UserDefaults.standard.data(forKey: "com.langswitch.selectedPair"),
               let pair = try? JSONDecoder().decode(LanguagePair.self, from: data) {
                return pair
            }
            return supportedPairs[0]
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "com.langswitch.selectedPair")
            }
            objectWillChange.send()
        }
    }

    var currentLang: String {
        get {
            return UserDefaults.standard.string(forKey: "com.langswitch.currentLang") ?? "a"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "com.langswitch.currentLang")
            objectWillChange.send()
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
        }
    }

    func toggleLanguage() {
        // Base the direction on the *actual* active source, not stale currentLang.
        let actual = actualCurrentLayout()
        let pair = selectedPair
        if actual == pair.langA {
            currentLang = "b"
            setInputSource(for: "b")
        } else {
            currentLang = "a"
            setInputSource(for: "a")
        }
    }

    func setInputSource(for lang: String) {
        let pair = selectedPair
        let sourceId = lang == "a" ? pair.inputSourceIdA : pair.inputSourceIdB
        switchInputSource(to: sourceId)
    }

    private func switchInputSource(to inputSourceId: String) {
        let filter = [kTISPropertyInputSourceID: inputSourceId] as CFDictionary
        guard let sources = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource],
              let source = sources.first else {
            // Try partial match with contains
            let allSourcesRef = TISCreateInputSourceList(nil, false)
            if let allSources = allSourcesRef?.takeRetainedValue() as? [TISInputSource] {
                for src in allSources {
                    if let idRef = TISGetInputSourceProperty(src, kTISPropertyInputSourceID),
                       let id = Unmanaged<CFString>.fromOpaque(idRef).takeUnretainedValue() as String? {
                        if id.contains(inputSourceId) || inputSourceId.contains(id) {
                            TISSelectInputSource(src)
                            return
                        }
                    }
                }
            }
            return
        }
        TISSelectInputSource(source)
    }

    func currentFlag() -> String {
        let lang = actualCurrentLayout()
        let pair = selectedPair
        return lang == pair.langA ? pair.flagA : pair.flagB
    }

    func currentCode() -> String {
        return actualCurrentLayout().uppercased()
    }

    func pairForId(_ id: String) -> LanguagePair? {
        return supportedPairs.first { $0.id == id }
    }

    /// Detects the *actual* active keyboard input source via TIS and returns the
    /// matching layout code ("en", "ru", "uk", etc.) for the selected pair.
    /// This is more reliable than `currentLang`, which only tracks what LangSwitch
    /// last set — it goes stale whenever the user switches sources manually.
    func actualCurrentLayout() -> String {
        guard let srcRef = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return currentLang == "a" ? selectedPair.langA : selectedPair.langB
        }
        guard let ptr = TISGetInputSourceProperty(srcRef, kTISPropertyInputSourceID) else {
            return currentLang == "a" ? selectedPair.langA : selectedPair.langB
        }
        let activeId = Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
        print("[LangSwitch] active input source id: \(activeId)")

        let pair = selectedPair
        if activeId == pair.inputSourceIdA { return pair.langA }
        if activeId == pair.inputSourceIdB { return pair.langB }

        // ABC is the modern name for the US English layout on macOS Ventura+.
        if activeId == "com.apple.keylayout.ABC" { return pair.langA }

        // Partial-match fallback for input method variants
        if activeId.lowercased().contains("russian") || activeId.lowercased().contains("birman") { return "ru" }
        if activeId.lowercased().contains("ukrainian") { return "uk" }
        if activeId.lowercased().contains("german") { return "de" }
        if activeId.lowercased().contains("french") { return "fr" }

        return pair.langA // default: treat as language A (English)
    }
}
