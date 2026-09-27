import AVFoundation
import Foundation

/// Plays a looping clip's audio outside `AVPlayer`, from a buffer an
/// `AVAudioPlayerNode` repeats sample-exact — the Apple counterpart of the
/// Android plugin's `ClipAudioLoopTrack`.
///
/// `AVPlayerLooper` joins laps gaplessly over a plain asset but can only fade
/// the sound at the join: an audio mix cannot add material, and a ramp under
/// ~25 ms does not reach zero there. On loud music the two 30 ms fades are
/// heard as a dip at every restart. Played from a prepared buffer instead, the
/// seam is closed the way Android closes it (see [LoopPcm]): with the sound
/// that follows the loop point where there is any, otherwise with the stretch
/// that followed the moment in the lap best matching its end.
///
/// The decode needs a local file — `AVAssetReader` refuses a remote asset —
/// so a streamed clip keeps the player's own sound until
/// [CachingAssetLoader] has written its download out.
final class ClipAudioLoop {

    /// The stretch of a file one lap plays, and where it sits on the player
    /// item's timeline.
    struct Source {
        let url: URL
        /// Where the lap starts in the file.
        let fileStart: CMTime
        let duration: CMTime
        /// Where the lap starts on the item: [fileStart] for an item played
        /// straight from the file, zero for a composition cut from it.
        let itemStart: CMTime
    }

    private let engine = AVAudioEngine()

    /// Two players, so the loop can be placed again without a gap: the
    /// newly placed one fades in while the other fades out.
    private let nodes = [AVAudioPlayerNode(), AVAudioPlayerNode()]
    private var active = 0
    private let buffer: AVAudioPCMBuffer
    private let loopFrames: AVAudioFrameCount
    private let sampleRate: Double

    /// Where each lap starts on the player item's timeline, in seconds.
    private let itemStart: Double

    /// Where the head was placed in the loop when each node last started.
    private var startFrames: [AVAudioFramePosition] = [0, 0]

    /// Whether the loop is playing.
    private(set) var isRunning = false

    /// Bumped by every placement, so a crossfade still stepping belongs to
    /// the latest one.
    private var crossfadeGeneration = 0
    private var isCrossfading = false

    /// A short summary of how the seam was closed, for the log.
    let seamDescription: String

    /// Called on the main queue when the engine has stopped itself for a new
    /// output configuration — a route change such as Bluetooth connecting —
    /// and the loop has gone silent, so the owner can place it again.
    var onStoppedByConfigurationChange: (() -> Void)?
    private var configurationObserver: NSObjectProtocol?

    var volume: Float = 1 {
        didSet {
            guard !isCrossfading else { return }
            nodes[active].volume = volume
        }
    }

    private var node: AVAudioPlayerNode { nodes[active] }
    private var startFrame: AVAudioFramePosition { startFrames[active] }

