import Foundation

class TextConverter {

    static let shared = TextConverter()

    // MARK: - Layout Maps

    // QWERTY → ЙЦУКЕН (Russian)
    private let qwertyToRussian: [Character: Character] = [
        "q": "й", "w": "ц", "e": "у", "r": "к", "t": "е", "y": "н", "u": "г", "i": "ш",
        "o": "щ", "p": "з", "[": "х", "]": "ъ",
        "a": "ф", "s": "ы", "d": "в", "f": "а", "g": "п", "h": "р", "j": "о", "k": "л",
        "l": "д", ";": "ж", "'": "э",
        "z": "я", "x": "ч", "c": "с", "v": "м", "b": "и", "n": "т", "m": "ь",
        ",": "б", ".": "ю", "`": "ё",
        "Q": "Й", "W": "Ц", "E": "У", "R": "К", "T": "Е", "Y": "Н", "U": "Г", "I": "Ш",
        "O": "Щ", "P": "З", "{": "Х", "}": "Ъ",
        "A": "Ф", "S": "Ы", "D": "В", "F": "А", "G": "П", "H": "Р", "J": "О", "K": "Л",
        "L": "Д", ":": "Ж", "\"": "Э",
        "Z": "Я", "X": "Ч", "C": "С", "V": "М", "B": "И", "N": "Т", "M": "Ь",
        "<": "Б", ">": "Ю", "~": "Ё"
    ]

    // QWERTY → ЙЦУКЕН-UA (Ukrainian) - similar to Russian with some differences
    private let qwertyToUkrainian: [Character: Character] = [
        "q": "й", "w": "ц", "e": "у", "r": "к", "t": "е", "y": "н", "u": "г", "i": "ш",
        "o": "щ", "p": "з", "[": "х", "]": "ї",
        "a": "ф", "s": "і", "d": "в", "f": "а", "g": "п", "h": "р", "j": "о", "k": "л",
        "l": "д", ";": "ж", "'": "є",
        "z": "я", "x": "ч", "c": "с", "v": "м", "b": "и", "n": "т", "m": "ь",
        ",": "б", ".": "ю", "`": "ґ",
        "Q": "Й", "W": "Ц", "E": "У", "R": "К", "T": "Е", "Y": "Н", "U": "Г", "I": "Ш",
        "O": "Щ", "P": "З", "{": "Х", "}": "Ї",
        "A": "Ф", "S": "І", "D": "В", "F": "А", "G": "П", "H": "Р", "J": "О", "K": "Л",
        "L": "Д", ":": "Ж", "\"": "Є",
        "Z": "Я", "X": "Ч", "C": "С", "V": "М", "B": "И", "N": "Т", "M": "Ь",
        "<": "Б", ">": "Ю", "~": "Ґ"
    ]

    // QWERTY → QWERTZ (German)
    private let qwertyToGerman: [Character: Character] = [
        "y": "z", "z": "y",
        "Y": "Z", "Z": "Y"
    ]

    // QWERTY → AZERTY (French)
    private let qwertyToFrench: [Character: Character] = [
        "q": "a", "w": "z", "a": "q", "z": "w",
        "Q": "A", "W": "Z", "A": "Q", "Z": "W",
        ";": "m", "m": ";",
        ":": "M", "M": ":",
        ",": ",", ".": ".",
        "1": "&", "2": "é", "3": "\"", "4": "'", "5": "(", "6": "-", "7": "è",
        "8": "_", "9": "ç", "0": "à"
    ]

    // MARK: - Reverse Maps (auto-derived)

    private lazy var russianToQwerty: [Character: Character] = Self.invertMap(qwertyToRussian)
    private lazy var ukrainianToQwerty: [Character: Character] = Self.invertMap(qwertyToUkrainian)
    private lazy var germanToQwerty: [Character: Character] = Self.invertMap(qwertyToGerman)
    private lazy var frenchToQwerty: [Character: Character] = Self.invertMap(qwertyToFrench)

    private static func invertMap(_ map: [Character: Character]) -> [Character: Character] {
        var inverted: [Character: Character] = [:]
        for (key, value) in map {
            inverted[value] = key
        }
        return inverted
    }

    // MARK: - Conversion

    func convert(_ text: String, from sourceLayout: String, to targetLayout: String) -> String {
        guard sourceLayout != targetLayout else { return text }

        // First convert source → English (QWERTY), then English → target
        let intermediate: String
        if sourceLayout == "en" {
            intermediate = text
        } else {
            intermediate = applyMap(text, map: reverseMap(for: sourceLayout))
        }

        if targetLayout == "en" {
            return intermediate
        } else {
            return applyMap(intermediate, map: forwardMap(for: targetLayout))
        }
    }

    private func applyMap(_ text: String, map: [Character: Character]) -> String {
        return String(text.map { char in
            map[char] ?? char
        })
    }

    private func forwardMap(for layout: String) -> [Character: Character] {
        switch layout {
        case "ru": return qwertyToRussian
        case "uk": return qwertyToUkrainian
        case "de": return qwertyToGerman
        case "fr": return qwertyToFrench
        default: return [:]
        }
    }

    private func reverseMap(for layout: String) -> [Character: Character] {
        switch layout {
        case "ru": return russianToQwerty
        case "uk": return ukrainianToQwerty
        case "de": return germanToQwerty
        case "fr": return frenchToQwerty
        default: return [:]
        }
    }

    func availablePairs() -> [(String, String)] {
        return [
            ("en", "ru"),
            ("en", "uk"),
            ("en", "de"),
            ("en", "fr")
        ]
    }
}
