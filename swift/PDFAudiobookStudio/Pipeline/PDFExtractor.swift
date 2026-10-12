import Foundation
import PDFKit
import Vision
import AppKit

final class PDFExtractor {
    let url: URL
    private let document: PDFDocument

    init(url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw StudioError.pdfNotFound(url.path)
        }
        guard let document = PDFDocument(url: url) else {
            throw StudioError.pdfUnreadable("PDFKit no pudo abrir el archivo.")
        }
        if document.isLocked {
            throw StudioError.pdfEncrypted
        }
        self.url = url
        self.document = document
    }

    var pageCount: Int { document.pageCount }

    /// Flattened PDF outline as 1-indexed page numbers.
    func toc() -> [(level: Int, title: String, page: Int)] {
        guard let root = document.outlineRoot else { return [] }
        var entries: [(Int, String, Int)] = []
        func walk(_ outline: PDFOutline, level: Int) {
            for i in 0..<outline.numberOfChildren {
                guard let child = outline.child(at: i) else { continue }
                let title = (child.label ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                var page = 1
                if let dest = child.destination, let pdfPage = dest.page {
                    page = document.index(for: pdfPage) + 1
                } else if let action = child.action as? PDFActionGoTo, let pdfPage = action.destination.page {
                    page = document.index(for: pdfPage) + 1
                }
                if !title.isEmpty {
                    entries.append((level, title, max(1, page)))
                }
                walk(child, level: level + 1)
            }
        }
        walk(root, level: 1)
        return entries
    }

    func metadata() -> PDFMetadata {
        let attrs = document.documentAttributes ?? [:]
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Double($0) / 1_048_576.0 } ?? 0
        return PDFMetadata(
            name: url.lastPathComponent,
            path: url,
            pageCount: document.pageCount,
            fileSizeMB: (size * 100).rounded() / 100,
            isScanned: isProbablyScanned(),
            author: (attrs[PDFDocumentAttribute.authorAttribute] as? String) ?? "Desconocido",
            title: (attrs[PDFDocumentAttribute.titleAttribute] as? String) ?? "Sin título"
        )
    }

    func extractPageText(pageIndex: Int) -> String {
        guard pageIndex >= 0, pageIndex < document.pageCount, let page = document.page(at: pageIndex) else {
            return ""
        }
        return page.string ?? ""
    }

    func isProbablyScanned(sampleLimit: Int = 10) -> Bool {
        let n = min(pageCount, sampleLimit)
        guard n > 0 else { return false }
        var chars = 0
        for i in 0..<n {
            chars += extractPageText(pageIndex: i).trimmingCharacters(in: .whitespacesAndNewlines).count
        }
        return Double(chars) / Double(n) < 50
    }

    func extractPageOCR(pageIndex: Int) async throws -> String {
        guard let page = document.page(at: pageIndex) else { return "" }
        let rect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0
        let size = CGSize(width: max(rect.width * scale, 1), height: max(rect.height * scale, 1))
        let image = page.thumbnail(of: size, for: .mediaBox)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return ""
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { req, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["es-ES", "es-MX", "en-US"]
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func extractRange(from startPage0: Int, to endPage0: Int, useOCR: Bool, onPage: ((Int, Int) -> Void)? = nil) async throws -> [(pageNum0: Int, rawText: String)] {
        var pages: [(pageNum0: Int, rawText: String)] = []
        let start = max(0, startPage0)
        let end = min(pageCount - 1, endPage0)
        for i in start...end {
            onPage?(i - start + 1, end - start + 1)
            var text = extractPageText(pageIndex: i)
            if useOCR && text.trimmingCharacters(in: .whitespacesAndNewlines).count < 40 {
                if let ocr = try? await extractPageOCR(pageIndex: i), ocr.count > text.count {
                    text = ocr
                }
            }
            pages.append((pageNum0: i, rawText: text))
        }
        return pages
    }
}
