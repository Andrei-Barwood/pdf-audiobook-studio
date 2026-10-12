import Foundation
import AVFoundation

enum AudioBuilder {
    private static let copyBuffer = 256 * 1024

    /// Concatenates chunk files without loading a whole chapter into RAM.
    /// Neural TTS writes MP3 bytes even when the UI asks for M4A; we sniff
    /// the payload, concat on the internal SSD, then transcode once if needed.
    static func merge(paths: [URL], output: URL, format: AudioFormat) async throws {
        let valid = paths.filter { url in
            (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { $0 > 0 } ?? false
        }
        guard !valid.isEmpty else {
            throw StudioError.audio("No hay bloques de audio válidos para unir.")
        }

        let stagingDir = AppPaths.staging
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
