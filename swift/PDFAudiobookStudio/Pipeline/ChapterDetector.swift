import Foundation
import PDFKit

struct Chapter: Identifiable, Hashable {
    let id: Int
    let title: String
    let startPage: Int
    let endPage: Int

    var pageLabel: String { "\(startPage)–\(endPage)" }
}

enum ChapterDetector {
    private static let majorHeading = try! NSRegularExpression(
        pattern: #"^\s*(?:parte\s+(?:\d+|[ivxlcdm]+)|part\s+(?:\d+|[ivxlcdm]+)|cap[íi]tulo\s+(?:\d+|[ivxlcdm]+)|chapter\s+(?:\d+|[ivxlcdm]+)|libro\s+(?:\d+|[ivxlcdm]+)|book\s+(?:\d+|[ivxlcdm]+)|secci[oó]n\s+(?:\d+|[ivxlcdm]+)|volumen\s+(?:\d+|[ivxlcdm]+)|volume\s+(?:\d+|[ivxlcdm]+)|ap[eé]ndice(?:\s|$)|appendix(?:\s|$))"#,
        options: [.caseInsensitive]
    )

    private static let indexTitle = try! NSRegularExpression(
        pattern: #"^\s*(índice(?:\s+general)?|indice(?:\s+general)?|tabla de contenidos|table of contents|contents|toc)\s*$"#,
        options: [.caseInsensitive]
    )

    private static let chapterKeyword = try! NSRegularExpression(
        pattern: #"^\s*(?:cap[íi]tulo|chapter|part[e]?)\s+(\d+|[IVXLCDM]+)(?:\s*[:.\-–—]\s*(.+))?\s*$"#,
        options: [.caseInsensitive]
    )

    private static let numberedHeading = try! NSRegularExpression(
        pattern: #"^\s*(\d{1,3})\.\s+(.{2,80})\s*$"#
    )

    private static let romanHeading = try! NSRegularExpression(
        pattern: #"^\s*([IVXLCDM]{1,6})\.\s+(.{2,80})\s*$"#
    )

    static func detect(from extractor: PDFExtractor) -> [Chapter] {
        let chapters = fromOutline(extractor.toc(), totalPages: extractor.pageCount)
        return chapters.count >= 2 ? chapters : []
    }

    static func fromOutline(_ toc: [(level: Int, title: String, page: Int)], totalPages: Int) -> [Chapter] {
        let cleaned: [(Int, String, Int)] = toc.compactMap { entry in
            let title = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, !matches(indexTitle, title) else { return nil }
            return (entry.level, title, max(1, entry.page))
        }
        guard !cleaned.isEmpty else { return [] }

        let majors = cleaned.filter { matches(majorHeading, $0.1) }
        let selected = majors.count >= 2
            ? majors
            : cleaned.filter { $0.0 == (cleaned.map(\.0).min() ?? 1) }
        return entriesToChapters(selected, totalPages: totalPages)
    }

    static func fromPageTexts(_ pages: [(pageNum0: Int, rawText: String)], totalPages: Int) -> [Chapter] {
        var hits: [(title: String, page: Int)] = []
        var seen = Set<Int>()
        for page in pages {
            let page1 = page.pageNum0 + 1
            let lines = page.rawText.split(whereSeparator: \.isNewline).prefix(8)
            for line in lines {
                if let title = matchHeading(String(line)), seen.insert(page1).inserted {
                    hits.append((title, page1))
                    break
                }
            }
        }
        guard hits.count >= 2 else { return [] }
        return entriesToChapters(hits.enumerated().map { (1, $0.element.title, $0.element.page) }, totalPages: totalPages)
    }

    static func clip(_ chapters: [Chapter], startPage: Int, endPage: Int) -> [Chapter] {
        chapters.compactMap { chapter in
            let start = max(chapter.startPage, startPage)
            let end = min(chapter.endPage, endPage)
            guard start <= end else { return nil }
            return Chapter(id: chapter.id, title: chapter.title, startPage: start, endPage: end)
        }
    }

    static func filename(index: Int, title: String, total: Int, format: AudioFormat) -> String {
        let width = total >= 100 ? 3 : 2
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
            .union(.newlines)
            .union(.controlCharacters)
        var safe = title.components(separatedBy: invalid).joined(separator: " ")
        safe = safe.replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
        while safe.contains("  ") {
            safe = safe.replacingOccurrences(of: "  ", with: " ")
        }
        safe = safe.trimmingCharacters(in: .whitespacesAndNewlines)
        if safe.count > 72 {
            let end = safe.index(safe.startIndex, offsetBy: 72)
            safe = String(safe[..<end]).trimmingCharacters(in: .whitespaces)
        }
        if safe.isEmpty { safe = "capitulo_\(index)" }
        let padded = String(format: "%0\(width)d", index)
        return "\(padded)_\(safe).\(format.fileExtension)"
    }

    private static func entriesToChapters(_ entries: [(Int, String, Int)], totalPages: Int) -> [Chapter] {
        var unique: [(Int, String, Int)] = []
        for item in entries {
            if let last = unique.last, last.1 == item.1, last.2 == item.2 { continue }
            unique.append(item)
        }
        return unique.enumerated().map { idx, item in
            let page = max(1, item.2)
            let end: Int
            if idx + 1 < unique.count {
                let next = unique[idx + 1].2
                end = next > page ? next - 1 : page
            } else {
                end = max(totalPages, page)
            }
            return Chapter(
                id: idx,
                title: item.1.isEmpty ? "Capítulo \(idx + 1)" : item.1,
                startPage: page,
                endPage: max(page, end)
            )
        }
    }

    private static func matchHeading(_ line: String) -> String? {
        let stripped = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard stripped.count >= 3 else { return nil }
        if matches(chapterKeyword, stripped) { return stripped }
        if let m = first(numberedHeading, stripped) {
            let title = group(m, 2, in: stripped)
            if let first = title.first, first.isLetter { return stripped }
        }
        if let m = first(romanHeading, stripped) {
            let title = group(m, 2, in: stripped)
            if let first = title.first, first.isLetter { return stripped }
        }
        return nil
    }

    private static func matches(_ regex: NSRegularExpression, _ text: String) -> Bool {
        regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private static func first(_ regex: NSRegularExpression, _ text: String) -> NSTextCheckingResult? {
        regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
    }

    private static func group(_ match: NSTextCheckingResult, _ i: Int, in text: String) -> String {
        guard let range = Range(match.range(at: i), in: text) else { return "" }
        return String(text[range])
    }
}
