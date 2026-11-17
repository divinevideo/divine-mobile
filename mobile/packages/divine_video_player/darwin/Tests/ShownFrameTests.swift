import Foundation

/// A detached clip seeked to a paused editor's position showed the frame after
/// the editor's picture whenever the pause fell in the second half of a frame:
/// the seek lands on the nearest frame, the picture holds the one it drew.
@main
enum ShownFrameTests {
    static func main() {
        placesAPauseLateInAFrameOnThatFrame()
        landsInsideAFrameWhoseStartIsNotAWholeMillisecond()
        placesNothingForAFrameFromBeforeASeek()
        placesNothingForATimeThatIsNotANumber()
        print("Shown frame tests passed")
    }

    /// Paused at 0.660 s, the picture holds frame 19, which went up at 0.633 s;
    /// frame 20 at 0.667 s is the nearer one.
    static func placesAPauseLateInAFrameOnThatFrame() {
        check(ShownFrame.seekTargetMilliseconds(frameAt: 19.0 / 30.0, position: 0.660) == 634, "late in frame 19")
    }

    static func landsInsideAFrameWhoseStartIsNotAWholeMillisecond() {
        check(ShownFrame.seekTargetMilliseconds(frameAt: 20.0 / 30.0, position: 0.680) == 667, "frame 20 at 666.67 ms")
    }

    static func placesNothingForAFrameFromBeforeASeek() {
        check(ShownFrame.seekTargetMilliseconds(frameAt: 0.2, position: 1.5) == nil, "stale frame")
    }

    static func placesNothingForATimeThatIsNotANumber() {
        check(ShownFrame.seekTargetMilliseconds(frameAt: .nan, position: 1) == nil, "NaN frame")
        check(ShownFrame.seekTargetMilliseconds(frameAt: 1, position: .infinity) == nil, "infinite position")
    }

    static func check(_ condition: Bool, _ label: String) {
        if !condition {
            print("FAILED: \(label)")
            exit(1)
        }
    }
}
