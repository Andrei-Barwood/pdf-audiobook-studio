import Foundation

enum AppPaths {
    static var support: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = base.appendingPathComponent("PDFAudiobookStudio", isDirectory: true)
        ensure(dir)
        return dir
    }

    static var database: URL {
        support.appendingPathComponent("studio.db")
    }

    static var cache: URL {
        let dir = support.appendingPathComponent("temp_cache", isDirectory: true)
        ensure(dir)
        return dir
    }

    static var staging: URL {
        let dir = support.appendingPathComponent("staging", isDirectory: true)
        ensure(dir)
        return dir
    }

    static var logs: URL {
        support.appendingPathComponent("app.log")
    }

    static func chunkURL(projectID: String, index: Int, format: AudioFormat) -> URL {
        cache.appendingPathComponent("\(projectID)_chunk_\(index).\(format.fileExtension)")
    }

    static func cachedAudioCount() -> Int {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: cache,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return files.filter { url in
            let ext = url.pathExtension.lowercased()
            guard ext == "mp3" || ext == "m4a" || ext == "wav" else { return false }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return size > 0
        }.count
    }

    static func destinationNote(for url: URL) -> String? {
        let keys: Set<URLResourceKey> = [
            .volumeLocalizedFormatDescriptionKey,
            .volumeIsEjectableKey,
            .volumeNameKey,
            .volumeIsLocalKey
        ]
        guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
        let format = values.volumeLocalizedFormatDescription ?? ""
        let name = values.volumeName ?? url.path
        if format.range(of: "HFS", options: .caseInsensitive) != nil
            || format.range(of: "Mac OS Extended", options: .caseInsensitive) != nil {
            return "Destino «\(name)» es HFS+ (típico de discos USB viejos y lentos). Los capítulos se arman en el SSD interno y luego se copian. No borres la caché si la copia falla."
        }
        if values.volumeIsEjectable == true || values.volumeIsLocal == false {
            return "Destino «\(name)» es un disco extraíble o de red. Los capítulos se arman en el SSD interno y luego se copian."
        }
        return nil
    }

    static func clearCache() throws {
        if FileManager.default.fileExists(atPath: cache.path) {
            try FileManager.default.removeItem(at: cache)
        }
        ensure(cache)
    }

    private static func ensure(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

enum AppLog {
    private static let lock = NSLock()

    static func write(_ message: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(stamp)] \(message)\n"
        lock.lock()
        defer { lock.unlock() }
        let url = AppPaths.logs
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data(line.utf8))
    }
}
