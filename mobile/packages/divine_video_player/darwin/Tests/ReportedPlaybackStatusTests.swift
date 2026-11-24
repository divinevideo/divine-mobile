import Foundation

/// AVPlayer keeps its rate while it waits for data, so a stall was reported as
/// `playing` and never reached Dart as `buffering`.
@main
enum ReportedPlaybackStatusTests {
    static func main() {
        reportsAWaitForDataAsBuffering()
        reportsAFrozenPictureAsBuffering()
        reportsPlaybackAsPlaying()
        keepsAnErrorOrTheEndOverAWait()
        reportsAPausedPlayer()
        print("Reported playback status tests passed")
    }

    static func reportsAWaitForDataAsBuffering() {
        check(status(waitsForData: true) == "buffering", "waiting for data")
    }

    static func reportsAFrozenPictureAsBuffering() {
        check(status(pictureFrozen: true) == "buffering", "frozen picture")
    }

    static func reportsPlaybackAsPlaying() {
        check(status() == "playing", "playing")
    }

    static func keepsAnErrorOrTheEndOverAWait() {
        for current in ["error", "completed"] {
            check(status(current: current, waitsForData: true) == current, "\(current) while waiting")
            check(status(current: current, pictureFrozen: true) == current, "\(current) while frozen")
        }
    }

    static func reportsAPausedPlayer() {
        check(status(rate: 0) == "paused", "paused")
        check(status(rate: 0, bufferEmpty: true) == "buffering", "paused, empty")
        check(status(current: "idle", rate: 0) == "idle", "not loaded yet")
    }

    static func status(
        current: String = "ready",
        rate: Float = 1,
        waitsForData: Bool = false,
        pictureFrozen: Bool = false,
        bufferEmpty: Bool = false
    ) -> String {
        ReportedPlaybackStatus.status(
            current: current,
            rate: rate,
            waitsForData: waitsForData,
            pictureFrozen: pictureFrozen,
            isPlaybackBufferEmpty: bufferEmpty)
    }

    static func check(_ condition: Bool, _ label: String) {
        if !condition {
            print("FAILED: \(label)")
            exit(1)
        }
    }
}
