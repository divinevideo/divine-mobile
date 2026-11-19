import Foundation

/// Where a paused player's picture sits, as a time that a seek lands on that
/// same frame.
///
/// Paused, the picture holds the frame it last drew, but a zero-tolerance seek
/// lands on the frame nearest its target: for a pause in the second half of a
/// frame, the next one. Anything seeked to the paused position then showed a
/// frame more than the picture.
enum ShownFrame {
    /// A time in milliseconds a seek lands on the frame that went on screen at
    /// `frameSeconds`, or `nil` when that frame is not the one at `seconds`.
    static func seekTargetMilliseconds(frameAt frameSeconds: Double, position seconds: Double) -> Int? {
        guard frameSeconds.isFinite, seconds.isFinite, frameSeconds >= 0 else { return nil }
        // A frame from before a seek, or of another clip.
        guard abs(frameSeconds - seconds) < 0.1 else { return nil }
        // One millisecond in, so a seek that rounds down lands on it as well.
        return Int((frameSeconds * 1000).rounded(.down)) + 1
    }
}
