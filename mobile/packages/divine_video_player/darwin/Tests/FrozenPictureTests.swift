import Foundation

/// On an iPhone a streamed clip whose download fell behind kept reporting
/// playing while its clock ran from 3.3 s to 14.4 s and the picture crept from
/// 3.3 s to 4.2 s; only the picture showed the stall.
@main
enum FrozenPictureTests {
    static func main() {
        reportsAPictureThatStaysBehindTheClock()
        keepsAPictureThatKeepsUp()
        ignoresAPictureThatIsBehindForAMoment()
        leavesAClockThatStandsStill()
        startsOverOnceThePlayerStops()
        ignoresATimeThatIsNotANumber()
        print("Frozen picture tests passed")
    }

    /// The frames that trickle in during the stall do not end it; catching up
    /// with the clock does.
    static func reportsAPictureThatStaysBehindTheClock() {
        var picture = FrozenPicture()
        check(!picture.isFrozen(frame: 3.47, clock: 4.2, now: 10, playing: true), "just fell behind")
        check(picture.isFrozen(frame: 3.47, clock: 4.5, now: 10.3, playing: true), "still behind")
        check(picture.isFrozen(frame: 3.60, clock: 5.5, now: 11.3, playing: true), "a frame trickled in")
        check(!picture.isFrozen(frame: 16.97, clock: 17.0, now: 23, playing: true), "caught up")
    }

    static func keepsAPictureThatKeepsUp() {
        var picture = FrozenPicture()
        for step in 0..<60 {
            let time = Double(step) / 30
            check(
                !picture.isFrozen(frame: time, clock: time + 0.1, now: 100 + time, playing: true),
                "frame \(step)")
        }
    }

    /// A forward seek leaves the clock past the frame until the next one.
    static func ignoresAPictureThatIsBehindForAMoment() {
        var picture = FrozenPicture()
        check(!picture.isFrozen(frame: 1.0, clock: 3.0, now: 5, playing: true), "seeked")
        check(!picture.isFrozen(frame: 3.0, clock: 3.1, now: 5.1, playing: true), "frame arrived")
        check(!picture.isFrozen(frame: 3.0, clock: 3.6, now: 5.2, playing: true), "behind again, briefly")
    }

    /// A start that reports playing while its clock stands still is the
    /// stale-playback detector's case, not a frozen picture.
    static func leavesAClockThatStandsStill() {
        var picture = FrozenPicture()
        for step in 0..<20 {
            check(
                !picture.isFrozen(frame: 1.0, clock: 1.2, now: 5 + Double(step) * 0.2, playing: true),
                "tick \(step)")
        }
    }

    static func startsOverOnceThePlayerStops() {
        var picture = FrozenPicture()
        _ = picture.isFrozen(frame: 2.0, clock: 2.6, now: 5, playing: true)
        check(!picture.isFrozen(frame: 2.0, clock: 2.6, now: 9, playing: false), "paused")
        check(!picture.isFrozen(frame: 2.0, clock: 2.7, now: 9.1, playing: true), "resumed")
        check(picture.isFrozen(frame: 2.0, clock: 3.0, now: 9.4, playing: true), "held after resuming")
    }

    static func ignoresATimeThatIsNotANumber() {
        var picture = FrozenPicture()
        check(!picture.isFrozen(frame: .nan, clock: 5, now: 5, playing: true), "no frame yet")
        check(!picture.isFrozen(frame: .nan, clock: 6, now: 6, playing: true), "still no frame")
    }

    static func check(_ condition: Bool, _ label: String) {
        if !condition {
            print("FAILED: \(label)")
            exit(1)
        }
    }
}
