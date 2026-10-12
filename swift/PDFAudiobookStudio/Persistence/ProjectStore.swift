import Foundation
import SQLite3

final class ProjectStore: @unchecked Sendable {
    static let shared = ProjectStore()

    private var db: OpaquePointer?
    private let lock = NSLock()

    private init() {
        open()
        migrate()
    }

    deinit {
        if db != nil { sqlite3_close(db) }
    }

    private func open() {
        let path = AppPaths.database.path
        if sqlite3_open(path, &db) != SQLITE_OK {
            fputs("SQLite open failed: \(lastError())\n", stderr)
        }
        exec("PRAGMA foreign_keys = ON;")
        exec("PRAGMA journal_mode = WAL;")
    }

    private func migrate() {
        exec("""
        CREATE TABLE IF NOT EXISTS projects (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            pdf_path TEXT NOT NULL,
            output_dir TEXT NOT NULL,
            created_at TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'ACTIVE',
            engine_type TEXT NOT NULL,
            voice_id TEXT NOT NULL,
            rate REAL NOT NULL,
            format_ext TEXT NOT NULL DEFAULT 'mp3',
            split_by_chapter INTEGER NOT NULL DEFAULT 0
        );
        """)
        exec("""
        CREATE TABLE IF NOT EXISTS chunks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id TEXT NOT NULL,
            chunk_index INTEGER NOT NULL,
            page_number INTEGER NOT NULL,
            original_text TEXT NOT NULL,
            clean_text TEXT NOT NULL,
            audio_path TEXT,
            status TEXT NOT NULL DEFAULT 'PENDING',
            error_message TEXT,
            chapter_index INTEGER,
            chapter_title TEXT,
            FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
            UNIQUE(project_id, chunk_index)
        );
        """)
        exec("""
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        """)
        addColumnIfNeeded("projects", "split_by_chapter", "INTEGER NOT NULL DEFAULT 0")
        addColumnIfNeeded("chunks", "chapter_index", "INTEGER")
        addColumnIfNeeded("chunks", "chapter_title", "TEXT")
    }

