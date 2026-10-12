import Foundation

/// OpenAI gpt-4o-mini-tts with audiobook-style instructions.
/// Unlike macOS system voices (fixed contour) this model conditions
/// prosody on the meaning of each sentence.
final class OpenAITTSEngine: TTSEngine {
    let kind: TTSEngineKind = .openai

    func synthesize(text: String, voiceID: String, rate: Double, to url: URL) async throws {
        guard let apiKey = KeychainStore.openaiAPIKey, !apiKey.isEmpty else {
            throw StudioError.missingAPIKey("OpenAI")
        }

        let cleaned = TextCleaner.removeIncompatibleCharacters(text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw StudioError.tts("El bloque de texto quedó vacío.")
        }

        let speed = min(max(rate, 0.25), 4.0)
        var body: [String: Any] = [
            "model": "gpt-4o-mini-tts",
            "voice": voiceID,
            "input": cleaned,
            "instructions": VoiceCatalog.openaiAudiobookInstructions,
            "response_format": "mp3",
            "speed": speed
        ]

        do {
            let data = try await post(body: body, apiKey: apiKey)
            try data.write(to: url, options: .atomic)
            return
        } catch {
            body.removeValue(forKey: "instructions")
            body["model"] = "tts-1-hd"
            let data = try await post(body: body, apiKey: apiKey)
            try data.write(to: url, options: .atomic)
        }
    }

    private func post(body: [String: Any], apiKey: String) async throws -> Data {
        guard let endpoint = URL(string: "https://api.openai.com/v1/audio/speech") else {
            throw StudioError.tts("URL de OpenAI inválida.")
        }
        var request = URLRequest(url: endpoint, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw StudioError.tts("Respuesta inválida de OpenAI.")
        }
        if http.statusCode == 401 {
            throw StudioError.tts("API key de OpenAI rechazada. Revísala en Ajustes.")
        }
        if http.statusCode >= 400 {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw StudioError.tts("OpenAI TTS (\(http.statusCode)): \(msg)")
        }
        if data.isEmpty {
            throw StudioError.tts("OpenAI no devolvió audio.")
        }
        return data
    }
}
