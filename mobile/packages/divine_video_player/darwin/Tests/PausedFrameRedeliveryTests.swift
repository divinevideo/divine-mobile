import CoreMedia
import Foundation

/// A paused output hands its frame over again on every display tick, and
/// each one made the engine composite the same picture: about 60 a second
/// per paused player.
@main
enum PausedFrameRedeliveryTests {
    static func main() {
        deliversAPausedFrameOnce()
        deliversTheNextPausedFrame()
        deliversEveryFrameWhilePlaying()
        deliversThePausedFrameAgainAfterAReset()
        print("Paused frame redelivery tests passed")
    }

    static func deliversAPausedFrameOnce() {
        var redelivery = PausedFrameRedelivery()
        check(redelivery.delivers(frameAt: frame(20), playing: false), "first tick")
        check(!redelivery.delivers(frameAt: frame(20), playing: false), "same frame again")
    }

    /// A seek or step moves a paused picture to another frame.
    static func deliversTheNextPausedFrame() {
        var redelivery = PausedFrameRedelivery()
        _ = redelivery.delivers(frameAt: frame(20), playing: false)
        check(redelivery.delivers(frameAt: frame(21), playing: false), "next frame")
    }

    /// A frame can repeat while playing, when the output hands over nothing
    /// newer; playback keeps its own handling of that.
    static func deliversEveryFrameWhilePlaying() {
        var redelivery = PausedFrameRedelivery()
        check(redelivery.delivers(frameAt: frame(20), playing: true), "playing")
        check(redelivery.delivers(frameAt: frame(20), playing: true), "playing again")
    }

    /// Back from the background, or on a new item, the texture is handed the
    /// frame on screen once more.
    static func deliversThePausedFrameAgainAfterAReset() {
        var redelivery = PausedFrameRedelivery()
        _ = redelivery.delivers(frameAt: frame(20), playing: false)
        redelivery.reset()
        check(redelivery.delivers(frameAt: frame(20), playing: false), "after reset")
    }

    /// Frame `index` of a 30 fps clip.
    static func frame(_ index: Int64) -> CMTime {
        CMTime(value: index, timescale: 30)
    }

    static func check(_ condition: Bool, _ label: String) {
        if !condition {
            print("FAILED: \(label)")
            exit(1)
        }
    }
}