    private init(
        buffer: AVAudioPCMBuffer,
        sampleRate: Double,
        itemStart: Double,
        seamDescription: String
    ) {
        self.buffer = buffer
        self.loopFrames = buffer.frameLength
        self.sampleRate = sampleRate
        self.itemStart = itemStart
        self.seamDescription = seamDescription
        // Each on a bus of its own: connecting without one puts both on bus 0,
        // and the second connection silently drops the first.
        for node in nodes {
            engine.attach(node)
            engine.connect(
                node,
                to: engine.mainMixerNode,
                fromBus: 0,
                toBus: engine.mainMixerNode.nextAvailableInputBus,
                format: buffer.format
            )
        }
        engine.prepare()
        // The engine stops itself on a new output configuration and drops
        // what the nodes had scheduled, while the muted player plays on.
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isRunning else { return }
            self.pause()
            self.onStoppedByConfigurationChange?()
        }
    }

    deinit {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
    }

    /// Decodes [source]'s audio and prepares it as a loop, or nil when there
    /// is nothing to loop or anything fails — the caller then leaves the sound
    /// with the player. Reads the whole file, so it must not run on the main
    /// thread.
    static func make(source: Source) async -> ClipAudioLoop? {
        guard source.url.isFileURL, source.duration.isNumeric, source.duration.seconds > 0,
            source.fileStart.isNumeric, source.itemStart.isNumeric
        else { return nil }
        guard let decoded = await decode(url: source.url) else { return nil }
        let channels = decoded.channels
        let loopFrames = Int((source.duration.seconds * decoded.sampleRate).rounded())
        let startFrame = Int(
            ((decoded.firstTime.seconds - source.fileStart.seconds) * decoded.sampleRate).rounded()
        )
        guard let prepared = LoopPcm.prepare(
            samples: decoded.samples,
            channels: channels,
            sampleRate: decoded.sampleRate,
            loopFrames: loopFrames,
            startFrame: startFrame
        ) else { return nil }
        guard
            let format = AVAudioFormat(
                standardFormatWithSampleRate: decoded.sampleRate,
                channels: AVAudioChannelCount(channels)
            ),
            let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(prepared.loopFrames)
            ),
            let channelData = buffer.floatChannelData
        else { return nil }
        buffer.frameLength = AVAudioFrameCount(prepared.loopFrames)
        for frame in 0..<prepared.loopFrames {
            for channel in 0..<channels {
                channelData[channel][frame] = prepared.samples[frame * channels + channel]
            }
        }
        let lagMs = Int(Double(prepared.lapLagFrames) * 1000 / decoded.sampleRate)
        let seam: String
        if prepared.blendedFromPastTheLoop {
            seam = "\(prepared.fadeFrames) frame crossfade with what follows the loop point"
        } else if prepared.lapLagFrames > 0 {
            seam = "\(prepared.fadeFrames) frame crossfade with the lap from \(lagMs) ms back"
        } else {
            seam = "\(prepared.fadeFrames) frame ramp"
        }
        return ClipAudioLoop(
            buffer: buffer,
            sampleRate: decoded.sampleRate,
            itemStart: source.itemStart.seconds,
            seamDescription: "\(prepared.loopFrames) frames at \(Int(decoded.sampleRate))Hz "
                + "from \(Int(source.fileStart.seconds * 1_000_000)) us into the file, "
                + "decoded from \(Int(decoded.firstTime.seconds * 1_000_000)) us, \(seam)"
        )
    }

    /// Starts the loop in step with [item]'s picture.
    ///
    /// The node starts at a host time a moment ahead, and the head is placed
    /// where the picture will be when that first sample is *heard* — the
    /// item's timebase converted to that host time, the output's presentation
    /// latency included. Both are sample-accurate, so the sound comes in on
    /// the picture rather than being steered onto it.
    ///
    /// A loop that is already running is placed again on the other node,
    /// which fades in over [crossfadeSteps] while the running one fades out:
    /// two copies of the same sound a few milliseconds apart cross without
    /// the stop a restart is heard as.
    ///
    /// Returns false, and changes nothing, while the item's timebase is not
    /// running yet. The player reports `.playing` before its clock moves;
    /// placed against the still clock, the sound came in 55–63 ms ahead of
    /// the picture on an iPad Air (M4).
    @discardableResult
    func start(alignedTo item: AVPlayerItem) -> Bool {
        guard let timebase = item.timebase, CMTimebaseGetRate(timebase) > 0 else {
            return false
        }
        do {
            if !engine.isRunning { try engine.start() }
        } catch {
            return false
        }
        let crossfades = isRunning
        let previous = active
        if crossfades { active = 1 - active }
        crossfadeGeneration += 1
        node.stop()
        let leadSeconds = Self.startLeadSeconds
        let startHostTime = mach_absolute_time() + Self.hostTicks(forSeconds: leadSeconds)
        let heardHostTime =
            startHostTime + Self.hostTicks(forSeconds: engine.outputNode.presentationLatency)
        let itemTime = CMSyncConvertTime(
            CMClockMakeHostTimeFromSystemUnits(heardHostTime),
            from: CMClockGetHostTimeClock(),
            to: timebase
        )
        guard itemTime.isNumeric else { return false }
        let frame = AVAudioFramePosition(((itemTime.seconds - itemStart) * sampleRate).rounded())
        startFrames[active] =
            ((frame % AVAudioFramePosition(loopFrames)) + AVAudioFramePosition(loopFrames))
            % AVAudioFramePosition(loopFrames)
        if let head = tail(from: startFrame) {
            node.scheduleBuffer(head, at: nil, options: [])
        }
        node.scheduleBuffer(buffer, at: nil, options: .loops)
        node.volume = crossfades ? 0 : volume
        node.play(at: AVAudioTime(hostTime: startHostTime))
        isRunning = true
        if crossfades {
            isCrossfading = true
            crossfade(from: previous, step: 0, generation: crossfadeGeneration)
        } else {
            nodes[1 - active].stop()
            isCrossfading = false
        }
        return true
    }

    /// Steps the gains from the node at [previous] to the active one at
    /// constant power, starting when the active one renders its first sample.
    private func crossfade(from previous: Int, step: Int, generation: Int) {
        guard generation == crossfadeGeneration, isRunning else { return }
        let progress = Float(step) / Float(Self.crossfadeSteps)
        nodes[active].volume = volume * sin(progress * .pi / 2)
        nodes[previous].volume = volume * cos(progress * .pi / 2)
        if step >= Self.crossfadeSteps {
            nodes[previous].stop()
            isCrossfading = false
            return
        }
        let delay = step == 0 ? Self.startLeadSeconds : Self.crossfadeStepSeconds
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.crossfade(from: previous, step: step + 1, generation: generation)
        }
    }

    private static let crossfadeSteps = 8
    private static let crossfadeStepSeconds = 0.005

    /// How far the sound heard now is ahead of [item]'s picture, in seconds,
    /// or nil before the node has rendered anything since it started.
    ///
    /// Nil too while the item's clock is not running or has not reached its
    /// start: the item `AVPlayerLooper` moves on to reports a stopped clock,
    /// then a time before the lap start, before its first frame shows.
    func offset(from item: AVPlayerItem) -> Double? {
        guard isRunning, !isCrossfading,
            let renderTime = node.lastRenderTime,
            renderTime.isHostTimeValid,
            let playerTime = node.playerTime(forNodeTime: renderTime),
            playerTime.sampleTime >= 0,
            let timebase = item.timebase,
            CMTimebaseGetRate(timebase) > 0,
            CMTimebaseGetTime(timebase).seconds >= itemStart
        else { return nil }
        let heardHostTime =
            renderTime.hostTime + Self.hostTicks(forSeconds: engine.outputNode.presentationLatency)
        let pictureTime = CMSyncConvertTime(
            CMClockMakeHostTimeFromSystemUnits(heardHostTime),
            from: CMClockGetHostTimeClock(),
            to: timebase
        )
        guard pictureTime.isNumeric else { return nil }
        let loop = Double(loopFrames)
        let heardFrame = (Double(startFrame) + Double(playerTime.sampleTime))
            .truncatingRemainder(dividingBy: loop)
        let pictureFrame = ((pictureTime.seconds - itemStart) * sampleRate)
            .truncatingRemainder(dividingBy: loop)
        var difference = heardFrame - pictureFrame
        if difference >= loop / 2 { difference -= loop }
        if difference < -loop / 2 { difference += loop }
        return difference / sampleRate
    }

    /// Stops the loop and the audio hardware behind it. The engine keeps what
    /// it prepared, so [start] brings it back quickly; a paused feed player
    /// can sit in the pool a long time and should hold no running output.
    func pause() {
        crossfadeGeneration += 1
        nodes.forEach { $0.stop() }
        isRunning = false
        isCrossfading = false
        if engine.isRunning { engine.pause() }
    }

    func release() {
        onStoppedByConfigurationChange = nil
        pause()
        engine.stop()
    }

    /// The loop from [frame] to its end, played once ahead of the repeating
    /// buffer so the first lap starts mid-loop.
    private func tail(from frame: AVAudioFramePosition) -> AVAudioPCMBuffer? {
        let remaining = AVAudioFrameCount(AVAudioFramePosition(loopFrames) - frame)
        guard frame > 0, remaining > 0,
            let head = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: remaining),
            let source = buffer.floatChannelData,
            let target = head.floatChannelData
        else { return nil }
        head.frameLength = remaining
        for channel in 0..<Int(buffer.format.channelCount) {
            target[channel].update(from: source[channel] + Int(frame), count: Int(remaining))
        }
        return head
    }

    /// How far ahead of now the node is started, so the host time it is
    /// given is still in the future when the render thread reaches it.
    private static let startLeadSeconds = 0.05

    /// How long after [start] returns the loop's first sample is heard.
    var startToHeardSeconds: TimeInterval {
        Self.startLeadSeconds + engine.outputNode.presentationLatency
    }

    private static func hostTicks(forSeconds seconds: Double) -> UInt64 {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        let nanos = seconds * 1_000_000_000
        return UInt64(max(0, nanos) * Double(info.denom) / Double(info.numer))
    }

    private struct Decoded {
        let samples: [Float]
        let channels: Int
        let sampleRate: Double
        let firstTime: CMTime
    }

    /// The audio track of [url] as interleaved floats, with where its first
    /// sample sits on the clip's timeline.
    private static func decode(url: URL) async -> Decoded? {
        let asset = AVURLAsset(url: url)
        do {
            guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
                return nil
            }
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsNonInterleaved: false,
                AVLinearPCMIsBigEndianKey: false,
            ])
            output.alwaysCopiesSampleData = false
            guard reader.canAdd(output) else { return nil }
            reader.add(output)
            guard reader.startReading() else { return nil }
            var samples: [Float] = []
            var channels = 0
            var sampleRate = 0.0
            var firstTime = CMTime.invalid
            while let sampleBuffer = output.copyNextSampleBuffer() {
                if channels == 0,
                    let description = CMSampleBufferGetFormatDescription(sampleBuffer),
                    let basic = CMAudioFormatDescriptionGetStreamBasicDescription(description)
                {
                    channels = Int(basic.pointee.mChannelsPerFrame)
                    sampleRate = basic.pointee.mSampleRate
                }
                if !firstTime.isValid {
                    firstTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                }
                guard let block = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }
                let length = CMBlockBufferGetDataLength(block)
                var chunk = [Float](repeating: 0, count: length / MemoryLayout<Float>.size)
                chunk.withUnsafeMutableBytes { bytes in
                    _ = CMBlockBufferCopyDataBytes(
                        block,
                        atOffset: 0,
                        dataLength: length,
                        destination: bytes.baseAddress!
                    )
                }
                samples.append(contentsOf: chunk)
            }
            guard reader.status == .completed, channels > 0, channels <= 2, sampleRate > 0,
                firstTime.isNumeric, !samples.isEmpty
            else { return nil }
            return Decoded(
                samples: samples,
                channels: channels,
                sampleRate: sampleRate,
                firstTime: firstTime
            )
        } catch {
            return nil
        }
    }
}
