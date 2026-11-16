import AVFoundation
import Foundation

/// [ClipAudioLoop.start] against an engine whose output stops rendering
/// while the engine still reports itself running. `play(at:)` given a host
/// time waits 5 s there for a render cycle and then raises "player did not
/// see an IO cycle", which ends the app. Here the output is stalled by a
/// node whose render blocks, which holds the engine's render thread the way
/// a stopped output does.
///
/// Needs an audio output device, which a CI runner may not have.
@main
enum ClipAudioLoopTests {
    static func main() async {
        guard hasAudioOutput() else {
            print("Clip audio loop tests skipped: no audio output device")
            return
        }
        guard let loop = await makeLoop() else {
            preconditionFailure("could not prepare a loop from a generated tone")
        }
        loop.volume = 0
        // Stopping a loop while its render thread is held blocks for good, so a
        // start that stopped the stalled engine instead of refusing would hang
        // the job until its timeout rather than fail.
        Thread.detachNewThread {
            Thread.sleep(forTimeInterval: 30)
            print("Clip audio loop tests timed out after 30 s")
            exit(1)
        }
        let stall = RenderStall(attachedTo: loop.engine)
        let clock = runningClock()

        startsAgainstARunningClockOnARenderingOutput(loop, clock: clock)
        refusesToStartWhileTheOutputHasStoppedRendering(loop, clock: clock, stall: stall)
        startsAgainOnceTheOutputRenders(loop, clock: clock)

        loop.release()
        print("Clip audio loop tests passed")
    }

    /// The normal path: an engine started by [ClipAudioLoop.start] itself,
    /// then placed again while its output renders, as the drift check does.
    static func startsAgainstARunningClockOnARenderingOutput(
        _ loop: ClipAudioLoop,
        clock: CMTimebase
    ) {
        precondition(loop.start(alignedTo: clock))
        precondition(loop.isRunning)
        waitUntilRendering(loop.engine)
        precondition(loop.start(alignedTo: clock))
    }

    /// Unguarded, this call blocks for 5 s and then aborts the process with
    /// the uncatchable exception the app crashed with.
    static func refusesToStartWhileTheOutputHasStoppedRendering(
        _ loop: ClipAudioLoop,
        clock: CMTimebase,
        stall: RenderStall
    ) {
        stall.begin()
        Thread.sleep(forTimeInterval: 0.6)
        precondition(loop.engine.isRunning, "a stalled engine still reports itself running")
        let started = Date()
        precondition(!loop.start(alignedTo: clock))
        precondition(Date().timeIntervalSince(started) < 1, "start waited for a render cycle")
        precondition(loop.isRunning, "a refused start changes nothing")
        stall.end()
    }

    /// The drift check places the loop again on a later tick, once the
    /// output renders again.
    static func startsAgainOnceTheOutputRenders(_ loop: ClipAudioLoop, clock: CMTimebase) {
        waitUntilRendering(loop.engine)
        precondition(loop.start(alignedTo: clock))
    }

    /// Holds the render thread of [engine] on request, through a silent node
    /// the main mixer pulls on every render cycle.
    final class RenderStall {
        private let requested = DispatchSemaphore(value: 0)
        private let released = DispatchSemaphore(value: 0)

        init(attachedTo engine: AVAudioEngine) {
            let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
            let requested = requested
            let released = released
            let node = AVAudioSourceNode(format: format) { isSilence, _, _, _ in
                if requested.wait(timeout: .now()) == .success { released.wait() }
                isSilence.pointee = true
                return noErr
            }
            engine.attach(node)
            engine.connect(
                node,
                to: engine.mainMixerNode,
                fromBus: 0,
                toBus: engine.mainMixerNode.nextAvailableInputBus,
                format: format
            )
        }

        func begin() { requested.signal() }
        func end() { released.signal() }
    }

    static func hasAudioOutput() -> Bool {
        let engine = AVAudioEngine()
        _ = engine.mainMixerNode
        defer { engine.stop() }
        do {
            try engine.start()
            return true
        } catch {
            return false
        }
    }

    /// A loop over half a second of a quiet tone written to a file.
    static func makeLoop() async -> ClipAudioLoop? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("clip_audio_loop_test_\(UUID().uuidString).caf")
        defer { try? FileManager.default.removeItem(at: url) }
        guard writeTone(to: url) else { return nil }
        return await ClipAudioLoop.make(
            source: ClipAudioLoop.Source(
                url: url,
                fileStart: .zero,
                duration: CMTime(seconds: 0.5, preferredTimescale: 600),
                itemStart: .zero
            )
        )
    }

    static func writeTone(to url: URL) -> Bool {
        let rate = 44_100.0
        let frames = AVAudioFrameCount(rate)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2),
            let fileFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 2, interleaved: true
            ),
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
            let channels = buffer.floatChannelData,
            let file = try? AVAudioFile(
                forWriting: url,
                settings: fileFormat.settings,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )
        else { return false }
        buffer.frameLength = frames
        for frame in 0..<Int(frames) {
            let sample = Float(0.1 * sin(2 * Double.pi * 440 * Double(frame) / rate))
            channels[0][frame] = sample
            channels[1][frame] = sample
        }
        return (try? file.write(from: buffer)) != nil
    }

    /// A clock on the host clock, running at 1x from zero, as a playing
    /// item's timebase does.
    static func runningClock() -> CMTimebase {
        var timebase: CMTimebase?
        CMTimebaseCreateWithSourceClock(
            allocator: kCFAllocatorDefault,
            sourceClock: CMClockGetHostTimeClock(),
            timebaseOut: &timebase
        )
        CMTimebaseSetTime(timebase!, time: .zero)
        CMTimebaseSetRate(timebase!, rate: 1)
        return timebase!
    }

    /// Waits until [engine]'s output has rendered within the last 50 ms.
    static func waitUntilRendering(_ engine: AVAudioEngine) {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if let renderTime = engine.outputNode.lastRenderTime, renderTime.isHostTimeValid,
                AVAudioTime.seconds(forHostTime: mach_absolute_time())
                    - AVAudioTime.seconds(forHostTime: renderTime.hostTime) < 0.05
            {
                return
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
        preconditionFailure("the output did not render within 2 s")
    }
}
