import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var model: StudioViewModel

    var body: some View {
        HStack(spacing: 14) {
            SidebarView()
                .frame(width: 230)

            VStack(spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    ConfigPanel()
                    PreviewPanel()
                }
                ProgressPanel()
                LogTerminal()
                    .frame(minHeight: 110, maxHeight: 160)
            }
        }
        .padding(16)
        .background(Palette.bg(model.isDark).ignoresSafeArea())
        .preferredColorScheme(model.isDark ? .dark : .light)
        .alert(model.alertTitle, isPresented: $model.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.alertMessage)
        }
        .alert("¿Borrar la caché de audio?", isPresented: $model.showClearCacheConfirm) {
            Button("Borrar", role: .destructive) { model.performClearCache() }
            Button("Conservar", role: .cancel) {}
        } message: {
            Text(model.clearCacheMessage)
        }
        .sheet(isPresented: $model.showSettings) {
            SettingsView()
                .environmentObject(model)
        }
        .onDrop(of: [UTType.pdf], isTargeted: nil) { providers in
            handleDrop(providers)
        }
        .onAppear {
            NSApp.appearance = NSAppearance(named: model.isDark ? .darkAqua : .aqua)
        }
        .onChange(of: model.isDark) { _, dark in
            NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }
        
        let group = DispatchGroup()
        var urls: [URL] = []
        
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { item, _ in
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                } else if let u = item as? URL {
                    urls.append(u)
                } else if let u = item as? NSURL {
                    urls.append(u as URL)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if !urls.isEmpty {
                model.loadPDFBatch(urls)
            }
        }
        return true
    }
}

struct SidebarView: View {
    @EnvironmentObject var model: StudioViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Proyectos recientes")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.accent)

            if model.projects.isEmpty {
                Text("Aún no hay proyectos.\nConvierte un PDF para empezar.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted(model.isDark))
                    .padding(.top, 8)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(model.projects) { project in
                            projectRow(project)
                        }
                    }
                }
            }

            Button("Limpiar caché temporal") {
                model.requestClearCache()
            }
            .buttonStyle(StudioButtonStyle(kind: .secondary, dark: model.isDark))
            .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .studioCard(dark: model.isDark)
    }

    private func projectRow(_ project: ProjectRecord) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(project.name)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(Palette.text(model.isDark))
            Text("\(project.status.rawValue) · \(project.createdAt.prefix(10))")
                .font(.system(size: 10))
                .foregroundStyle(Palette.muted(model.isDark))
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(model.activeProject?.id == project.id ? Palette.accent.opacity(0.18) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { model.loadProject(project) }
        .contextMenu {
            Button("Cargar") { model.loadProject(project) }
            Button("Eliminar", role: .destructive) { model.deleteProject(project) }
        }
    }
}

