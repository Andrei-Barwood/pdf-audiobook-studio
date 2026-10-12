import Foundation

actor JobControl {
    private var paused = false
    private var cancelled = false
    private var waiter: CheckedContinuation<Void, Never>?

    var isCancelled: Bool { cancelled }

    func pause() {
        paused = true
    }

    func resume() {
        paused = false
        let waiter = self.waiter
        self.waiter = nil
        waiter?.resume()
    }

    func cancel() {
        cancelled = true
        paused = false
        let waiter = self.waiter
        self.waiter = nil
        waiter?.resume()
    }

    func waitIfPaused() async {
        if cancelled || !paused { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            if cancelled || !paused {
                cont.resume()
            } else {
                waiter = cont
            }
        }
        if paused && !cancelled {
            await waitIfPaused()
        }
    }
}

struct ConversionRequest: Sendable {
    let projectID: String
    let engine: TTSEngineKind
    let voiceID: String
    let rate: Double
    let format: AudioFormat
    let outputFile: URL
    let omitSymbols: Bool
    let splitByChapter: Bool
}

enum ConversionEvent: Sendable {
    case status(String)
    case progress(Int)
    case chunkDone(Int, URL)
    case chunkError(String, String)
    case finished(Bool, String)
}

enum ConversionRunner {
    static func run(
        request: ConversionRequest,
        store: ProjectStore,
        control: JobControl,
        emit: @escaping @Sendable (ConversionEvent) -> Void
    ) async {
        emit(.status("Iniciando conversión..."))
        let engine = TTSFactory.engine(for: request.engine)
        let chunks = store.chunks(projectID: request.projectID)
        guard !chunks.isEmpty else {
            emit(.chunkError("General", "No hay bloques de texto para procesar."))
            emit(.finished(false, "Sin bloques"))
            return
        }

        var completed: [URL?] = Array(repeating: nil, count: chunks.count)
        let total = chunks.count

        do {
            for chunk in chunks {
                if await control.isCancelled {
                    store.updateStatus(projectID: request.projectID, status: .failed)
                    emit(.finished(false, "Conversión cancelada por el usuario."))
                    return
                }
                await control.waitIfPaused()
                if await control.isCancelled {
                    store.updateStatus(projectID: request.projectID, status: .failed)
                    emit(.finished(false, "Conversión cancelada por el usuario."))
                    return
                }

                // Neural engines emit MP3. Naming chunks .m4a made AVFoundation
                // refuse to open them after a full-day synthesis ("can't open").
                let dest = AppPaths.chunkURL(projectID: request.projectID, index: chunk.chunkIndex, format: .mp3)
                let spoken = request.omitSymbols
                    ? TextCleaner.omitSpokenSymbols(chunk.cleanText)
                    : chunk.cleanText
                let cacheMatchesSpoken = !request.omitSymbols || spoken == chunk.cleanText
                if cacheMatchesSpoken,
                   chunk.status == .completed,
                   let cached = chunk.audioPath,
                   FileManager.default.fileExists(atPath: cached),
                   (try? FileManager.default.attributesOfItem(atPath: cached)[.size] as? NSNumber)?.intValue ?? 0 > 0 {
                    completed[chunk.chunkIndex] = URL(fileURLWithPath: cached)
                    let pct = Int(Double(chunk.chunkIndex + 1) / Double(total) * 100)
                    emit(.progress(pct))
                    emit(.chunkDone(chunk.chunkIndex, URL(fileURLWithPath: cached)))
                    continue
                }

                if let chapter = chunk.chapterTitle, !chapter.isEmpty {
                    emit(.status("Sintetizando bloque \(chunk.chunkIndex + 1) de \(total) · \(chapter) (pág. \(chunk.pageNumber))…"))
                } else {
                    emit(.status("Sintetizando bloque \(chunk.chunkIndex + 1) de \(total) (pág. \(chunk.pageNumber))…"))
                }
                store.updateChunk(projectID: request.projectID, index: chunk.chunkIndex, status: .processing)

                var success = false
                var lastError = ""
                for attempt in 1...3 {
                    if await control.isCancelled { break }
                    do {
                        try await engine.synthesize(
                            text: spoken,
                            voiceID: request.voiceID,
                            rate: request.rate,
                            to: dest
                        )
                        success = true
                        break
                    } catch {
                        lastError = error.localizedDescription
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        _ = attempt
                    }
                }

                if await control.isCancelled {
                    store.updateStatus(projectID: request.projectID, status: .failed)
                    emit(.finished(false, "Conversión cancelada por el usuario."))
                    return
                }

                if success {
                    store.updateChunk(
                        projectID: request.projectID,
                        index: chunk.chunkIndex,
                        status: .completed,
                        audioPath: dest.path
                    )
                    completed[chunk.chunkIndex] = dest
                    emit(.chunkDone(chunk.chunkIndex, dest))
                } else {
                    store.updateChunk(
                        projectID: request.projectID,
                        index: chunk.chunkIndex,
                        status: .failed,
                        error: lastError
                    )
                    emit(.chunkError("Bloque \(chunk.chunkIndex + 1) (pág. \(chunk.pageNumber))", lastError))
                }

                let pct = Int(Double(chunk.chunkIndex + 1) / Double(total) * 100)
                emit(.progress(pct))
            }

            let segments = completed.compactMap { $0 }
            guard !segments.isEmpty else {
                throw StudioError.audio("Todos los bloques fallaron. No hay audio que unir.")
            }

            let failed = total - segments.count
            if request.splitByChapter {
                try FileManager.default.createDirectory(at: request.outputFile, withIntermediateDirectories: true)
                var order: [Int] = []
                var titles: [Int: String] = [:]
                var groups: [Int: [URL]] = [:]
                for chunk in chunks {
                    let chapterIdx = chunk.chapterIndex ?? 0
                    if titles[chapterIdx] == nil {
                        order.append(chapterIdx)
                        titles[chapterIdx] = chunk.chapterTitle ?? "Capítulo \(chapterIdx + 1)"
                    }
                    if let url = completed[chunk.chunkIndex] {
                        groups[chapterIdx, default: []].append(url)
                    }
                }
                let nonempty = order.filter { !(groups[$0]?.isEmpty ?? true) }
                guard !nonempty.isEmpty else {
                    throw StudioError.audio("No hay audio que agrupar por capítulo.")
                }
                var created: [URL] = []
                var chapterErrors: [String] = []
                for (i, chapterIdx) in nonempty.enumerated() {
                    if await control.isCancelled {
                        store.updateStatus(projectID: request.projectID, status: .failed)
                        let note = created.isEmpty
                            ? "Conversión cancelada por el usuario."
                            : "Cancelado. \(created.count) capítulos ya están en \(request.outputFile.path)"
                        emit(.finished(false, note))
                        return
                    }
                    let title = titles[chapterIdx] ?? "Capítulo \(chapterIdx + 1)"
                    let paths = groups[chapterIdx] ?? []
                    emit(.status("Exportando \(i + 1)/\(nonempty.count): \(title)…"))
                    AppLog.write("Export chapter \(i + 1)/\(nonempty.count) \(title) (\(paths.count) bloques)")
                    let name = ChapterDetector.filename(
                        index: i + 1,
                        title: title,
                        total: nonempty.count,
                        format: request.format
                    )
                    let dest = request.outputFile.appendingPathComponent(name)
                    do {
                        try await AudioBuilder.merge(paths: paths, output: dest, format: request.format)
                        created.append(dest)
                    } catch {
                        let msg = error.localizedDescription
                        chapterErrors.append("\(title): \(msg)")
                        emit(.chunkError("Capítulo \(title)", msg))
                        AppLog.write("Chapter export failed: \(title) — \(msg)")
                    }
                }
                if created.isEmpty {
                    store.updateStatus(projectID: request.projectID, status: .failed)
                    throw StudioError.audio(
                        chapterErrors.first ?? "No se pudo exportar ningún capítulo. La caché de bloques no se borra: no pulses «Limpiar caché»."
                    )
                }
                store.updateStatus(
                    projectID: request.projectID,
                    status: chapterErrors.isEmpty ? .completed : .failed
                )
                let omitted = failed > 0 ? " (\(failed) bloques omitidos)." : ""
                let failedCh = chapterErrors.isEmpty
                    ? ""
                    : " Fallaron \(chapterErrors.count): \(chapterErrors.prefix(3).joined(separator: " | "))."
                emit(.finished(
                    chapterErrors.isEmpty,
                    "\(created.count) archivos de audio en \(request.outputFile.path)\(omitted)\(failedCh)"
                ))
                return
            }

            emit(.status("Uniendo archivos de audio…"))
            try await AudioBuilder.merge(paths: segments, output: request.outputFile, format: request.format)
            store.updateStatus(projectID: request.projectID, status: .completed)

            if failed > 0 {
                emit(.finished(true, "Audiolibro creado en \(request.outputFile.path) (\(failed) bloques omitidos)."))
            } else {
                emit(.finished(true, "Audiolibro creado con éxito en \(request.outputFile.path)"))
            }
        } catch is CancellationError {
            store.updateStatus(projectID: request.projectID, status: .failed)
            emit(.finished(false, "Conversión cancelada."))
        } catch {
            store.updateStatus(projectID: request.projectID, status: .failed)
            emit(.chunkError("General", error.localizedDescription))
            emit(.finished(false, error.localizedDescription))
        }
    }
}
