import Foundation
import AppKit
import AVFoundation
import SwiftUI
import Combine

@MainActor
final class StudioViewModel: ObservableObject {
    @Published var projects: [ProjectRecord] = []
    @Published var activeProject: ProjectRecord?
    @Published var batchQueue: [URL] = []

    @Published var pdfURL: URL?
    @Published var metadata: PDFMetadata?
    @Published var previewText = ""
    @Published var isScanned = false

    @Published var startPage = 1
    @Published var endPage = 1
    @Published var engine: TTSEngineKind = .edge
    @Published var voices: [VoiceOption] = VoiceCatalog.voices(for: .edge)
    @Published var selectedVoiceID: String = VoiceCatalog.edgeRecommended.first?.voiceID ?? ""
    @Published var rate: Double = 1.0
    @Published var format: AudioFormat = .mp3
    @Published var omitSymbols: Bool = true
    @Published var splitByChapter: Bool = true
    @Published var detectedChapters: [Chapter] = []
    @Published var outputDir: URL?

    @Published var progress: Int = 0
    @Published var statusText = "Listo para convertir"
    @Published var logs: [LogLine] = []

    @Published var isRunning = false
    @Published var isPaused = false
    @Published var isDark = true
    @Published var showSettings = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    @Published var showAlert = false
    @Published var showClearCacheConfirm = false
    @Published var clearCacheMessage = ""
    @Published var hasOpenAIKey = KeychainStore.openaiAPIKey != nil
    @Published var hasGrokKey = KeychainStore.xaiAPIKey != nil
    @Published var hasGoogleKey = KeychainStore.googleAPIKey != nil
    @Published var isPreviewing = false

    private let store = ProjectStore.shared
    private var extractor: PDFExtractor?
    private var control: JobControl?
    private var jobTask: Task<Void, Never>?
    private var previewPlayer: AVAudioPlayer?

    var selectedVoice: VoiceOption? {
        voices.first(where: { $0.voiceID == selectedVoiceID }) ?? voices.first
    }

    var canStart: Bool {
        pdfURL != nil && outputDir != nil && !isRunning && selectedVoice != nil
    }

    var visibleChapters: [Chapter] {
        ChapterDetector.clip(detectedChapters, startPage: startPage, endPage: endPage)
    }

    var chapterSummary: String {
        let visible = visibleChapters
        if visible.count >= 2 {
            return "\(visible.count) archivos · pág. \(visible.first!.startPage)–\(visible.last!.endPage)"
        }
        if detectedChapters.isEmpty {
            return "Sin índice estructurado. Si lo activas, se buscarán encabezados al convertir."
        }
        return "Ningún capítulo cae en el rango de páginas."
    }

    init() {
        reloadProjects()
        log("PDF Audiobook Studio nativo listo. Voces: Microsoft Neural, Grok TTS y OpenAI, no las de macOS.")
        if let saved = store.setting("theme") {
            isDark = saved != "light"
        }
        if let saved = store.setting("omit_symbols") {
            omitSymbols = saved != "false"
        }
        if let saved = store.setting("split_by_chapter") {
            splitByChapter = saved != "false"
        }
    }

    func persistSplitByChapter(_ value: Bool) {
        splitByChapter = value
        store.setSetting("split_by_chapter", value ? "true" : "false")
        if value {
            let n = visibleChapters.count
            log(n >= 2
                ? "Exportación por capítulos activada: \(n) archivos de audio."
                : "Exportación por capítulos activada. Se buscarán encabezados al convertir si el PDF no trae índice.")
        } else {
            log("Se exportará un único archivo de audio.")
        }
    }

    func persistOmitSymbols(_ value: Bool) {
        omitSymbols = value
        store.setSetting("omit_symbols", value ? "true" : "false")
        refreshPreview()
        log(value
            ? "Omitir símbolos activado. Elena no pronunciará asteriscos ni barras."
            : "Omitir símbolos desactivado. La voz leerá los símbolos del PDF.")
    }

    func toggleTheme() {
        isDark.toggle()
        store.setSetting("theme", isDark ? "dark" : "light")
        log(isDark ? "Tema oscuro." : "Tema claro.")
    }