struct ConfigPanel: View {
    @EnvironmentObject var model: StudioViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                Text("PDF Audiobook Studio")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Palette.text(model.isDark))
                Spacer()
                Button(model.isDark ? "Tema claro" : "Tema oscuro") {
                    model.toggleTheme()
                }
                .buttonStyle(StudioButtonStyle(kind: .secondary, dark: model.isDark))
                Button("Ajustes") { model.showSettings = true }
                    .buttonStyle(StudioButtonStyle(kind: .secondary, dark: model.isDark))
            }

            DropZone()

            if let meta = model.metadata {
                metaGrid(meta)
            }

            Text("Configuración de conversión")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.accent)

            formRow("Rango de páginas") {
                HStack(spacing: 8) {
                    Text("Desde").foregroundStyle(Palette.muted(model.isDark))
                    Stepper(value: $model.startPage, in: 1...max(model.endPage, 1)) {
                        Text("\(model.startPage)").frame(minWidth: 36)
                    }
                    .disabled(model.metadata == nil || model.isRunning)
                    Text("Hasta").foregroundStyle(Palette.muted(model.isDark))
                    Stepper(value: $model.endPage, in: model.startPage...max(model.metadata?.pageCount ?? 1, 1)) {
                        Text("\(model.endPage)").frame(minWidth: 36)
                    }
                    .disabled(model.metadata == nil || model.isRunning)
                }
            }

            Toggle(isOn: $model.splitByChapter) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Un archivo por capítulo")
                        .foregroundStyle(Palette.text(model.isDark))
                    Text(model.chapterSummary)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted(model.isDark))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.checkbox)
            .disabled(model.isRunning || model.metadata == nil)
            .onChange(of: model.splitByChapter) { _, value in
                model.persistSplitByChapter(value)
            }

            if model.splitByChapter && !model.visibleChapters.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(model.visibleChapters.enumerated()), id: \.element.id) { index, chapter in
                            Text("\(String(format: "%02d", index + 1)).  \(chapter.pageLabel)  \(chapter.title)")
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.text(model.isDark))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                }
                .frame(maxHeight: 120)
                .padding(8)
                .background(Palette.field(model.isDark))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            formRow("Motor de voz") {
                Picker("", selection: $model.engine) {
                    ForEach(TTSEngineKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .labelsHidden()
                .disabled(model.isRunning)
                .onChange(of: model.engine) { _, new in
                    model.engineChanged(new)
                }
            }

            Text(model.engine.subtitle)
                .font(.system(size: 11))
                .foregroundStyle(Palette.muted(model.isDark))
                .fixedSize(horizontal: false, vertical: true)

            formRow("Voz") {
                Picker("", selection: $model.selectedVoiceID) {
                    ForEach(model.voices) { voice in
                        Text("\(voice.localeFlag)  \(voice.name)").tag(voice.voiceID)
                    }
                }
                .labelsHidden()
                .disabled(model.isRunning)
            }

            if let voice = model.selectedVoice {
                Text(voice.hint)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted(model.isDark))
            }

            Toggle(isOn: $model.omitSymbols) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Omitir símbolos")
                        .foregroundStyle(Palette.text(model.isDark))
                    Text("Evita que Elena y otras voces de Edge pronuncien asterisco, barra, almohadilla…")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted(model.isDark))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.checkbox)
            .disabled(model.isRunning)
            .onChange(of: model.omitSymbols) { _, value in
                model.persistOmitSymbols(value)
            }

            formRow("Velocidad") {
                Picker("", selection: $model.rate) {
                    ForEach(SpeedOption.all) { opt in
                        Text(opt.label).tag(opt.id)
                    }
                }
                .labelsHidden()
                .disabled(model.isRunning)
            }

            formRow("Formato") {
                Picker("", selection: $model.format) {
                    ForEach(AudioFormat.allCases) { fmt in
                        Text(fmt.displayName).tag(fmt)
                    }
                }
                .labelsHidden()
                .disabled(model.isRunning)
            }

            formRow("Destino") {
                HStack {
                    Text(model.outputDir?.path ?? "Carpeta de salida…")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(model.outputDir == nil ? Palette.muted(model.isDark) : Palette.text(model.isDark))
                    Spacer()
                    Button("Buscar") { model.browseOutput() }
                        .buttonStyle(StudioButtonStyle(kind: .secondary, dark: model.isDark))
                }
            }

            HStack {
                Button(model.isPreviewing ? "Generando muestra…" : "Probar voz") {
                    model.previewVoice()
                }
                .buttonStyle(StudioButtonStyle(kind: .secondary, dark: model.isDark, enabled: !model.isPreviewing))
                .disabled(model.isPreviewing || model.selectedVoice == nil)

                if model.engine == .openai && !model.hasOpenAIKey {
                    Text("Falta API key de OpenAI")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.orange)
                }
                if model.engine == .grok && !model.hasGrokKey {
                    Text("Falta API key de Grok (xAI)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.orange)
                }
            }

            Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .studioCard(dark: model.isDark)
    }

    private func metaGrid(_ meta: PDFMetadata) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            metaRow("Archivo", meta.name)
            metaRow("Páginas", "\(meta.pageCount)")
            metaRow("Tamaño", String(format: "%.2f MB", meta.fileSizeMB))
            metaRow("OCR", meta.isScanned ? "SÍ (probablemente escaneado)" : "NO (texto extraíble)")
        }
        .font(.system(size: 12))
    }

    private func metaRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k + ":").foregroundStyle(Palette.muted(model.isDark)).frame(width: 90, alignment: .leading)
            Text(v).foregroundStyle(Palette.text(model.isDark)).lineLimit(1)
        }
    }

    private func formRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.muted(model.isDark))
            content()
        }
    }
}

