import Foundation
import CryptoKit

/// Native client for Microsoft Edge Read Aloud neural voices.
/// These are cloud neural voices (not macOS / Siri voices) and adapt
/// intonation to each phrase the same way the Python Edge-TTS engine does.
final class EdgeTTSEngine: TTSEngine {
    let kind: TTSEngineKind = .edge

    private static let trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
    private static let chromiumFull = "143.0.3650.75"
    private static let chromiumMajor = "143"
    private static let winEpoch: Double = 11_644_473_600
    private static var clockSkew: Double = 0

    private static var userAgent: String {
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/\(chromiumMajor).0.0.0 Safari/537.36 Edg/\(chromiumMajor).0.0.0"
    }

    func synthesize(text: String, voiceID: String, rate: Double, to url: URL) async throws {
        let prepared = TextCleaner.xmlEscape(TextCleaner.removeIncompatibleCharacters(text))
        let pieces = Self.splitByBytes(prepared, limit: 4096)
        guard !pieces.isEmpty else {
            throw StudioError.tts("El bloque de texto quedó vacío tras la limpieza.")
        }

        var audio = Data()
        for piece in pieces {
            let chunk = try await synthesizePiece(piece, voiceID: voiceID, rate: rate)
            audio.append(chunk)
        }
        try audio.write(to: url, options: .atomic)
        if audio.isEmpty {
            throw StudioError.tts("Edge Neural no devolvió audio. Prueba otra voz o reintenta.")
        }
    }

    private func synthesizePiece(_ text: String, voiceID: String, rate: Double) async throws -> Data {
        var lastError: Error = StudioError.tts("Fallo de conexión con Edge Neural.")
        for attempt in 0..<3 {
            do {
                return try await openAndRead(text: text, voiceID: voiceID, rate: rate)
            } catch {
                lastError = error
                if attempt == 0 {
                    await Self.syncClockSkew()
                }
                try await Task.sleep(nanoseconds: 800_000_000)
            }
        }
        throw lastError
    }

    private func openAndRead(text: String, voiceID: String, rate: Double) async throws -> Data {
        let connectionID = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let token = Self.generateSecMSGEC()
        let gecVersion = "1-\(Self.chromiumFull)"
        let urlString = "wss://api.msedgeservices.com/tts/cognitiveservices/websocket/v1"
            + "?Ocp-Apim-Subscription-Key=\(Self.trustedClientToken)"
            + "&ConnectionId=\(connectionID)"
            + "&Sec-MS-GEC=\(token)"
            + "&Sec-MS-GEC-Version=\(gecVersion)"
        guard let wsURL = URL(string: urlString) else {
            throw StudioError.tts("URL de Edge Neural inválida.")
        }

        var request = URLRequest(url: wsURL, timeoutInterval: 60)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold", forHTTPHeaderField: "Origin")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("muid=\(Self.randomMUID());", forHTTPHeaderField: "Cookie")

        let session = URLSession(configuration: .ephemeral)
        let task = session.webSocketTask(with: request)
        task.resume()

        defer {
            task.cancel(with: .goingAway, reason: nil)
            session.finishTasksAndInvalidate()
        }

        let timestamp = Self.jsDateString()
        let rateStr = TTSPercent.edgeRate(rate)
        let config = """
        X-Timestamp:\(timestamp)\r
        Content-Type:application/json; charset=utf-8\r
        Path:speech.config\r
        \r
        {"context":{"synthesis":{"audio":{"metadataoptions":{"sentenceBoundaryEnabled":"true","wordBoundaryEnabled":"false"},"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}\r

        """
        try await task.send(.string(config))

        let ssml = """
        <speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'><voice name='\(voiceID)'><prosody pitch='+0Hz' rate='\(rateStr)' volume='+0%'>\(text)</prosody></voice></speak>
        """
        let requestID = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let ssmlMessage = """
        X-RequestId:\(requestID)\r
        Content-Type:application/ssml+xml\r
        X-Timestamp:\(timestamp)Z\r
        Path:ssml\r
        \r
        \(ssml)
        """
        try await task.send(.string(ssmlMessage))

        var audio = Data()
        var receivedAudio = false
        let deadline = Date().addingTimeInterval(90)

        while Date() < deadline {
            try Task.checkCancellation()
            let message: URLSessionWebSocketTask.Message
            do {
                message = try await withTimeout(seconds: 30) {
                    try await task.receive()
                }
            } catch {
                if receivedAudio { break }
                throw StudioError.tts("Tiempo de espera agotado en Edge Neural: \(error.localizedDescription)")
            }

            switch message {
            case .string(let textMsg):
                if textMsg.contains("Path:turn.end") {
                    if !receivedAudio {
                        throw StudioError.tts("Edge Neural cerró el turno sin audio. Voz no disponible o texto rechazado.")
                    }
                    return audio
                }
            case .data(let data):
                if let chunk = Self.extractAudio(from: data) {
                    if !chunk.isEmpty {
                        audio.append(chunk)
                        receivedAudio = true
                    }
                }
            @unknown default:
                continue
            }
        }

        if receivedAudio { return audio }
        throw StudioError.tts("No se recibió audio de Edge Neural.")
    }

