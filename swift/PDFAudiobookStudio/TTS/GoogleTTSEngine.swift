import Foundation

/// Google Text-to-Speech & Gemini AI Audio Engine.
/// Supports both Google Cloud Text-to-Speech (Journey, Studio, Neural2)
/// and Google Gemini Multimodal Voices (Kore, Aoede, Leda, Puck, Fenrir...).
final class GoogleTTSEngine: TTSEngine {
    let kind: TTSEngineKind = .google

    func synthesize(text: String, voiceID: String, rate: Double, to url: URL) async throws {
        guard let apiKey = KeychainStore.googleAPIKey, !apiKey.isEmpty else {
            throw StudioError.missingAPIKey("Google AI Pro / Cloud TTS")
        }

        let cleaned = TextCleaner.removeIncompatibleCharacters(text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw StudioError.tts("El bloque de texto quedó vacío.")
        }

        if voiceID.hasPrefix("gemini-") {
            try await synthesizeWithGemini(text: cleaned, voiceID: voiceID, apiKey: apiKey, to: url)
        } else {
            do {
                try await synthesizeWithCloudTTS(text: cleaned, voiceID: voiceID, rate: rate, apiKey: apiKey, to: url)
            } catch {
                // If Cloud TTS fails (e.g. 401 unauthenticated with Google AI key), fallback to Gemini TTS with corresponding voice
                let fallbackVoice = (voiceID.contains("-D") || voiceID.contains("-B") || voiceID.contains("Male"))
                    ? "gemini-charon"
                    : "gemini-kore"
                try await synthesizeWithGemini(text: cleaned, voiceID: fallbackVoice, apiKey: apiKey, to: url)
            }
        }
    }

    // MARK: - Google Cloud Text-to-Speech (Journey, Studio, Neural2)

    private func synthesizeWithCloudTTS(text: String, voiceID: String, rate: Double, apiKey: String, to url: URL) async throws {
        guard let endpoint = URL(string: "https://texttospeech.googleapis.com/v1/text:synthesize?key=\(apiKey)") else {
            throw StudioError.tts("URL de Google TTS inválida.")
        }

        let lang = extractLocale(from: voiceID)
        let speed = min(max(rate, 0.25), 4.0)

        let body: [String: Any] = [
            "input": ["text": text],
            "voice": [
                "languageCode": lang,
                "name": voiceID
            ],
            "audioConfig": [
                "audioEncoding": "MP3",
                "speakingRate": speed,
                "pitch": 0.0
            ]
        ]

        var request = URLRequest(url: endpoint, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw StudioError.tts("Respuesta inválida del servidor de Google TTS.")
        }

        if http.statusCode >= 400 {
            let errorMsg = Self.parseErrorMessage(from: data)
            throw StudioError.tts("Google TTS (\(http.statusCode)): \(errorMsg)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let audioBase64 = json["audioContent"] as? String,
              let audioData = Data(base64Encoded: audioBase64),
              !audioData.isEmpty else {
            throw StudioError.tts("Google TTS no devolvió audio en la respuesta.")
        }

        try audioData.write(to: url, options: .atomic)
    }

    // MARK: - Google Gemini Multimodal Audio (gemini-3.8-flash-tts)

    private func synthesizeWithGemini(text: String, voiceID: String, apiKey: String, to url: URL) async throws {
        let rawVoice = voiceID.replacingOccurrences(of: "gemini-", with: "").capitalized
        let candidateModels = ["gemini-3.8-flash-tts", "gemini-3.8-flash-lite-tts", "gemini-3.8-flash"]
        var lastError: Error?

        for model in candidateModels {
            guard let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else {
                continue
            }

            let body: [String: Any] = [
                "contents": [
                    [
                        "parts": [
                            [
                                "text": "Narrate the following text aloud with natural expressive human tone suitable for an audiobook. Read only the exact words without any preamble, greeting, explanation or conclusion:\n\n\(text)"
                            ]
                        ]
                    ]
                ],
                "generationConfig": [
                    "responseModalities": ["AUDIO"],
                    "speechConfig": [
                        "voiceConfig": [
                            "prebuiltVoiceConfig": [
                                "voiceName": rawVoice
                            ]
                        ]
                    ]
                ]
            ]

            var request = URLRequest(url: endpoint, timeoutInterval: 180)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else { continue }
                if http.statusCode == 200 {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let candidates = json["candidates"] as? [[String: Any]],
                          let firstCandidate = candidates.first,
                          let content = firstCandidate["content"] as? [String: Any],
                          let parts = content["parts"] as? [[String: Any]] else {
                        continue
                    }

                    var foundAudioData: Data?
                    for part in parts {
                        if let inlineData = part["inlineData"] as? [String: Any],
                           let base64 = inlineData["data"] as? String,
                           let audioBytes = Data(base64Encoded: base64) {
                            foundAudioData = audioBytes
                            break
                        }
                    }

                    if let audio = foundAudioData, !audio.isEmpty {
                        try audio.write(to: url, options: .atomic)
                        return
                    }
                } else {
                    let errorMsg = Self.parseErrorMessage(from: data)
                    lastError = StudioError.tts("Google Gemini (\(http.statusCode)): \(errorMsg)")
                }
            } catch {
                lastError = error
            }
        }

        throw lastError ?? StudioError.tts("No se pudo sintetizar audio con Google Gemini.")
    }

    private func extractLocale(from voiceID: String) -> String {
        let parts = voiceID.split(separator: "-")
        if parts.count >= 2 {
            return "\(parts[0])-\(parts[1])"
        }
        return "es-ES"
    }

    private static func parseErrorMessage(from data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8)?.prefix(200).description ?? "Error desconocido"
        }
        if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
            return message
        }
        if let message = json["message"] as? String {
            return message
        }
        return "Error devuelto por la API de Google"
    }
}
