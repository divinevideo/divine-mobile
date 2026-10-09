import AVFoundation
import Foundation

/// An overlay track's sound with its equalizer applied, written to a file of
/// its own that the track's `AVPlayer` then plays like any other.
///
/// The equalizer cannot run inside the player. A processing tap on an
/// `AVPlayer` adds 0.1–0.2 s to every start and seek on top of the ~0.1 s it
/// takes without one (measured on macOS and the iOS Simulator). A track
/// started anywhere but where it last stopped came in that late, drifted past
/// [AudioOverlayManager]'s 0.25 s threshold, and was seeked again every
/// 0.4 s for as long as it played. Rendered ahead instead, the sound goes
/// through the same [EqualizerPcm] the clip preview uses, the twin of the
/// export's chain.
enum EqualizedAudioFile {

    /// A local file holding [source]: the file itself, or a download of a
    /// remote one into the temporary directory. Nil when the download fails.
    static func localCopy(of source: URL) async -> URL? {
        if source.isFileURL { return source }
        do {
            let (downloaded, response) = try await URLSession.shared.download(from: source)
            if let status = (response as? HTTPURLResponse)?.statusCode, !(200..<300).contains(status) {
                try? FileManager.default.removeItem(at: downloaded)
                return nil
            }
            // AVFoundation tells a local file's format by its extension.
            let fileExtension = source.pathExtension.isEmpty
                ? fileExtension(forMimeType: response.mimeType)
                : source.pathExtension
            let target = temporaryURL(fileExtension: fileExtension)
            try FileManager.default.moveItem(at: downloaded, to: target)
            return target
        } catch {
            return nil
        }
    }

    /// Renders the local file [source] through [equalizer] into a new CAF in
    /// the temporary directory, or nil when it cannot be read or written.
    ///
    /// Reads and writes a sample buffer at a time, so a long song never sits
    /// in memory whole. The copy starts where the source does, silence
    /// included, so a time in one is the same time in the other. Run it off
    /// the main thread.
    static func render(source: URL, equalizer: AudioEqualizer) async -> URL? {
        let target = temporaryURL(fileExtension: "caf")
        let rendered = await write(source: source, equalizer: equalizer, to: target)
        if !rendered { try? FileManager.default.removeItem(at: target) }
        return rendered ? target : nil
    }

    private static func write(source: URL, equalizer: AudioEqualizer, to target: URL) async -> Bool {
        let asset = AVURLAsset(url: source)
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first else {
            return false
        }
        // AVAudioFile completes the file only once it is released, which an
        // autoreleased reference would put off past the return.
        return autoreleasepool {
            write(asset: asset, track: track, equalizer: equalizer, to: target)
        }
    }

    private static func write(
        asset: AVAsset,
        track: AVAssetTrack,
        equalizer: AudioEqualizer,
        to target: URL
    ) -> Bool {
        guard let reader = try? AVAssetReader(asset: asset) else { return false }
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsBigEndianKey: false,
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { return false }
        reader.add(output)
        guard reader.startReading() else { return false }
        var file: AVAudioFile?
        var chain: EqualizerPcm?
        var failed = false
        while !failed, let sampleBuffer = output.copyNextSampleBuffer() {
            autoreleasepool {
                do {
                    if file == nil {
                        guard let opened = try open(target, for: sampleBuffer) else {
                            failed = true
                            return
                        }
                        file = opened
                        let format = opened.processingFormat
                        chain = EqualizerPcm(
                            equalizer: equalizer,
                            sampleRate: format.sampleRate,
                            channelCount: Int(format.channelCount)
                        )
                    }
                    guard let file, let chain else { return }
                    failed = try !append(sampleBuffer, to: file, through: chain)
                } catch {
                    failed = true
                }
            }
        }
        if failed { reader.cancelReading() }
        return !failed && reader.status == .completed && file != nil
    }

    /// Opens [target] for the format of the first [sampleBuffer], with the
    /// silence before it written; nil for audio the copy cannot hold.
    private static func open(_ target: URL, for sampleBuffer: CMSampleBuffer) throws -> AVAudioFile? {
        guard let description = CMSampleBufferGetFormatDescription(sampleBuffer),
            let basic = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee,
            (1...2).contains(Int(basic.mChannelsPerFrame)), basic.mSampleRate > 0,
            let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: basic.mSampleRate,
                channels: basic.mChannelsPerFrame,
                interleaved: true
            )
        else { return nil }
        let file = try AVAudioFile(
            forWriting: target,
            settings: format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: true
        )
        let start = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if start.isNumeric, start.seconds > 0 {
            try writeSilence(frames: Int((start.seconds * basic.mSampleRate).rounded()), to: file)
        }
        return file
    }

    /// Equalizes [sampleBuffer] and writes it to [file]; false when its
    /// samples cannot be read.
    private static func append(
        _ sampleBuffer: CMSampleBuffer,
        to file: AVAudioFile,
        through chain: EqualizerPcm
    ) throws -> Bool {
        guard let block = CMSampleBufferGetDataBuffer(sampleBuffer) else { return true }
        let format = file.processingFormat
        let bytesPerFrame = Int(format.channelCount) * MemoryLayout<Float>.size
        let frames = CMBlockBufferGetDataLength(block) / bytesPerFrame
        guard frames > 0 else { return true }
        guard
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)),
            let samples = buffer.floatChannelData?[0],
            CMBlockBufferCopyDataBytes(
                block, atOffset: 0, dataLength: frames * bytesPerFrame, destination: samples)
                == kCMBlockBufferNoErr
        else { return false }
        buffer.frameLength = AVAudioFrameCount(frames)
        chain.process(samples, frames: frames)
        try file.write(from: buffer)
        return true
    }

    private static func writeSilence(frames: Int, to file: AVAudioFile) throws {
        guard frames > 0,
            let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(frames)),
            let samples = buffer.floatChannelData?[0]
        else { return }
        buffer.frameLength = AVAudioFrameCount(frames)
        samples.update(repeating: 0, count: frames * Int(file.processingFormat.channelCount))
        try file.write(from: buffer)
    }

    private static func temporaryURL(fileExtension: String) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("divine_eq_\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)
    }

    /// The extension AVFoundation knows a downloaded sound by.
    private static func fileExtension(forMimeType mimeType: String?) -> String {
        switch mimeType?.lowercased() {
        case "audio/mpeg", "audio/mp3": return "mp3"
        case "audio/wav", "audio/x-wav", "audio/wave": return "wav"
        case "audio/aac", "audio/aacp": return "aac"
        case "audio/x-caf": return "caf"
        case "audio/aiff", "audio/x-aiff": return "aiff"
        default: return "m4a"
        }
    }
}