    func reloadProjects() {
        projects = store.listProjects()
    }

    func openPDF() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Selecciona uno o varios PDFs para convertir en audiolibro"
        if panel.runModal() == .OK, !panel.urls.isEmpty {
            loadPDFBatch(panel.urls)
        }
    }

    func loadPDFBatch(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        
        // El primero se carga en la interfaz
        let first = urls[0]
        batchQueue = Array(urls.dropFirst())
        
        loadPDF(first)
        
        if !batchQueue.isEmpty {
            log("Lote detectado: \(batchQueue.count) PDF(s) en cola. Se procesarán automáticamente con la misma configuración.")
        }
    }

    func browseOutput() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Elegir"
        panel.message = "Carpeta de destino del audiolibro"
        if panel.runModal() == .OK, let url = panel.url {
            outputDir = url
            if let note = AppPaths.destinationNote(for: url) {
                log(note)
            }
        }
    }

    func loadPDF(_ url: URL) {
        do {
            let extractor = try PDFExtractor(url: url)
            self.extractor = extractor
            self.pdfURL = url
            let meta = extractor.metadata()
            metadata = meta
            isScanned = meta.isScanned
            startPage = 1
            endPage = meta.pageCount
            if outputDir == nil {
                outputDir = url.deletingLastPathComponent()
            }

            refreshPreview()
            detectedChapters = ChapterDetector.detect(from: extractor)
            if detectedChapters.count >= 2 {
                if store.setting("split_by_chapter") != "false" {
                    splitByChapter = true
                }
                let first = detectedChapters[0]
                let last = detectedChapters[detectedChapters.count - 1]
                log("Índice: \(detectedChapters.count) partes/capítulos (pág. \(first.startPage)–\(last.endPage)).")
                if first.startPage > 1 {
                    log("Las páginas 1–\(first.startPage - 1) (portada/índice impreso) no se leen.")
                }
            } else {
                detectedChapters = []
                log("Este PDF no tiene un índice de capítulos reconocible. Se puede exportar un solo archivo.")
            }

            log("PDF «\(meta.name)» cargado · \(meta.pageCount) páginas · \(meta.fileSizeMB) MB")
            if meta.isScanned {
                log("Parece un PDF escaneado. Se activará OCR de Vision al convertir.")
            }
        } catch {
            present("Error de lectura", error.localizedDescription)
        }
    }

    func engineChanged(_ new: TTSEngineKind) {
        engine = new
        voices = VoiceCatalog.voices(for: new)
        selectedVoiceID = voices.first?.voiceID ?? ""
        if new == .openai && !hasOpenAIKey {
            log("OpenAI TTS necesita una API key. Ábrela en Ajustes.")
            showSettings = true
        }
        if new == .grok && !hasGrokKey {
            log("Grok TTS necesita una API key de console.x.ai. Ábrela en Ajustes.")
            showSettings = true
        }
        if new == .google && !hasGoogleKey {
            log("Google AI Pro / Cloud TTS necesita una API key. Ábrela en Ajustes.")
            showSettings = true
        }
    }

    func loadProject(_ project: ProjectRecord) {
        let url = URL(fileURLWithPath: project.pdfPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            present("Archivo no encontrado", "El PDF original ya no existe:\n\(project.pdfPath)")
            return
        }
        loadPDF(url)
        batchQueue = []
        activeProject = project
        outputDir = URL(fileURLWithPath: project.outputDir)
        engineChanged(project.engineType)
        selectedVoiceID = project.voiceID
        rate = project.rate
        format = project.formatExt
        splitByChapter = project.splitByChapter
        let prog = store.progress(projectID: project.id)
        progress = Int(prog.percentage)
        statusText = "Proyecto reanudado (\(prog.completedChunks)/\(prog.totalChunks) bloques)"
        log("Proyecto «\(project.name)» cargado desde la base de datos.")
        let missing = store.chunks(projectID: project.id).filter { chunk in
            guard chunk.status == .completed, let path = chunk.audioPath, !path.isEmpty else { return false }
            return !FileManager.default.fileExists(atPath: path)
        }.count
        if missing > 0 {
            log(
                "Faltan \(missing) bloques de audio en disco. Al pulsar Iniciar se vuelven a sintetizar; el PDF no se relee. No borres la caché a mitad de un trabajo.",
                error: true
            )
        }
        if let note = AppPaths.destinationNote(for: URL(fileURLWithPath: project.outputDir)) {
            log(note)
        }
    }

    func startConversion() {
        guard let pdfURL, let extractor, let outputDir, let voice = selectedVoice else { return }
        if engine == .openai && KeychainStore.openaiAPIKey == nil {
            present("API key", "OpenAI TTS requiere una API key. Guárdala en Ajustes.")
            showSettings = true
            return
        }
        if engine == .grok && KeychainStore.xaiAPIKey == nil {
            present("API key", "Grok TTS requiere una API key de console.x.ai. Guárdala en Ajustes.")
            showSettings = true
            return
        }
        if engine == .google && KeychainStore.googleAPIKey == nil {
            present("API key", "Google AI Pro / Cloud TTS requiere una API key de Google (Google AI Studio o Google Cloud). Guárdala en Ajustes.")
            showSettings = true
            return
        }

        let start0 = startPage - 1
        let end0 = endPage - 1
        guard start0 <= end0 else {
            present("Rango", "La página inicial no puede ser mayor que la final.")
            return
        }

        isRunning = true
        isPaused = false
        let control = JobControl()
        self.control = control

        if let note = AppPaths.destinationNote(for: outputDir) {
            log(note)
        }
        AppLog.write("Start conversion \(pdfURL.lastPathComponent) format=\(format.rawValue) split=\(splitByChapter) dest=\(outputDir.path)")

        let engineKind = engine
        let rateValue = rate
        let formatValue = format
        let useOCR = isScanned
        let omitSymbolsValue = omitSymbols
        var splitValue = splitByChapter
        let existingProject = (activeProject?.pdfPath == pdfURL.path) ? activeProject : nil
        if let existingProject {
            splitValue = existingProject.splitByChapter
        }
        let store = self.store
        let stem = pdfURL.deletingPathExtension().lastPathComponent
        let voiceID = voice.voiceID
        let knownChapters = visibleChapters

        jobTask = Task { [weak self] in
            guard let self else { return }
            do {
                let project: ProjectRecord
                if let existingProject {
                    project = existingProject
                    await MainActor.run { self.log("Reanudando bloques ya registrados…") }
                } else {
                    await MainActor.run { self.log("Extrayendo páginas y agrupando texto…") }
                    let pages = try await extractor.extractRange(
                        from: start0,
                        to: end0,
                        useOCR: useOCR
                    ) { current, total in
                        Task { @MainActor in
                            self.statusText = "Extrayendo página \(current) de \(total)…"
                        }
                    }
                    var chapters = knownChapters
                    var split = splitValue
                    if split && chapters.count < 2 {
                        chapters = ChapterDetector.fromPageTexts(pages, totalPages: extractor.pageCount)
                        chapters = ChapterDetector.clip(chapters, startPage: start0 + 1, endPage: end0 + 1)
                    }
                    if split && chapters.count < 2 {
                        split = false
                        await MainActor.run {
                            self.log("No se encontraron capítulos. Se exportará un único archivo.")
                        }
                    }

                    var chunks: [TextChunk] = []
                    if split {
                        for (chapterIndex, chapter) in chapters.enumerated() {
                            let slice = pages.filter {
                                let page1 = $0.pageNum0 + 1
                                return page1 >= chapter.startPage && page1 <= chapter.endPage
                            }
                            let part = TextChunker.chunk(pages: slice, maxChars: 1800, omitSymbols: omitSymbolsValue)
                            if part.isEmpty {
                                await MainActor.run {
                                    self.log("Sin texto sintetizable en «\(chapter.title)»; se omite.")
                                }
                                continue
                            }
                            for item in part {
                                chunks.append(TextChunk(
                                    chunkIndex: chunks.count,
                                    pageNumber: item.pageNumber,
                                    originalText: item.originalText,
                                    cleanText: item.cleanText,
                                    audioPath: nil,
                                    status: .pending,
                                    errorMessage: nil,
                                    chapterIndex: chapterIndex,
                                    chapterTitle: chapter.title
                                ))
                            }
                        }
                        await MainActor.run {
                            self.log("Texto agrupado en \(chapters.count) capítulos (\(chunks.count) bloques).")
                        }
                    } else {
                        chunks = TextChunker.chunk(pages: pages, maxChars: 1800, omitSymbols: omitSymbolsValue)
                    }
                    if omitSymbolsValue {
                        await MainActor.run {
                            self.log("Símbolos omitidos en el texto: Elena no pronunciará asterisco, barra ni almohadilla.")
                        }
                    }
                    guard !chunks.isEmpty else {
                        await MainActor.run {
                            self.isRunning = false
                            self.present("Sin texto", "El rango seleccionado no contiene texto para sintetizar.")
                        }
                        return
                    }
                    let created = store.createProject(
                        name: "Audiolibro_\(stem)",
                        pdfPath: pdfURL.path,
                        outputDir: outputDir.path,
                        engine: engineKind,
                        voiceID: voiceID,
                        rate: rateValue,
                        format: formatValue,
                        splitByChapter: split
                    )
                    store.addChunks(projectID: created.id, chunks: chunks)
                    await MainActor.run {
                        self.activeProject = created
                        self.reloadProjects()
                    }
                    project = created
                }

                let destination = project.splitByChapter
                    ? outputDir.appendingPathComponent("\(stem)_audiolibro", isDirectory: true)
                    : outputDir.appendingPathComponent("\(stem)_audiolibro.\(formatValue.fileExtension)")
                let request = ConversionRequest(
                    projectID: project.id,
                    engine: engineKind,
                    voiceID: voiceID,
                    rate: rateValue,
                    format: formatValue,
                    outputFile: destination,
                    omitSymbols: omitSymbolsValue,
                    splitByChapter: project.splitByChapter
                )

                await ConversionRunner.run(request: request, store: store, control: control) { event in
                    Task { @MainActor in
                        self.handle(event)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isRunning = false
                    self.present("Error", error.localizedDescription)
                }
            }
        }
    }

    func pause() {
        let control = control
        Task { await control?.pause() }
        isPaused = true
        statusText = "Conversión pausada."
        log("Conversión pausada.")
    }

    func resume() {
        let control = control
        Task { await control?.resume() }
        isPaused = false
        statusText = "Reanudando conversión…"
        log("Reanudando.")
    }

    func cancel() {
        let control = control
        Task { await control?.cancel() }
        jobTask?.cancel()
        isPaused = false
        statusText = "Cancelando…"
        log("Cancelando conversión…")
    }

    func openOutputFolder() {
        guard let outputDir else { return }
        NSWorkspace.shared.open(outputDir)
    }

    func requestClearCache() {
        let n = AppPaths.cachedAudioCount()
        if n == 0 {
            performClearCache()
            return
        }
        clearCacheMessage = """
        Hay \(n) archivos de audio en la caché. Si un libro largo falló al copiarse al USB, estos bloques SON el trabajo de todo el día. Borrarlos obliga a sintetizar otra vez.
        """
        showClearCacheConfirm = true
    }

    func performClearCache() {
        do {
            try AppPaths.clearCache()
            log("Caché temporal limpiada.")
            present("Caché", "La carpeta de bloques temporales se vació.")
            AppLog.write("Cache cleared by user.")
        } catch {
            present("Caché", error.localizedDescription)
        }
    }

    func previewVoice() {
        guard let voice = selectedVoice else { return }
        if engine == .openai && KeychainStore.openaiAPIKey == nil {
            showSettings = true
            return
        }
        if engine == .grok && KeychainStore.xaiAPIKey == nil {
            showSettings = true
            return
        }
        if engine == .google && (KeychainStore.googleAPIKey?.isEmpty ?? true) {
            showSettings = true
            return
        }
        isPreviewing = true
        let sample = VoiceCatalog.sampleText(for: voice)
        let dest = AppPaths.cache.appendingPathComponent("preview_\(voice.voiceID).mp3")
        let engineKind = engine
        let rate = rate
        Task {
            do {
                let tts = TTSFactory.engine(for: engineKind)
                try await tts.synthesize(text: sample, voiceID: voice.voiceID, rate: rate, to: dest)
                await MainActor.run {
                    self.play(url: dest)
                    self.isPreviewing = false
                    self.log("Previsualización de \(voice.name).")
                }
            } catch {
                await MainActor.run {
                    self.isPreviewing = false
                    self.present("Previsualización", error.localizedDescription)
                }
            }
        }
    }

    func deleteProject(_ project: ProjectRecord) {
        store.deleteProject(id: project.id)
        if activeProject?.id == project.id { activeProject = nil }
        reloadProjects()
    }

    func refreshKeyFlag() {
        hasOpenAIKey = KeychainStore.openaiAPIKey != nil
        hasGrokKey = KeychainStore.xaiAPIKey != nil
        hasGoogleKey = KeychainStore.googleAPIKey != nil
    }

    private func play(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            guard !data.isEmpty else {
                throw StudioError.audio("El archivo de audio está vacío.")
            }
            if data.prefix(4) == Data("RIFF".utf8) {
                previewPlayer = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue)
            } else if data.prefix(3) == Data("ID3".utf8) || (data.count > 1 && data[0] == 0xFF && (data[1] & 0xE0) == 0xE0) {
                previewPlayer = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.mp3.rawValue)
            } else if data.count >= 8 && data.subdata(in: 4..<8) == Data("ftyp".utf8) {
                previewPlayer = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.m4a.rawValue)
            } else {
                previewPlayer = try AVAudioPlayer(contentsOf: url)
            }
            previewPlayer?.prepareToPlay()
            previewPlayer?.play()
        } catch {
            present("Reproducción", error.localizedDescription)
        }
    }

    private func handle(_ event: ConversionEvent) {
        switch event {
        case .status(let s):
            statusText = s
            log(s)
        case .progress(let p):
            progress = p
        case .chunkDone(let i, _):
            log("Bloque \(i + 1) sintetizado.")
        case .chunkError(let source, let msg):
            log("⚠️ ERROR en \(source): \(msg)", error: true)
        case .finished(let ok, let msg):
            isRunning = false
            isPaused = false
            control = nil
            jobTask = nil
            reloadProjects()
            AppLog.write("Finished ok=\(ok) \(msg)")
            if ok {
                activeProject = nil
                progress = 100
                statusText = "Completado"
                log("Proceso finalizado para este documento. Todo el audio ha sido ensamblado.")
                
                if !batchQueue.isEmpty {
                    let nextPDF = batchQueue.removeFirst()
                    log("Iniciando el siguiente documento en la cola: \(nextPDF.lastPathComponent)")
                    loadPDF(nextPDF)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.startConversion()
                    }
                } else {
                    log(msg)
                    present("Conversión completada", msg)
                }
            } else {
                statusText = "Incompleto"
                log(msg, error: true)
                log("El proyecto sigue cargado. Pulsa Iniciar para reanudar; no borres la caché.", error: true)
                present("Conversión incompleta", msg)
            }
        }
    }

    func refreshPreview() {
        guard let extractor, let meta = metadata else { return }
        var preview = ""
        for i in 0..<min(meta.pageCount, 2) {
            preview += "--- PÁGINA \(i + 1) ---\n"
            preview += TextCleaner.clean(
                extractor.extractPageText(pageIndex: i),
                omitSymbols: omitSymbols
            ) + "\n\n"
        }
        let trimmed = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        previewText = trimmed.isEmpty
            ? "[Sin texto extraíble en las primeras páginas. Si es un escaneo, se usará OCR al convertir.]"
            : trimmed
    }

    func log(_ message: String, error: Bool = false) {
        logs.append(LogLine(message: message, isError: error))
        if logs.count > 400 { logs.removeFirst(logs.count - 400) }
        AppLog.write(error ? "ERROR \(message)" : message)
    }

    func present(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}
