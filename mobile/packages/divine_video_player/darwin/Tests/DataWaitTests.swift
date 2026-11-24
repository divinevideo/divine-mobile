import AVFoundation

/// On an iPhone, a seek in the middle of a wait for data passed through
/// evaluating the buffering rate for about 10 ms, which split one stall into
/// several.
@main
enum DataWaitTests {
    static func main() {
        countsWaitingToMinimizeStalls()
        leavesTheEvaluationThatOpensAStart()
        keepsAWaitForDataThroughASeek()
        endsTheWaitWhenThePlayerPlaysOrPauses()
        leavesAMissingItem()
        print("Data wait tests passed")
    }

    static func countsWaitingToMinimizeStalls() {
        var wait = DataWait()
        check(wait.isWaiting(timeControlStatus: .waitingToPlayAtSpecifiedRate, reasonForWaitingToPlay: .toMinimizeStalls), "to minimize stalls")
    }

    static func leavesTheEvaluationThatOpensAStart() {
        var wait = DataWait()
        check(!wait.isWaiting(timeControlStatus: .waitingToPlayAtSpecifiedRate, reasonForWaitingToPlay: .evaluatingBufferingRate), "evaluating")
        check(!wait.isWaiting(timeControlStatus: .playing, reasonForWaitingToPlay: nil), "playing")
    }

    static func keepsAWaitForDataThroughASeek() {
        var wait = DataWait()
        _ = wait.isWaiting(timeControlStatus: .waitingToPlayAtSpecifiedRate, reasonForWaitingToPlay: .toMinimizeStalls)
        check(wait.isWaiting(timeControlStatus: .waitingToPlayAtSpecifiedRate, reasonForWaitingToPlay: .evaluatingBufferingRate), "seek mid-wait")
        check(wait.isWaiting(timeControlStatus: .waitingToPlayAtSpecifiedRate, reasonForWaitingToPlay: .toMinimizeStalls), "back to waiting")
    }

    static func endsTheWaitWhenThePlayerPlaysOrPauses() {
        for end in [AVPlayer.TimeControlStatus.playing, .paused] {
            var wait = DataWait()
            _ = wait.isWaiting(timeControlStatus: .waitingToPlayAtSpecifiedRate, reasonForWaitingToPlay: .toMinimizeStalls)
            check(!wait.isWaiting(timeControlStatus: end, reasonForWaitingToPlay: nil), "ended by \(end.rawValue)")
            check(!wait.isWaiting(timeControlStatus: .waitingToPlayAtSpecifiedRate, reasonForWaitingToPlay: .evaluatingBufferingRate), "next start after \(end.rawValue)")
        }
    }

    static func leavesAMissingItem() {
        var wait = DataWait()
        check(!wait.isWaiting(timeControlStatus: .waitingToPlayAtSpecifiedRate, reasonForWaitingToPlay: .noItemToPlay), "no item to play")
    }

    static func check(_ condition: Bool, _ label: String) {
        if !condition {
            print("FAILED: \(label)")
            exit(1)
        }
    }
}
