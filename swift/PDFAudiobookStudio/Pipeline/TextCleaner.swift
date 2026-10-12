import Foundation

enum TextCleaner {
    /// Sentence punctuation kept so TTS still pauses. Other glyphs are stripped
    /// because voices like es-AR-ElenaNeural read their names aloud.
    private static let allowedPunctuation = Set(Array(".,;:?!¿¡…'"))

    static func clean(_ raw: String, omitSymbols: Bool = true) -> String {
        guard !raw.isEmpty else { return "" }

        var text = raw.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        if let hyphen = try? NSRegularExpression(
            pattern: #"(\w+)-\s*\n\s*([A-Za-zñáéíóúüÑÁÉÍÓÚÜ]+)"#,
            options: [.caseInsensitive]
        ) {
            text = hyphen.stringByReplacingMatches(
                in: text,
                range: NSRange(text.startIndex..., in: text),
                withTemplate: "$1$2"
            )
        }

        text = removeHeadersFooters(text)

        let paragraphs = text.components(separatedBy: "\n\n")
        let cleanedParagraphs: [String] = paragraphs.compactMap { p in
            let joined = p.replacingOccurrences(of: "\n", with: " ")
            let collapsed = joined.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return collapsed.isEmpty ? nil : collapsed
        }
        var cleaned = cleanedParagraphs.joined(separator: "\n\n")

        cleaned = cleaned.replacingOccurrences(of: "—", with: " - ")
            .replacingOccurrences(of: "–", with: " - ")
        cleaned = cleaned.replacingOccurrences(of: #"[“”«»]"#, with: "\"", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"[‘’]"#, with: "'", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\.{4,}"#, with: "...", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"_{2,}"#, with: " ", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "-{3,}", with: " - ", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\*{2,}"#, with: " ", options: .regularExpression)

        if omitSymbols {
            cleaned = omitSpokenSymbols(cleaned)
        }

        cleaned = cleaned.replacingOccurrences(of: " +", with: " ", options: .regularExpression)

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Strips glyphs Spanish Edge voices (especially Elena) tend to pronounce.
    /// Expands meaningful units first so "50%" becomes "50 por ciento".
    static func omitSpokenSymbols(_ raw: String) -> String {
        guard !raw.isEmpty else { return "" }

        var text = raw
        text = text.replacingOccurrences(of: #"https?://\S+"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #"www\.\S+"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\b[\w.+-]+@[\w.-]+\.\w{2,}\b"#, with: " ", options: .regularExpression)

        text = text.replacingOccurrences(of: #"(\d+(?:[.,]\d+)?)\s*%"#, with: "$1 por ciento", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\$\s*(\d+(?:[.,]\d+)?)"#, with: "$1 dólares", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(\d+(?:[.,]\d+)?)\s*\$"#, with: "$1 dólares", options: .regularExpression)
        text = text.replacingOccurrences(of: #"€\s*(\d+(?:[.,]\d+)?)"#, with: "$1 euros", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(\d+(?:[.,]\d+)?)\s*€"#, with: "$1 euros", options: .regularExpression)
        text = text.replacingOccurrences(of: #"£\s*(\d+(?:[.,]\d+)?)"#, with: "$1 libras", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(\d+(?:[.,]\d+)?)\s*£"#, with: "$1 libras", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(\d+(?:[.,]\d+)?)\s*°[CFcf]?"#, with: "$1 grados", options: .regularExpression)

        text = text.replacingOccurrences(of: "&", with: " y ")
        text = text.replacingOccurrences(of: #"\by/o\b"#, with: "y o", options: [.regularExpression, .caseInsensitive])

        while true {
            let replaced = text.replacingOccurrences(
                of: #"(\d+)\s*/\s*(\d+)"#,
                with: "$1 de $2",
                options: .regularExpression
            )
            if replaced == text { break }
            text = replaced
        }

        text = text.replacingOccurrences(of: #"\[\d+\]"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #"[¹²³⁴⁵⁶⁷⁸⁹⁰]+"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "(", with: ", ")
        text = text.replacingOccurrences(of: ")", with: ", ")
        text = text.replacingOccurrences(of: #"[“”«»"]"#, with: " ", options: .regularExpression)

        let chars = Array(text)
        var out = ""
        out.reserveCapacity(chars.count)
        for i in chars.indices {
            let ch = chars[i]
            if ch.isLetter || ch.isNumber || ch.isWhitespace {
                out.append(ch)
                continue
            }
            if allowedPunctuation.contains(ch) {
                out.append(ch)
                continue
            }
            if ch == "-" {
                let prev = i > 0 ? chars[i - 1] : " "
                let next = i + 1 < chars.count ? chars[i + 1] : " "
                if (prev.isLetter || prev.isNumber) && (next.isLetter || next.isNumber) {
                    out.append(ch)
                    continue
                }
            }
            out.append(" ")
        }

        var result = out.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\s+([.,;:?!¡¿])"#, with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: #"([,;:]){2,}"#, with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: #"^[,.\s]+"#, with: "", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func removeHeadersFooters(_ text: String) -> String {
        let patterns: [NSRegularExpression] = [
            try! NSRegularExpression(pattern: #"^\s*p[áa]g(ina)?\s*\d+\s*(de\s*\d+)?\s*$"#, options: [.caseInsensitive]),
            try! NSRegularExpression(pattern: #"^\s*page\s*\d+\s*(of\s*\d+)?\s*$"#, options: [.caseInsensitive]),
            try! NSRegularExpression(pattern: #"^\s*\d+\s*de\s*\d+\s*$"#, options: [.caseInsensitive]),
            try! NSRegularExpression(pattern: #"^\s*\d+\s*of\s*\d+\s*$"#, options: [.caseInsensitive]),
            try! NSRegularExpression(pattern: #"^\s*\d+\s*$"#)
        ]

        return text.components(separatedBy: "\n").filter { line in
            let stripped = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if stripped.isEmpty { return true }
            let range = NSRange(stripped.startIndex..., in: stripped)
            return !patterns.contains(where: { $0.firstMatch(in: stripped, range: range) != nil })
        }.joined(separator: "\n")
    }

    static func removeIncompatibleCharacters(_ string: String) -> String {
        String(string.map { ch in
            guard let v = ch.unicodeScalars.first?.value else { return ch }
            if (0...8).contains(v) || (11...12).contains(v) || (14...31).contains(v) {
                return " "
            }
            return ch
        })
    }

    static func xmlEscape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
