import CoreMedia

/// Keeps a paused texture on the frame a seek or reload put it on.
///
/// Priming a paused output steps the item a frame forward and back, and the
/// step hands the output the frame after the paused one. The texture took it:
/// in the last frame before a cut that is the next clip's first, so a slow
/// scrub there flickered between the two clips.
struct PausedFramePull {
    private var target: CMTime = .invalid

    /// Whether a frame at or before `target` has reached the texture.
    private var hasTargetFrame = false

    /// A provisional step frame can be shown while the target is still due.
    var isAwaitingTargetFrame: Bool { target.isNumeric && !hasTargetFrame }

    /// Holds a paused picture at `time`, where a seek or reload put it.
    mutating func hold(at time: CMTime) {
        target = time
        hasTargetFrame = false
    }

    /// Forgets the held time, as when the output moves to another item.
    mutating func reset() {
        target = .invalid
        hasTargetFrame = false
    }

    /// The time to pull at: the held time while paused, the clock while
    /// playing. Asked for the held time, the output hands over the paused
    /// frame where the stepped clock got the one after it. Playing lets go of
    /// the held time, so a pause that follows without a seek shows where the
    /// clock stopped.
    mutating func time(playing: Bool, clock: CMTime) -> CMTime {
        if playing { reset() }
        return target.isValid ? target : clock
    }

    /// Whether the frame that went up at `frameTime` may replace the picture.
    ///
    /// Paused, a frame that starts after the held time is the step's, and is
    /// dropped once the held time's own frame is up. Before that, any frame
    /// beats an empty or stale texture.
    mutating func accepts(frameAt frameTime: CMTime, playing: Bool) -> Bool {
        guard !playing, target.isValid, frameTime.isNumeric else { return true }
        if CMTimeCompare(frameTime, target) <= 0 {
            hasTargetFrame = true
            return true
        }
        return !hasTargetFrame
    }
}
