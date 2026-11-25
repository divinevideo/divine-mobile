import Foundation

/// Tells when a playing picture fell behind the player's clock.
///
/// A streamed clip plays through a composition, and AVPlayer does not wait
/// for a composition's data: when the download falls behind, its status stays
/// playing, the clock runs on and the picture holds, or creeps on a frame at a
/// time, until data arrives, then jumps ahead. Only the picture shows the
/// stall.
struct FrozenPicture {
    /// How far the frame on screen may lag the clock; normally under 0.1 s.
    static let lag: TimeInterval = 0.5

    /// How long the picture has to stay that far behind. The first frame after
    /// a forward seek normally arrives within it.
    static let hold: TimeInterval = 0.25

    private var behindSince: TimeInterval?

    /// Whether `frame`, the time of the frame on screen, has stayed at least
    /// [lag] behind `clock`, the player's time, for [hold].
    ///
    /// `now` is a monotonic time in seconds. A player that is not `playing`
    /// starts the watch over.
    mutating func isFrozen(
        frame: Double, clock: Double, now: TimeInterval, playing: Bool
    ) -> Bool {
        guard playing, frame.isFinite, clock.isFinite, clock - frame >= Self.lag else {
            behindSince = nil
            return false
        }
        let since = behindSince ?? now
        behindSince = since
        return now - since >= Self.hold
    }
}
