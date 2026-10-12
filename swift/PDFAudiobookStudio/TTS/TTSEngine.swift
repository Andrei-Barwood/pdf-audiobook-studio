import Foundation

protocol TTSEngine {
    var kind: TTSEngineKind { get }
    func synthesize(text: String, voiceID: String, rate: Double, to url: URL) async throws
}

enum TTSFactory {
    static func engine(for kind: TTSEngineKind) -> TTSEngine {
        switch kind {
        case .edge: return EdgeTTSEngine()
        case .grok: return GrokTTSEngine()
        case .openai: return OpenAITTSEngine()
        case .google: return GoogleTTSEngine()
        }
    }
}

enum TTSPercent {
    static func edgeRate(_ multiplier: Double) -> String {
        let pct = Int(((multiplier - 1.0) * 100.0).rounded())
        return String(format: "%+d%%", pct)
    }
}
