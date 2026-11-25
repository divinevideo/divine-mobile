import AVFoundation

/// Tells when AVPlayer waits for data.
///
/// AVPlayer keeps its rate while it waits, and says why: to minimize stalls
/// when data is short. It evaluates the buffering rate at the start of every
/// playback, local files included, for about 0.1 s, which is no wait for
/// data; but a seek in the middle of a wait for data passes through that
/// evaluation too, so a wait that began for data counts as one until the
/// player plays or pauses.
struct DataWait {
    private var waitingForData = false

    mutating func isWaiting(
        timeControlStatus: AVPlayer.TimeControlStatus,
        reasonForWaitingToPlay: AVPlayer.WaitingReason?
    ) -> Bool {
        guard timeControlStatus == .waitingToPlayAtSpecifiedRate else {
            waitingForData = false
            return false
        }
        if reasonForWaitingToPlay == .toMinimizeStalls { waitingForData = true }
        return waitingForData
    }
}
