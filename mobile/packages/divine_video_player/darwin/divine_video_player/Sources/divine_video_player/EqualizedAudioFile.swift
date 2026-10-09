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

    /// Renders [startSec] to [endSec] of the local file [source] through
    /// [equalizer] into a new CAF in the temporary directory, or nil when it
    /// cannot be read or written, or the task is cancelled.
    ///
    /// Only that stretch is read: a sound declaring hours of audio costs no
    /// more than the seconds a track plays of it. Reads and writes a sample
    /// buffer at a time, so it never sits in memory whole. The copy's first
    /// frame is the source at [EqualizedCopy.startSec], silence included, so
    /// a time in one is that much later in the other. Run it off the main
    /// thread.
    static func render(
        source: URL,
        equalizer: AudioEqualizer,
        from startSec: Double,
        to endSec: Double
    ) async -> EqualizedCopy? {
        let start = max(startSec, 0)
        guard endSec > start else { return nil }
        let target = temporaryURL(fileExtension: "caf")
        let rendered = await write(
            source: source, equalizer: equalizer, from: start, to: endSec, into: target)
        guard rendered, !Task.isCancelled else {
            try? FileManager.default.removeItem(at: target)
            return nil
        }
        return EqualizedCopy(url: target, startSec: start)
    }

    /// The copies and downloads in the temporary directory. Listed before a
    /// run renders any, they are an earlier run's, which no player of this
    /// one plays: evicting needs a running player, so a run killed while it
    /// played left them behind.
    static func copies() -> [URL] {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.filter { $0.hasPrefix(filePrefix) }.map { directory.appendingPathComponent($0) }
    }

    private static func write(
        source: URL,
        equalizer: AudioEqualizer,
        from startSec: Double,
        to endSec: Double,
        into target: URL
    ) async -> Bool {
        let asset = AVURLAsset(url: source)
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first else {
            return false
        }
        // AVAudioFile completes the file only once it is released, which an
        // autoreleased reference would put off past the return.
        return autoreleasepool {
            write(
                asset: asset, track: track, equalizer: equalizer,
                from: startSec, to: endSec, into: target)
        }
    }

    private static func write(
        asset: AVAsset,
        track: AVAssetTrack,
        equalizer: AudioEqualizer,
        from startSec: Double,
        to endSec: Double,
        into target: URL
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
        reader.timeRange = CMTimeRange(
            start: CMTime(seconds: startSec, preferredTimescale: 48_000),
            end: CMTime(seconds: endSec, preferredTimescale: 48_000)
        )
        guard reader.startReading() else { return false }
        var copy: Copy?
        var failed = false
        while !failed, !Task.isCancelled, let sampleBuffer = output.copyNextSampleBuffer() {
            autoreleasepool {
                do {
                    if copy == nil {
                        copy = try Copy(target, for: sampleBuffer, equalizer: equalizer,
                                        startSec: startSec, endSec: endSec)
                        if copy == nil { failed = true }
                    }
                    guard let copy else { return }
                    failed = try !copy.append(sampleBuffer)
                } catch {
                    failed = true
                }
            }
            // The reader keeps to its range; this keeps to it whatever the
            // file claims.
            if copy?.isFull == true { break }
        }
        let finished = reader.status == .completed || copy?.isFull == true
        if failed || !finished || Task.isCancelled { reader.cancelReading() }
        return !failed && finished && !Task.isCancelled && copy != nil
    }

    /// The copy being written: the file, the equalizer chain, and how many of
    /// the stretch's frames it holds.
    private final class Copy {
        let file: AVAudioFile
        let chain: EqualizerPcm
        let sampleRate: Double
        let startSec: Double
        let capacity: Int
        private(set) var frames = 0

        var isFull: Bool { frames >= capacity }

        /// Opens [target] for the format of the first [sampleBuffer]; nil for
        /// audio the copy cannot hold.
        init?(
            _ target: URL,
            for sampleBuffer: CMSampleBuffer,
            equalizer: AudioEqualizer,
            startSec: Double,
            endSec: Double
        ) throws {
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
            file = try AVAudioFile(
                forWriting: target,
                settings: format.settings,
                commonFormat: .pcmFormatFloat32,
                interleaved: true
            )
            chain = EqualizerPcm(
                equalizer: equalizer,
                sampleRate: format.sampleRate,
                channelCount: Int(format.channelCount)
            )
            sampleRate = basic.mSampleRate
            self.startSec = startSec
            capacity = Int(((endSec - startSec) * basic.mSampleRate).rounded())
        }

        /// Equalizes [sampleBuffer] and writes the part of it inside the
        /// stretch, after the silence before it; false when its samples
        /// cannot be read.
        func append(_ sampleBuffer: CMSampleBuffer) throws -> Bool {
            guard let block = CMSampleBufferGetDataBuffer(sampleBuffer) else { return true }
            let format = file.processingFormat
            let channels = Int(format.channelCount)
            let bytesPerFrame = channels * MemoryLayout<Float>.size
            let available = CMBlockBufferGetDataLength(block) / bytesPerFrame
            guard available > 0 else { return true }
            // Where the buffer starts in the copy: a gap before it is silence,
            // and frames before the stretch, which a decoder can hand over
            // ahead of a range, are dropped.
            let presentation = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            if presentation.isNumeric {
                let at = Int(((presentation.seconds - startSec) * sampleRate).rounded())
                if at > frames {
                    let silence = min(at - frames, capacity - frames)
                    try EqualizedAudioFile.writeSilence(frames: silence, to: file)
                    frames += silence
                }
            }
            guard
                let buffer = AVAudioPCMBuffer(
                    pcmFormat: format, frameCapacity: AVAudioFrameCount(available)),
                let samples = buffer.floatChannelData?[0],
                CMBlockBufferCopyDataBytes(
                    block, atOffset: 0, dataLength: available * bytesPerFrame,
                    destination: samples) == kCMBlockBufferNoErr
            else { return false }
            var skip = 0
            if presentation.isNumeric {
                let at = Int(((presentation.seconds - startSec) * sampleRate).rounded())
                if at < 0 { skip = min(-at, available) }
            }
            let kept = min(available - skip, capacity - frames)
            guard kept > 0 else { return true }
            if skip > 0 {
                memmove(samples, samples + skip * channels, kept * bytesPerFrame)
            }
            buffer.frameLength = AVAudioFrameCount(kept)
            chain.process(samples, frames: kept)
            try file.write(from: buffer)
            frames += kept
            return true
        }
    }

    fileprivate static func writeSilence(frames: Int, to file: AVAudioFile) throws {
        guard frames > 0,
            let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(frames)),
            let samples = buffer.floatChannelData?[0]
        else { return }
        buffer.frameLength = AVAudioFrameCount(frames)
        samples.update(repeating: 0, count: frames * Int(file.processingFormat.channelCount))
        try file.write(from: buffer)
    }

    /// What every copy's and download's name starts with.
    private static let filePrefix = "divine_eq_"

    private static func temporaryURL(fileExtension: String) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(filePrefix)\(UUID().uuidString)")
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

/// An equalized copy of part of a sound: its file, and the time in the
/// source its first frame is.
struct EqualizedCopy: Hashable {
    let url: URL
    let startSec: Double
}
