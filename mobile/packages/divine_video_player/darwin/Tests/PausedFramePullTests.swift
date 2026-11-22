import CoreMedia
import Foundation

/// A slow scrub across a cut flickered between the two clips: priming a
/// paused output steps the item a frame forward and back, and the texture
/// took the step's frame, which before a cut is the next clip's first.
@main
enum PausedFramePullTests {
    static func main() {
        holdsAPausedPictureWhereTheSeekPutIt()
        followsTheClockWhilePlaying()
        followsTheClockOnceAPauseFollowsPlayback()
        followsTheClockOnceTheItemChanges()
        dropsTheStepsFrameOnceThePausedFrameIsUp()
        takesALaterFrameWhileTheTextureHasNoPausedFrame()
        waitsForTheSeekFrameAfterADecoderStepAcrossACut()
        takesEveryFrameWhilePlaying()
        print("Paused frame pull tests passed")
    }

    /// Paused in the last frame of a clip that ends at 1383 ms, while the
    /// priming step has moved the clock onto the next clip's first frame.
    static func holdsAPausedPictureWhereTheSeekPutIt() {
        var pull = PausedFramePull()
        pull.hold(at: ms(1370))
        check(pull.time(playing: false, clock: ms(1383)) == ms(1370), "held while paused")
    }

    static func followsTheClockWhilePlaying() {
        var pull = PausedFramePull()
        pull.hold(at: ms(1370))
        check(pull.time(playing: true, clock: ms(1400)) == ms(1400), "clock while playing")
    }

    /// Playback moved the picture on; a pause without a seek shows where the
    /// clock stopped, not where the last seek had been.
    static func followsTheClockOnceAPauseFollowsPlayback() {
        var pull = PausedFramePull()
        pull.hold(at: ms(1370))
        _ = pull.time(playing: true, clock: ms(1500))
        check(pull.time(playing: false, clock: ms(1700)) == ms(1700), "clock after playing")
    }

    static func followsTheClockOnceTheItemChanges() {
        var pull = PausedFramePull()
        pull.hold(at: ms(1370))
        pull.reset()
        check(pull.time(playing: false, clock: ms(20)) == ms(20), "clock after reset")
    }

    /// Paused at 1370 ms in the last frame of a clip, which went up at
    /// 1366.7 ms; the step then hands over the next clip's first frame.
    static func dropsTheStepsFrameOnceThePausedFrameIsUp() {
        var pull = PausedFramePull()
        pull.hold(at: ms(1370))
        check(pull.accepts(frameAt: frame(41), playing: false), "paused frame")
        check(!pull.accepts(frameAt: ms(1383), playing: false), "step frame after it")
    }

    /// A load held at 21 ms whose first frame went up at 33 ms: an empty
    /// texture takes it rather than staying black.
    static func takesALaterFrameWhileTheTextureHasNoPausedFrame() {
        var pull = PausedFramePull()
        pull.hold(at: ms(21))
        check(pull.accepts(frameAt: frame(1), playing: false), "first frame after the hold")
    }

    static func waitsForTheSeekFrameAfterADecoderStepAcrossACut() {
        var pull = PausedFramePull()
        check(!pull.isAwaitingTargetFrame, "idle without a seek")
        pull.hold(at: ms(1370))
        check(pull.isAwaitingTargetFrame, "waiting before the decoder supplies a frame")
        check(pull.accepts(frameAt: ms(1383), playing: false), "provisional step frame")
        check(pull.isAwaitingTargetFrame, "still waiting after the next clip's frame")
        check(pull.accepts(frameAt: frame(41), playing: false), "late target frame")
        check(!pull.isAwaitingTargetFrame, "idle once the sought frame is up")
    }

    static func takesEveryFrameWhilePlaying() {
        var pull = PausedFramePull()
        pull.hold(at: ms(1370))
        check(pull.accepts(frameAt: frame(41), playing: false), "paused frame")
        check(pull.accepts(frameAt: ms(1383), playing: true), "next frame while playing")
    }

    /// Frame `index` of a 30 fps clip.
    static func frame(_ index: Int64) -> CMTime {
        CMTime(value: index, timescale: 30)
    }

    static func ms(_ value: Int64) -> CMTime {
        CMTime(value: value, timescale: 1000)
    }

    static func check(_ condition: Bool, _ label: String) {
        if !condition {
            print("FAILED: \(label)")
            exit(1)
        }
    }
}