    private func addColumnIfNeeded(_ table: String, _ column: String, _ decl: String) {
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "PRAGMA table_info(\(table));", -1, &stmt, nil)
        var names: Set<String> = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let c = sqlite3_column_text(stmt, 1) {
                names.insert(String(cString: c))
            }
        }
        sqlite3_finalize(stmt)
        if !names.contains(column) {
            exec("ALTER TABLE \(table) ADD COLUMN \(column) \(decl);")
        }
    }

    func createProject(
        name: String,
        pdfPath: String,
        outputDir: String,
        engine: TTSEngineKind,
        voiceID: String,
        rate: Double,
        format: AudioFormat,
        splitByChapter: Bool = false
    ) -> ProjectRecord {
        let id = UUID().uuidString
        let created = ISO8601DateFormatter().string(from: Date())
        lock.lock()
        defer { lock.unlock() }
        let sql = """
        INSERT INTO projects (id, name, pdf_path, output_dir, created_at, status, engine_type, voice_id, rate, format_ext, split_by_chapter)
        VALUES (?, ?, ?, ?, ?, 'ACTIVE', ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        bind(stmt, 1, id)
        bind(stmt, 2, name)
        bind(stmt, 3, pdfPath)
        bind(stmt, 4, outputDir)
        bind(stmt, 5, created)
        bind(stmt, 6, engine.rawValue)
        bind(stmt, 7, voiceID)
        sqlite3_bind_double(stmt, 8, rate)
        bind(stmt, 9, format.rawValue)
        sqlite3_bind_int(stmt, 10, splitByChapter ? 1 : 0)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        return ProjectRecord(
            id: id, name: name, pdfPath: pdfPath, outputDir: outputDir,
            createdAt: created, status: .active, engineType: engine,
            voiceID: voiceID, rate: rate, formatExt: format,
            splitByChapter: splitByChapter
        )
    }

    func listProjects() -> [ProjectRecord] {
        lock.lock()
        defer { lock.unlock() }
        var rows: [ProjectRecord] = []
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "SELECT * FROM projects ORDER BY created_at DESC;", -1, &stmt, nil)
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let row = readProject(stmt) { rows.append(row) }
        }
        sqlite3_finalize(stmt)
        return rows
    }

    func loadProject(id: String) -> ProjectRecord? {
        lock.lock()
        defer { lock.unlock() }
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "SELECT * FROM projects WHERE id = ?;", -1, &stmt, nil)
        bind(stmt, 1, id)
        var row: ProjectRecord?
        if sqlite3_step(stmt) == SQLITE_ROW {
            row = readProject(stmt)
        }
        sqlite3_finalize(stmt)
        return row
    }

    func updateStatus(projectID: String, status: ProjectStatus) {
        lock.lock()
        defer { lock.unlock() }
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "UPDATE projects SET status = ? WHERE id = ?;", -1, &stmt, nil)
        bind(stmt, 1, status.rawValue)
        bind(stmt, 2, projectID)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }

    func deleteProject(id: String) {
        lock.lock()
        defer { lock.unlock() }
        exec("PRAGMA foreign_keys = ON;")
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "DELETE FROM projects WHERE id = ?;", -1, &stmt, nil)
        bind(stmt, 1, id)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }

    func addChunks(projectID: String, chunks: [TextChunk]) {
        lock.lock()
        defer { lock.unlock() }
        exec("BEGIN;")
        let sql = """
        INSERT OR IGNORE INTO chunks (project_id, chunk_index, page_number, original_text, clean_text, audio_path, status, error_message, chapter_index, chapter_title)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        for chunk in chunks {
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            bind(stmt, 1, projectID)
            sqlite3_bind_int(stmt, 2, Int32(chunk.chunkIndex))
            sqlite3_bind_int(stmt, 3, Int32(chunk.pageNumber))
            bind(stmt, 4, chunk.originalText)
            bind(stmt, 5, chunk.cleanText)
            bind(stmt, 6, chunk.audioPath)
            bind(stmt, 7, chunk.status.rawValue)
            bind(stmt, 8, chunk.errorMessage)
            if let chapterIndex = chunk.chapterIndex {
                sqlite3_bind_int(stmt, 9, Int32(chapterIndex))
            } else {
                sqlite3_bind_null(stmt, 9)
            }
            bind(stmt, 10, chunk.chapterTitle)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
        exec("COMMIT;")
    }

    func updateChunk(
        projectID: String,
        index: Int,
        status: ChunkStatus,
        audioPath: String? = nil,
        error: String? = nil
    ) {
        lock.lock()
        defer { lock.unlock() }
        var stmt: OpaquePointer?
        if let audioPath {
            sqlite3_prepare_v2(
                db,
                "UPDATE chunks SET status = ?, audio_path = ?, error_message = ? WHERE project_id = ? AND chunk_index = ?;",
                -1, &stmt, nil
            )
            bind(stmt, 1, status.rawValue)
            bind(stmt, 2, audioPath)
            bind(stmt, 3, error)
            bind(stmt, 4, projectID)
            sqlite3_bind_int(stmt, 5, Int32(index))
        } else {
            sqlite3_prepare_v2(
                db,
                "UPDATE chunks SET status = ?, error_message = ? WHERE project_id = ? AND chunk_index = ?;",
                -1, &stmt, nil
            )
            bind(stmt, 1, status.rawValue)
            bind(stmt, 2, error)
            bind(stmt, 3, projectID)
            sqlite3_bind_int(stmt, 4, Int32(index))
        }
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }

    func chunks(projectID: String) -> [TextChunk] {
        lock.lock()
        defer { lock.unlock() }
        var rows: [TextChunk] = []
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(
            db,
            "SELECT chunk_index, page_number, original_text, clean_text, audio_path, status, error_message, chapter_index, chapter_title FROM chunks WHERE project_id = ? ORDER BY chunk_index ASC;",
            -1, &stmt, nil
        )
        bind(stmt, 1, projectID)
        while sqlite3_step(stmt) == SQLITE_ROW {
            let index = Int(sqlite3_column_int(stmt, 0))
            let page = Int(sqlite3_column_int(stmt, 1))
            let original = string(stmt, 2) ?? ""
            let clean = string(stmt, 3) ?? ""
            let audio = string(stmt, 4)
            let status = ChunkStatus(rawValue: string(stmt, 5) ?? "PENDING") ?? .pending
            let err = string(stmt, 6)
            let chapterIndex: Int? = sqlite3_column_type(stmt, 7) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 7))
            let chapterTitle = string(stmt, 8)
            rows.append(TextChunk(
                chunkIndex: index,
                pageNumber: page,
                originalText: original,
                cleanText: clean,
                audioPath: audio,
                status: status,
                errorMessage: err,
                chapterIndex: chapterIndex,
                chapterTitle: chapterTitle
            ))
        }
        sqlite3_finalize(stmt)
        return rows
    }

    func progress(projectID: String) -> ProjectProgress {
        lock.lock()
        defer { lock.unlock() }
        let total = count("SELECT COUNT(*) FROM chunks WHERE project_id = ?;", projectID)
        let done = count("SELECT COUNT(*) FROM chunks WHERE project_id = ? AND status = 'COMPLETED';", projectID)
        let failed = count("SELECT COUNT(*) FROM chunks WHERE project_id = ? AND status = 'FAILED';", projectID)
        return ProjectProgress(totalChunks: total, completedChunks: done, failedChunks: failed)
    }

    func setting(_ key: String, default defaultValue: String? = nil) -> String? {
        lock.lock()
        defer { lock.unlock() }
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "SELECT value FROM settings WHERE key = ?;", -1, &stmt, nil)
        bind(stmt, 1, key)
        var value: String?
        if sqlite3_step(stmt) == SQLITE_ROW {
            value = string(stmt, 0)
        }
        sqlite3_finalize(stmt)
        return value ?? defaultValue
    }

    func setSetting(_ key: String, _ value: String) {
        lock.lock()
        defer { lock.unlock() }
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?);", -1, &stmt, nil)
        bind(stmt, 1, key)
        bind(stmt, 2, value)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }

    // MARK: - helpers

    private func readProject(_ stmt: OpaquePointer?) -> ProjectRecord? {
        guard let id = string(stmt, 0) else { return nil }
        let engine = TTSEngineKind(rawValue: string(stmt, 6) ?? "edge") ?? .edge
        let format = AudioFormat(rawValue: string(stmt, 9) ?? "mp3") ?? .mp3
        let split = sqlite3_column_count(stmt) > 10 && sqlite3_column_int(stmt, 10) != 0
        return ProjectRecord(
            id: id,
            name: string(stmt, 1) ?? "",
            pdfPath: string(stmt, 2) ?? "",
            outputDir: string(stmt, 3) ?? "",
            createdAt: string(stmt, 4) ?? "",
            status: ProjectStatus(rawValue: string(stmt, 5) ?? "ACTIVE") ?? .active,
            engineType: engine,
            voiceID: string(stmt, 7) ?? "",
            rate: sqlite3_column_double(stmt, 8),
            formatExt: format,
            splitByChapter: split
        )
    }

    private func count(_ sql: String, _ projectID: String) -> Int {
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        bind(stmt, 1, projectID)
        var n = 0
        if sqlite3_step(stmt) == SQLITE_ROW {
            n = Int(sqlite3_column_int(stmt, 0))
        }
        sqlite3_finalize(stmt)
        return n
    }

    private func exec(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private func bind(_ stmt: OpaquePointer?, _ index: Int32, _ value: String?) {
        if let value {
            sqlite3_bind_text(stmt, index, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private func string(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
        guard let c = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: c)
    }

    private func lastError() -> String {
        String(cString: sqlite3_errmsg(db))
    }
}