    private static func extractAudio(from data: Data) -> Data? {
        let needle = Data("Path:audio\r\n".utf8)
        if let range = data.range(of: needle) {
            let payload = data[range.upperBound...]
            return Data(payload)
        }
        guard data.count >= 2 else { return nil }
        let headerLength = Int(data[0]) << 8 | Int(data[1])
        let bodyStart = headerLength + 2
        guard bodyStart < data.count else { return Data() }
        return Data(data[bodyStart...])
    }

    static func generateSecMSGEC(now: Date = Date()) -> String {
        var ticks = now.timeIntervalSince1970 + clockSkew
        ticks += winEpoch
        ticks -= ticks.truncatingRemainder(dividingBy: 300)
        ticks *= 1e9 / 100.0
        let ticksInt = Int64(ticks.rounded(.towardZero))
        let payload = "\(ticksInt)\(trustedClientToken)"
        let digest = SHA256.hash(data: Data(payload.utf8))
        return digest.map { String(format: "%02X", $0) }.joined()
    }

    static func syncClockSkew() async {
        var comps = URLComponents(string: "https://speech.platform.bing.com/consumer/speech/synthesize/readaloud/voices/list")
        comps?.queryItems = [
            URLQueryItem(name: "trustedclienttoken", value: trustedClientToken),
            URLQueryItem(name: "Sec-MS-GEC", value: generateSecMSGEC()),
            URLQueryItem(name: "Sec-MS-GEC-Version", value: "1-\(chromiumFull)")
        ]
        guard let url = comps?.url else { return }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, let dateStr = http.value(forHTTPHeaderField: "Date") {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                if let server = formatter.date(from: dateStr) {
                    clockSkew += server.timeIntervalSince1970 - Date().timeIntervalSince1970
                }
            }
        } catch {
            // Keep previous skew.
        }
    }

    private static func jsDateString() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "EEE MMM dd yyyy HH:mm:ss 'GMT+0000 (Coordinated Universal Time)'"
        return f.string(from: Date())
    }

    private static func randomMUID() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02X", $0) }.joined()
    }

    private static func splitByBytes(_ text: String, limit: Int) -> [String] {
        let utf8 = Array(text.utf8)
        if utf8.count <= limit { return text.isEmpty ? [] : [text] }
        var result: [String] = []
        var start = 0
        while start < utf8.count {
            var end = min(start + limit, utf8.count)
            if end < utf8.count {
                while end > start {
                    let b = utf8[end - 1]
                    if b == 0x0A || b == 0x20 { break }
                    end -= 1
                }
                if end == start { end = min(start + limit, utf8.count) }
                while end > start && (utf8[end - 1] & 0xC0) == 0x80 {
                    end -= 1
                }
            }
            let slice = utf8[start..<end]
            if let s = String(bytes: slice, encoding: .utf8) {
                let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { result.append(trimmed) }
            }
            start = end
        }
        return result
    }
}

private func withTimeout<T>(seconds: TimeInterval, body: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await body() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw StudioError.tts("Timeout")
        }
        let value = try await group.next()!
        group.cancelAll()
        return value
    }
}
