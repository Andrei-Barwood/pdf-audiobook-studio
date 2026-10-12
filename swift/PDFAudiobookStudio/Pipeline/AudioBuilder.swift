import Foundation
import AVFoundation

enum AudioBuilder {
    private static let copyBuffer = 256 * 1024

    enum AudioPayloadFormat {
        case mp3
        case wav
        case m4a
        case unknown
    }

    static func sniffFormat(url: URL) -> AudioPayloadFormat {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return .unknown }
        defer { try? handle.close() }
        let header = (try? handle.read(upToCount: 16)) ?? Data()
        return sniffFormat(data: header)
    }

    static func sniffFormat(data: Data) -> AudioPayloadFormat {
        if data.prefix(4) == Data("RIFF".utf8) { return .wav }
        if data.prefix(3) == Data("ID3".utf8) || (data.count > 1 && data[0] == 0xFF && (data[1] & 0xE0) == 0xE0) { return .mp3 }
        if data.count >= 8 && data.subdata(in: 4..<8) == Data("ftyp".utf8) { return .m4a }
        return .unknown
    }

    static var ffmpegPath: String? {
        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg",
            "/bin/ffmpeg"
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.split(separator: ":") {
                let candidate = URL(fileURLWithPath: String(dir)).appendingPathComponent("ffmpeg").path
                if FileManager.default.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }
        return nil
    }

    static var isFFmpegAvailable: Bool {
        ffmpegPath != nil
    }

    static func convertWAVToMP3(wavData: Data, to outputURL: URL, bitrate: String = "192k") throws {
        guard let ffmpeg = ffmpegPath else {
            throw StudioError.audio("ffmpeg no está disponible para codificar MP3.")
        }
        let stagingDir = AppPaths.staging
        let tempWav = stagingDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("wav")
        try wavData.write(to: tempWav, options: .atomic)
        defer { try? FileManager.default.removeItem(at: tempWav) }

        try convertWAVToMP3(inputURL: tempWav, outputURL: outputURL, bitrate: bitrate)
    }

    static func convertWAVToMP3(inputURL: URL, outputURL: URL, bitrate: String = "192k") throws {
        guard let ffmpeg = ffmpegPath else {
            throw StudioError.audio("ffmpeg no está disponible para codificar MP3.")
        }
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpeg)
        process.arguments = [
            "-loglevel", "error",
            "-y",
            "-i", inputURL.path,
            "-c:a", "libmp3lame",
            "-b:a", bitrate,
            outputURL.path
        ]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0,
              FileManager.default.fileExists(atPath: outputURL.path),
              (try? outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map({ $0 > 0 }) ?? false else {
            throw StudioError.audio("Error al codificar MP3 con ffmpeg.")
        }
    }

    /// Concatenates chunk files without loading a whole chapter into RAM.
    /// Handles both MP3 chunks and WAV chunks (from Google Gemini multimodal audio).
    static func merge(paths: [URL], output: URL, format: AudioFormat) async throws {
        let valid = paths.filter { url in
            (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { $0 > 0 } ?? false
        }
        guard let first = valid.first else {
            throw StudioError.audio("No hay bloques de audio válidos para unir.")
        }

        let stagingDir = AppPaths.staging
        let payloadFormat = sniffFormat(url: first)

        if payloadFormat == .wav {
            let concatWAV = stagingDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("wav")
            try streamConcatWAV(valid, to: concatWAV)
            guard (try? concatWAV.resourceValues(forKeys: [.fileSizeKey]).fileSize).map({ $0 > 0 }) ?? false else {
                throw StudioError.audio("La unión de bloques WAV produjo un archivo vacío.")
            }

            var staged: URL
            switch format {
            case .wav:
                staged = concatWAV
            case .m4a:
                let m4a = stagingDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
                do {
                    try await transcode(concatWAV, to: m4a, format: .m4a)
                    try? FileManager.default.removeItem(at: concatWAV)
                    staged = m4a
                } catch {
                    AppLog.write("Transcodificación M4A falló (\(error.localizedDescription)); se entrega WAV.")
                    staged = concatWAV
                }
            case .mp3:
                if isFFmpegAvailable {
                    let mp3 = stagingDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp3")
                    do {
                        try convertWAVToMP3(inputURL: concatWAV, outputURL: mp3)
                        try? FileManager.default.removeItem(at: concatWAV)
                        staged = mp3
                    } catch {
                        AppLog.write("Transcodificación MP3 con ffmpeg falló (\(error.localizedDescription)); convirtiendo a M4A...")
                        let m4a = stagingDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
                        try await transcode(concatWAV, to: m4a, format: .m4a)
                        try? FileManager.default.removeItem(at: concatWAV)
                        staged = m4a
                    }
                } else {
                    let m4a = stagingDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
                    try await transcode(concatWAV, to: m4a, format: .m4a)
                    try? FileManager.default.removeItem(at: concatWAV)
                    staged = m4a
                }
            }

            var destination = output
            if staged.pathExtension.lowercased() != output.pathExtension.lowercased() {
                destination = output.deletingPathExtension().appendingPathExtension(staged.pathExtension)
            }
            try publish(staged, to: destination)
            return
        }

        // Chunks are MP3 (Edge TTS, OpenAI, Grok, Cloud TTS)
        let concatMP3 = stagingDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp3")
        try streamConcat(valid, to: concatMP3)
        guard (try? concatMP3.resourceValues(forKeys: [.fileSizeKey]).fileSize).map({ $0 > 0 }) ?? false else {
            throw StudioError.audio("La unión de bloques produjo un archivo vacío.")
        }

        var staged: URL
        switch format {
        case .mp3:
            staged = concatMP3
        case .m4a:
            let m4a = stagingDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
            do {
                try await transcode(concatMP3, to: m4a, format: .m4a)
                try? FileManager.default.removeItem(at: concatMP3)
                staged = m4a
            } catch {
                AppLog.write("Transcodificación M4A falló (\(error.localizedDescription)); se entrega MP3.")
                staged = concatMP3
            }
        case .wav:
            let wav = stagingDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("wav")
            try await transcode(concatMP3, to: wav, format: .wav)
            try? FileManager.default.removeItem(at: concatMP3)
            staged = wav
        }

        var destination = output
        if staged.pathExtension.lowercased() != output.pathExtension.lowercased() {
            destination = output.deletingPathExtension().appendingPathExtension(staged.pathExtension)
        }
        try publish(staged, to: destination)
    }

    static func publish(_ staged: URL, to destination: URL) throws {
        let fm = FileManager.default
        let dir = destination.deletingLastPathComponent()
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        do {
            try fm.copyItem(at: staged, to: destination)
        } catch {
            AppLog.write("Copia al destino falló. El archivo sigue en \(staged.path). \(error.localizedDescription)")
            throw StudioError.audio(
                "El capítulo quedó a salvo en el SSD interno:\n\(staged.path)\n\n" +
                "No se pudo copiar a \(destination.path): \(error.localizedDescription)"
            )
        }
        try? fm.removeItem(at: staged)
    }

    /// Pure Swift streaming concatenation for standard PCM WAV chunk files.
    /// Preserves standard 44-byte WAV header and appends raw PCM bytes from each chunk.
    /// Eliminates memory overhead, avoids external dependencies, and fixes multi-header corruption.
    static func streamConcatWAV(_ urls: [URL], to output: URL) throws {
        guard let first = urls.first else { return }
        let fm = FileManager.default
        try fm.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: output.path) {
            try fm.removeItem(at: output)
        }

        let firstData = try Data(contentsOf: first)
        guard firstData.count >= 44,
              firstData.prefix(4) == Data("RIFF".utf8),
              firstData[8..<12] == Data("WAVE".utf8) else {
            throw StudioError.audio("El primer bloque WAV no contiene un encabezado válido.")
        }

        // Find "data" chunk offset in WAV header
        var dataChunkOffset = 12
        while dataChunkOffset + 8 <= firstData.count {
            let chunkID = String(data: firstData[dataChunkOffset..<(dataChunkOffset + 4)], encoding: .ascii) ?? ""
            let chunkSize = firstData[dataChunkOffset + 4..<dataChunkOffset + 8].withUnsafeBytes { $0.load(as: UInt32.self) }
            if chunkID == "data" {
                break
            }
            dataChunkOffset += 8 + Int(chunkSize)
        }

        let headerLength = min(dataChunkOffset + 8, firstData.count)

        fm.createFile(atPath: output.path, contents: nil)
        let handle = try FileHandle(forWritingTo: output)
        defer { try? handle.close() }

        // Write initial header from the first file
        try handle.write(contentsOf: firstData.subdata(in: 0..<headerLength))

        var totalPCMBytes: UInt32 = 0
        for url in urls {
            let reader = try FileHandle(forReadingFrom: url)
            defer { try? reader.close() }

            // Seek past header to PCM payload
            try reader.seek(toOffset: UInt64(headerLength))
            while true {
                let data = try reader.read(upToCount: copyBuffer) ?? Data()
                if data.isEmpty { break }
                try handle.write(contentsOf: data)
                totalPCMBytes += UInt32(data.count)
            }
        }

        // Patch data chunk size
        if dataChunkOffset + 8 <= headerLength {
            try handle.seek(toOffset: UInt64(dataChunkOffset + 4))
            var dataSizeLE = totalPCMBytes.littleEndian
            try handle.write(contentsOf: Data(bytes: &dataSizeLE, count: 4))
        }

        // Patch RIFF total size minus 8
        try handle.seek(toOffset: 4)
        var riffSizeLE = (totalPCMBytes + UInt32(headerLength) - 8).littleEndian
        try handle.write(contentsOf: Data(bytes: &riffSizeLE, count: 4))

        try handle.synchronize()
    }

    /// Copy file bytes in small buffers. Never `Data(contentsOf:)` a chapter.
    private static func streamConcat(_ urls: [URL], to output: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: output.path) {
            try fm.removeItem(at: output)
        }
        fm.createFile(atPath: output.path, contents: nil)
        let handle = try FileHandle(forWritingTo: output)
        defer { try? handle.close() }
        for url in urls {
            let reader = try FileHandle(forReadingFrom: url)
            defer { try? reader.close() }
            while true {
                let data = try reader.read(upToCount: copyBuffer) ?? Data()
                if data.isEmpty { break }
                try handle.write(contentsOf: data)
            }
        }
        try handle.synchronize()
    }

    private static func transcode(_ input: URL, to output: URL, format: AudioFormat) async throws {
        if FileManager.default.fileExists(atPath: output.path) {
            try FileManager.default.removeItem(at: output)
        }
        let asset = AVURLAsset(url: input)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard !tracks.isEmpty else {
            throw StudioError.audio("AVFoundation no pudo leer el MP3 unido. El archivo no se abrirá como M4A.")
        }

        switch format {
        case .m4a:
            guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
                throw StudioError.audio("No se pudo iniciar la transcodificación a M4A.")
            }
            session.outputURL = output
            session.outputFileType = .m4a
            session.metadata = [
                makeItem(.commonIdentifierType, "Audiobook"),
                makeItem(.commonIdentifierTitle, output.deletingPathExtension().lastPathComponent)
            ]
            try await export(session)
            guard session.status == .completed,
                  (try? output.resourceValues(forKeys: [.fileSizeKey]).fileSize).map({ $0 > 0 }) ?? false else {
                throw StudioError.audio(session.error?.localizedDescription ?? "Fallo al exportar M4A.")
            }
        case .wav:
            try await transcodeToWAV(input, output: output)
        case .mp3:
            try FileManager.default.copyItem(at: input, to: output)
        }
    }

    private static func transcodeToWAV(_ input: URL, output: URL) async throws {
        let asset = AVURLAsset(url: input)
        guard let reader = try? AVAssetReader(asset: asset) else {
            throw StudioError.audio("No se pudo leer el audio para WAV.")
        }
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let track = tracks.first else {
            throw StudioError.audio("El audio no tiene pista.")
        }
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        reader.add(readerOutput)

        guard let writer = try? AVAssetWriter(outputURL: output, fileType: .wav) else {
            throw StudioError.audio("No se pudo crear el WAV.")
        }
        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings)
        writerInput.expectsMediaDataInRealTime = false
        writer.add(writerInput)

        guard writer.startWriting(), reader.startReading() else {
            throw StudioError.audio("No se pudo iniciar la transcodificación WAV.")
        }
        writer.startSession(atSourceTime: .zero)

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            writerInput.requestMediaDataWhenReady(on: DispatchQueue(label: "wav.export")) {
                while writerInput.isReadyForMoreMediaData {
                    if let sample = readerOutput.copyNextSampleBuffer() {
                        writerInput.append(sample)
                    } else {
                        writerInput.markAsFinished()
                        writer.finishWriting {
                            if writer.status == .completed {
                                cont.resume()
                            } else {
                                cont.resume(throwing: StudioError.audio(writer.error?.localizedDescription ?? "WAV falló."))
                            }
                        }
                        return
                    }
                }
            }
        }
    }

    private static func export(_ session: AVAssetExportSession) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            session.exportAsynchronously {
                switch session.status {
                case .completed:
                    cont.resume()
                case .cancelled:
                    cont.resume(throwing: StudioError.cancelled)
                default:
                    cont.resume(throwing: StudioError.audio(session.error?.localizedDescription ?? "Exportación fallida."))
                }
            }
        }
    }

    private static func makeItem(_ id: AVMetadataIdentifier, _ value: String) -> AVMutableMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = id
        item.value = value as NSString
        return item
    }
}
