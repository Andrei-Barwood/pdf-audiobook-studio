import Foundation

enum ProjectStatus: String, Codable, CaseIterable {
    case active = "ACTIVE"
    case completed = "COMPLETED"
    case failed = "FAILED"
    case paused = "PAUSED"
}

enum ChunkStatus: String, Codable {
    case pending = "PENDING"
    case processing = "PROCESSING"
    case completed = "COMPLETED"
    case failed = "FAILED"
}

enum AudioFormat: String, CaseIterable, Identifiable, Sendable {
    case mp3
    case m4a
    case wav

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mp3: return "MP3"
        case .m4a: return "M4A"
        case .wav: return "WAV"
        }
    }

    var fileExtension: String { rawValue }
}

enum TTSEngineKind: String, CaseIterable, Identifiable, Sendable {
    case edge
    case google
    case grok
    case openai

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .edge:
            return "Edge Neural (Microsoft)"
        case .google:
            return "Google AI Pro / Cloud TTS 👑"
        case .grok:
            return "Grok TTS (xAI)"
        case .openai:
            return "OpenAI TTS (entonación inteligente)"
        }
    }

    var subtitle: String {
        switch self {
        case .edge:
            return "Voces neuronales gratuitas. Entonación natural por frase, no las voces de macOS."
        case .google:
            return "Voces Journey, Studio y Gemini (Kore, Aoede, Journey-F…). Estilo princesa, literarias y ultraexpresivas."
        case .grok:
            return "Voces de Grok (Ara, Eve, Rex…). 15 USD / 1M caracteres. Velocidad 0.7–1.5×. Requiere API key de console.x.ai."
        case .openai:
            return "gpt-4o-mini-tts adapta ritmo y emoción al carácter de cada frase. Requiere API key."
        }
    }
}

struct VoiceOption: Identifiable, Hashable {
    var id: String { voiceID }
    let voiceID: String
    let name: String
    let locale: String
    let gender: String
    let engine: TTSEngineKind
    let hint: String

    var localeFlag: String {
        let region = locale.split(separator: "-").last.map(String.init)?.uppercased() ?? ""
        switch region {
        case "ES": return "🇪🇸"
        case "MX": return "🇲🇽"
        case "AR": return "🇦🇷"
        case "CO": return "🇨🇴"
        case "US": return "🇺🇸"
        case "GB": return "🇬🇧"
        case "CL": return "🇨🇱"
        case "PE": return "🇵🇪"
        case "US-MULTI", "MULTI": return "🌍"
        default:
            if locale.lowercased().contains("multilingual") { return "🌍" }
            if locale.hasPrefix("es") { return "🇪🇸" }
            if locale.hasPrefix("en") { return "🇺🇸" }
            if locale.hasPrefix("fr") { return "🇫🇷" }
            if locale.hasPrefix("pt") { return "🇧🇷" }
            if locale.hasPrefix("it") { return "🇮🇹" }
            if locale.hasPrefix("de") { return "🇩🇪" }
            return "🎙️"
        }
    }
}

struct PDFMetadata {
    let name: String
    let path: URL
    let pageCount: Int
    let fileSizeMB: Double
    let isScanned: Bool
    let author: String
    let title: String
}

struct TextChunk: Identifiable {
    var id: Int { chunkIndex }
    let chunkIndex: Int
    let pageNumber: Int
    let originalText: String
    let cleanText: String
    var audioPath: String?
    var status: ChunkStatus
    var errorMessage: String?
    var chapterIndex: Int? = nil
    var chapterTitle: String? = nil
}

struct ProjectRecord: Identifiable, Hashable {
    let id: String
    var name: String
    var pdfPath: String
    var outputDir: String
    var createdAt: String
    var status: ProjectStatus
    var engineType: TTSEngineKind
    var voiceID: String
    var rate: Double
    var formatExt: AudioFormat
    var splitByChapter: Bool = false

    var createdDate: Date {
        ISO8601DateFormatter().date(from: createdAt) ?? Date()
    }
}

struct ProjectProgress {
    var totalChunks: Int
    var completedChunks: Int
    var failedChunks: Int

    var percentage: Double {
        guard totalChunks > 0 else { return 0 }
        return Double(completedChunks) / Double(totalChunks) * 100.0
    }
}

enum StudioError: LocalizedError, Sendable {
    case pdfNotFound(String)
    case pdfEncrypted
    case pdfUnreadable(String)
    case noText
    case tts(String)
    case audio(String)
    case database(String)
    case cancelled
    case missingAPIKey(String)
    case invalidOutput

    var errorDescription: String? {
        switch self {
        case .pdfNotFound(let p): return "No se encontró el PDF:\n\(p)"
        case .pdfEncrypted: return "El PDF está protegido con contraseña."
        case .pdfUnreadable(let m): return "No se pudo leer el PDF: \(m)"
        case .noText: return "El rango seleccionado no contiene texto sintetizable."
        case .tts(let m): return m
        case .audio(let m): return m
        case .database(let m): return m
        case .cancelled: return "Conversión cancelada."
        case .missingAPIKey(let engine): return "Falta la API key de \(engine). Ábrela en Ajustes."
        case .invalidOutput: return "Selecciona una carpeta de destino válida."
        }
    }
}

struct SpeedOption: Identifiable, Hashable {
    let id: Double
    let label: String

    static let all: [SpeedOption] = [
        SpeedOption(id: 0.5, label: "0.5×  Muy lento"),
        SpeedOption(id: 0.75, label: "0.75×  Lento"),
        SpeedOption(id: 1.0, label: "1.0×  Normal"),
        SpeedOption(id: 1.25, label: "1.25×  Rápido"),
        SpeedOption(id: 1.5, label: "1.5×  Muy rápido"),
        SpeedOption(id: 2.0, label: "2.0×  Veloz")
    ]
}

struct LogLine: Identifiable, Hashable {
    let id = UUID()
    let date = Date()
    let message: String
    let isError: Bool

    var stamped: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return "[\(f.string(from: date))] \(message)"
    }
}