struct PreviewPanel: View {
    @EnvironmentObject var model: StudioViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.omitSymbols ? "Vista previa del texto que escuchará la voz" : "Vista previa del texto extraído")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.accent)
            TextEditor(text: .constant(model.previewText))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Palette.text(model.isDark))
                .scrollContentBackground(.hidden)
                .background(Palette.field(model.isDark))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    Group {
                        if model.previewText.isEmpty {
                            Text("El texto de las primeras páginas aparecerá aquí.")
                                .foregroundStyle(Palette.muted(model.isDark))
                                .padding(10)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                    }
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .studioCard(dark: model.isDark)
    }
}

struct ProgressPanel: View {
    @EnvironmentObject var model: StudioViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(model.statusText)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.text(model.isDark))
                Spacer()
                Text("\(model.progress)%")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.accent)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Palette.field(model.isDark))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Palette.accentDeep, Palette.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * CGFloat(model.progress) / 100))
                }
            }
            .frame(height: 12)

            HStack(spacing: 8) {
                Button("Iniciar conversión") { model.startConversion() }
                    .buttonStyle(StudioButtonStyle(kind: .primary, dark: model.isDark, enabled: model.canStart && !model.isRunning))
                    .disabled(!model.canStart || model.isRunning)

                Button("Pausar") { model.pause() }
                    .buttonStyle(StudioButtonStyle(kind: .secondary, dark: model.isDark, enabled: model.isRunning && !model.isPaused))
                    .disabled(!model.isRunning || model.isPaused)

                Button("Reanudar") { model.resume() }
                    .buttonStyle(StudioButtonStyle(kind: .secondary, dark: model.isDark, enabled: model.isRunning && model.isPaused))
                    .disabled(!(model.isRunning && model.isPaused))

                Button("Cancelar") { model.cancel() }
                    .buttonStyle(StudioButtonStyle(kind: .danger, dark: model.isDark, enabled: model.isRunning))
                    .disabled(!model.isRunning)

                Button("Abrir carpeta") { model.openOutputFolder() }
                    .buttonStyle(StudioButtonStyle(kind: .secondary, dark: model.isDark, enabled: model.outputDir != nil))
                    .disabled(model.outputDir == nil)
            }
        }
        .studioCard(dark: model.isDark)
    }
}

struct LogTerminal: View {
    @EnvironmentObject var model: StudioViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(model.logs) { line in
                        Text(line.stamped)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(line.isError ? Color.orange : Palette.muted(model.isDark))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                    }
                }
                .padding(10)
            }
            .background(Palette.field(model.isDark))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Palette.border(model.isDark), lineWidth: 1)
            )
            .onChange(of: model.logs.count) { _, _ in
                if let last = model.logs.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}

