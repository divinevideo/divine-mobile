import Foundation

/// The playback status a player reports to Dart.
enum ReportedPlaybackStatus {
    /// The status for a player in the state given.
    ///
    /// AVPlayer keeps its rate while it waits for data, so a rate above zero
    /// does not mean the picture moves. A wait for data ([DataWait]) is
    /// reported as `buffering`, as ExoPlayer's buffering state is on Android,
    /// and so is a picture that fell behind a clock that ran on
    /// ([FrozenPicture]).
    static func status(
        current: String,
        rate: Float,
        waitsForData: Bool,
        pictureFrozen: Bool,
        isPlaybackBufferEmpty: Bool
    ) -> String {
        if current == "error" || current == "completed" { return current }
        if rate > 0 { return waitsForData || pictureFrozen ? "buffering" : "playing" }
        if isPlaybackBufferEmpty { return "buffering" }
        if current == "ready" && rate == 0 { return "paused" }
        return current
    }
}
