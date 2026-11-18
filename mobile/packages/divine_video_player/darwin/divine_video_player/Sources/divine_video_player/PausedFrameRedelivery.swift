import CoreMedia

/// Whether a display tick hands its frame to the texture.
///
/// A paused output hands over the frame on screen again on every tick. Each
/// one marked the texture as changed, so a paused player had the engine
/// composite it, and frame effects drawn over it, about 60 times a second for
/// the same picture. Paused, a tick delivers a frame only when it is not the
/// one it delivered last.
struct PausedFrameRedelivery {
    private var delivered: CMTime = .invalid

    /// Lets the next tick deliver whatever frame it pulls: after a seek, a
    /// new item or a return from the background.
    mutating func reset() {
        delivered = .invalid
    }

    /// Whether the frame that went up at `frameTime`, pulled on a tick, goes
    /// to the texture. Playing, every frame does.
    mutating func delivers(frameAt frameTime: CMTime, playing: Bool) -> Bool {
        guard !playing, frameTime.isNumeric else {
            reset()
            return true
        }
        if frameTime == delivered { return false }
        delivered = frameTime
        return true
    }
}
