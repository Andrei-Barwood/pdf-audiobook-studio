import Foundation

/// xAI Grok Text-to-Speech (`POST https://api.x.ai/v1/tts`).
/// Bills per character of the text sent. Speed is clamped to 0.7…1.5.
final class GrokTTSEngine: TTSEngine {
    let kind: TTSEngineKind = .grok

    func synthesize(text: String, voiceID: String, rate: Double, to url: URL) async throws {
        guard let apiKey = KeychainStore.xaiAPIKey, !apiKey.isEmpty else {
            throw StudioError.missingAPIKey("Grok (xAI)")
        }

        let cleaned = TextCleaner.removeIncompatibleCharacters(text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw StudioError.tts("El bloque de texto quedó vacío.")
        }
        if cleaned.count > 15_000 {
            throw StudioError.tts("Un bloque supera el límite de 15.000 caracteres de Grok TTS.")
        }

        let codec = url.pathExtension.lowercased() == "wav" ? "wav" : "mp3"
        let speed = min(max(rate, 0.7), 1.5)
        let body: [String: Any] = [
            "text": cleaned,
            "voice_id": voiceID,
            "language": Self.detectLanguage(cleaned),
            "speed": speed,
            "text_normalization": true,
            "output_format": [
                "codec": codec,
                "sample_rate": codec == "wav" ? 44_100 : 24_000,
                "bit_rate": 128_000
            ]
        ]

        let data = try await post(body: body, apiKey: apiKey)
        try data.write(to: url, options: .atomic)
    }

    static func detectLanguage(_ text: String) -> String {
        let sample = " \(text.lowercased()) "
        let spanishHits = [" el ", " la ", " de ", " que ", " los ", " las ", " del ", " una ", " por ", " con ", "ñ", "á", "é", "í", "ó", "ú", "¿", "¡"]
            .filter { sample.contains($0) }
            .count
        if spanishHits >= 3 { return "es-ES" }
        if sample.range(of: #"[A-Za-z]"#, options: .regularExpression) != nil { return "en" }
        return "auto"
    }

    private func post(body: [String: Any], apiKey: String) async throws -> Data {
        guard let endpoint = URL(string: "https://api.x.ai/v1/tts") else {
            throw StudioError.tts("URL de Grok TTS inválida.")
        }
        var request = URLRequest(url: endpoint, timeoutInterval: 180)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw StudioError.tts("Respuesta inválida de Grok TTS.")
        }
        if http.statusCode == 401 {
            throw StudioError.tts("API key de Grok rechazada. Revísala en Ajustes.")
        }
        if http.statusCode == 429 {
            throw StudioError.tts("Grok TTS está limitando peticiones. Reintenta en unos segundos.")
        }
        if http.statusCode >= 400 {
            throw StudioError.tts("Grok TTS (\(http.statusCode)): \(Self.errorMessage(from: data))")
        }
        let audio = try Self.audioData(from: data, contentType: http.value(forHTTPHeaderField: "Content-Type"))
        if audio.isEmpty {
            throw StudioError.tts("Grok TTS no devolvió audio.")
        }
        return audio
    }

    private static func audioData(from data: Data, contentType: String?) throws -> Data {
        let mime = contentType?.lowercased() ?? ""
        if mime.contains("audio/") || mime.contains("mpeg") || mime.contains("wav") {
            return data
        }
        if data.starts(with: [0x49, 0x44, 0x33]) || data.starts(with: [0xFF, 0xFB]) || data.starts(with: [0x52, 0x49, 0x46, 0x46]) {
            return data
        }
        guard mime.contains("json") || data.first == UInt8(ascii: "{") else {
            return data
        }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw StudioError.tts("Grok TTS devolvió JSON ilegible.")
        }
        if let encoded = obj["audio"] as? String, let decoded = Data(base64Encoded: encoded) {
            return decoded
        }
        throw StudioError.tts(errorMessage(from: data))
    }

    private static func errorMessage(from data: Data) -> String {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = obj["error"] as? [String: Any], let msg = error["message"] as? String {
                return msg
            }
            if let msg = obj["message"] as? String { return msg }
            if let msg = obj["error"] as? String { return msg }
        }
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(280)
            .description ?? "error desconocido"
    }
}
