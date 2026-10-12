import Foundation

enum TextChunker {
    static func chunk(
        pages: [(pageNum0: Int, rawText: String)],
        maxChars: Int = 1800,
        omitSymbols: Bool = true
    ) -> [TextChunk] {
        var chunks: [TextChunk] = []
        var chunkIdx = 0
        var currentClean = ""
        var currentRaw = ""
        var chunkPages: [Int] = []

        for page in pages {
            let page1 = page.pageNum0 + 1
            let cleaned = TextCleaner.clean(page.rawText, omitSymbols: omitSymbols)
            if cleaned.isEmpty { continue }

            let sentences = splitSentences(cleaned)
            for sentence in sentences {
                let s = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                if s.isEmpty { continue }

                if !currentClean.isEmpty && currentClean.count + s.count > maxChars {
                    chunks.append(TextChunk(
                        chunkIndex: chunkIdx,
                        pageNumber: chunkPages.min() ?? page1,
                        originalText: currentRaw.trimmingCharacters(in: .whitespacesAndNewlines),
                        cleanText: currentClean.trimmingCharacters(in: .whitespacesAndNewlines),
                        audioPath: nil,
                        status: .pending,
                        errorMessage: nil
                    ))
                    chunkIdx += 1
                    currentClean = s + " "
                    currentRaw = s + " "
                    chunkPages = [page1]
                } else {
                    currentClean += s + " "
                    currentRaw += s + " "
                    if !chunkPages.contains(page1) {
                        chunkPages.append(page1)
                    }
                }
            }
        }

        let leftover = currentClean.trimmingCharacters(in: .whitespacesAndNewlines)
        if !leftover.isEmpty {
            chunks.append(TextChunk(
                chunkIndex: chunkIdx,
                pageNumber: chunkPages.min() ?? (pages.last.map { $0.pageNum0 + 1 } ?? 1),
                originalText: currentRaw.trimmingCharacters(in: .whitespacesAndNewlines),
                cleanText: leftover,
                audioPath: nil,
                status: .pending,
                errorMessage: nil
            ))
        }
        return chunks
    }

    private static func splitSentences(_ text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"(?<=[.!?])\s+"#) else {
            return [text]
        }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        if matches.isEmpty { return [text] }

        var result: [String] = []
        var last = 0
        for m in matches {
            let part = ns.substring(with: NSRange(location: last, length: m.range.location - last))
            result.append(part)
            last = m.range.location + m.range.length
        }
        if last < ns.length {
            result.append(ns.substring(from: last))
        }
        return result
    }
}