struct DropZone: View {
    @EnvironmentObject var model: StudioViewModel
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 28))
                .foregroundStyle(Palette.accent)
            Text("Arrastra un PDF aquí\no haz clic para seleccionarlo")
                .multilineTextAlignment(.center)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.muted(model.isDark))
            if let name = model.metadata?.name {
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.text(model.isDark))
                if !model.batchQueue.isEmpty {
                    Text("(+ \(model.batchQueue.count) en cola)")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted(model.isDark))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(hovering ? Palette.accent.opacity(0.12) : Palette.field(model.isDark))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Palette.accentDeep, style: StrokeStyle(lineWidth: 2, dash: [7]))
        )
        .contentShape(Rectangle())
        .onTapGesture { model.openPDF() }
        .onDrop(of: [UTType.pdf], isTargeted: $hovering) { providers in
            guard !providers.isEmpty else { return false }
            
            let group = DispatchGroup()
            var urls: [URL] = []
            
            for provider in providers {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { item, _ in
                    if let url = item as? URL {
                        urls.append(url)
                    } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        urls.append(url)
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                if !urls.isEmpty {
                    model.loadPDFBatch(urls)
                }
            }
            return true
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var model: StudioViewModel
    @State private var googleKey: String = KeychainStore.googleAPIKey ?? ""
    @State private var openaiKey: String = KeychainStore.openaiAPIKey ?? ""
    @State private var xaiKey: String = KeychainStore.xaiAPIKey ?? ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ajustes")
                .font(.title2.bold())
            Text("Esta app no usa las voces de macOS (suenan robóticas y con curva fija). Usa voces neuronales de Microsoft Edge de forma gratuita, Google AI / Cloud TTS (voces Journey, Studio y Gemini), Grok TTS (xAI) u OpenAI.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                VStack(spacing: 14) {
                    GroupBox("Google AI Pro / Cloud TTS 👑 (Voces Hermosas de Google)") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API key de Google (Google AI Studio / Cloud)")
                                .font(.caption.bold())
                            SecureField("AIzaSy…", text: $googleKey)
                                .textFieldStyle(.roundedBorder)
                            Text("Con tu cuenta Google AI Pro (andrewvkaamo@gmail.com) obtienes acceso a las voces Journey (estilo princesa y narrativa dulce), Studio (alta fidelidad) y Gemini (Kore, Aoede, Leda...).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 16) {
                                Link("Obtener API Key en Google AI Studio ↗", destination: URL(string: "https://aistudio.google.com/apikey")!)
                                    .font(.caption)
                                Link("Consola Cloud TTS ↗", destination: URL(string: "https://console.cloud.google.com/apis/library/texttospeech.googleapis.com")!)
                                    .font(.caption)
                            }
                        }
                        .padding(6)
                    }

                    GroupBox("Grok TTS · xAI (opcional)") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API key")
                                .font(.caption)
                            SecureField("xai-…", text: $xaiKey)
                                .textFieldStyle(.roundedBorder)
                            Text("Se guarda en el Llavero de macOS. Grok TTS cobra 15 USD por cada millón de caracteres. SuperGrok no cubre estas llamadas.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Link("Crear una clave en console.x.ai", destination: URL(string: "https://console.x.ai/team/default/api-keys")!)
                                .font(.caption)
                        }
                        .padding(6)
                    }

                    GroupBox("OpenAI TTS (opcional)") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API key")
                                .font(.caption)
                            SecureField("sk-…", text: $openaiKey)
                                .textFieldStyle(.roundedBorder)
                            Text("Se guarda en el Llavero de macOS. El modelo gpt-4o-mini-tts recibe instrucciones de narrador de audiolibro para adaptar la entonación a cada frase.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Link("Crear una clave en platform.openai.com", destination: URL(string: "https://platform.openai.com/api-keys")!)
                                .font(.caption)
                        }
                        .padding(6)
                    }
                }
            }
            .frame(maxHeight: 460)

            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }
                Button("Guardar") {
                    let previousGoogle = KeychainStore.googleAPIKey
                    let previousGrok = KeychainStore.xaiAPIKey
                    let previousOpenAI = KeychainStore.openaiAPIKey
                    KeychainStore.googleAPIKey = googleKey
                    KeychainStore.xaiAPIKey = xaiKey
                    KeychainStore.openaiAPIKey = openaiKey
                    model.refreshKeyFlag()
                    if previousGoogle != KeychainStore.googleAPIKey {
                        model.log(googleKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  ? "API key de Google eliminada."
                                  : "API key de Google AI / Cloud guardada en el Llavero.")
                    }
                    if previousGrok != KeychainStore.xaiAPIKey {
                        model.log(xaiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  ? "API key de Grok eliminada."
                                  : "API key de Grok guardada en el Llavero.")
                    }
                    if previousOpenAI != KeychainStore.openaiAPIKey {
                        model.log(openaiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  ? "API key de OpenAI eliminada."
                                  : "API key de OpenAI guardada en el Llavero.")
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 580)
    }
}
