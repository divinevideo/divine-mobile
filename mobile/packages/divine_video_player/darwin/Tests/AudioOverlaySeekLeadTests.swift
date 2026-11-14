import Foundation

/// An overlay seek stands still for a moment before its sound plays on. The
/// sync has to aim its seeks past that stall, or a stall beyond the drift
/// threshold re-seeks the sound every other sync, heard as the music
/// cutting out.
@main
enum AudioOverlaySeekLeadTests {
    static func main() {
        stopsReseekingASoundWhoseSeeksStandStillPastTheThreshold()
        waitsForASeekToPlayBeforeCorrectingIt()
        correctsASoundWhoseSeekNeverPlays()
        learnsNothingFromASoundInTheWrongPlace()
        aimsLessFarAheadAfterASeekOvershoots()
        learnsEachRateApart()
        print("Audio overlay seek lead tests passed")
    }

    /// A sound at 0.8x on a route where every seek stands still 0.45 s,
    /// synced every 0.2 s for 8 s of a 1x video, the way the editor's 0.4 s
    /// re-seek loop was found. One correction teaches the stall; after it
    /// the sound stays on the picture.
    static func stopsReseekingASoundWhoseSeeksStandStillPastTheThreshold() {
        let trackSpeed = 0.8
        var lead = AudioOverlaySeekLead()
        var player = StallingPlayer(rate: trackSpeed, stallSec: 0.45)
        var pending: AudioOverlayPendingSeek?
        var corrections = 0
        var seekId = 0

        func seek(at now: Double) {
            let target = now * trackSpeed + lead.aheadSec(rate: trackSpeed)
            player.seek(to: target, at: now)
            seekId += 1
            pending = AudioOverlayPendingSeek(id: seekId, targetSec: target, issuedAt: now)
            pending?.landed = true
        }

        seek(at: 0)
        var lastBehindSec = 0.0
        for tick in 1...40 {
            let now = Double(tick) * 0.2
            let playerSec = player.positionSec(at: now)
            lastBehindSec = now * trackSpeed - playerSec
            if lead.needsSeek(
                behindSec: lastBehindSec, trackSpeed: trackSpeed, rate: trackSpeed,
                playerSec: playerSec, pending: &pending, now: now)
            {
                corrections += 1
                seek(at: now)
            }
        }
        precondition(corrections == 1, "re-seeked \(corrections) times")
        precondition(abs(lastBehindSec) < 0.01, "ends \(lastBehindSec)s off the picture")
    }

    static func waitsForASeekToPlayBeforeCorrectingIt() {
        var lead = AudioOverlaySeekLead()
        var pending: AudioOverlayPendingSeek? = landedSeek(targetSec: 10, issuedAt: 0)
        let corrects = lead.needsSeek(
            behindSec: 0.4, trackSpeed: 1, rate: 1, playerSec: 10, pending: &pending, now: 0.4)
        precondition(!corrects)
        precondition(pending != nil)
        precondition(lead.stallSec.isEmpty)
    }

    static func correctsASoundWhoseSeekNeverPlays() {
        var lead = AudioOverlaySeekLead()
        var pending: AudioOverlayPendingSeek? = landedSeek(targetSec: 10, issuedAt: 0)
        let corrects = lead.needsSeek(
            behindSec: 1, trackSpeed: 1, rate: 1, playerSec: 10, pending: &pending,
            now: AudioOverlaySeekLead.restartTimeoutSec)
        precondition(corrects)
        precondition(pending == nil)
        precondition(lead.stallSec.isEmpty)
    }

    /// Three seconds off is a sound in the wrong place, not one restarting.
    static func learnsNothingFromASoundInTheWrongPlace() {
        var lead = AudioOverlaySeekLead()
        var pending: AudioOverlayPendingSeek? = landedSeek(targetSec: 10, issuedAt: 0)
        let corrects = lead.needsSeek(
            behindSec: 3, trackSpeed: 1, rate: 1, playerSec: 10.2, pending: &pending, now: 0.4)
        precondition(corrects)
        precondition(lead.aheadSec(rate: 1) == 0, "\(lead.aheadSec(rate: 1))")
    }

    static func aimsLessFarAheadAfterASeekOvershoots() {
        var lead = AudioOverlaySeekLead()
        var pending: AudioOverlayPendingSeek? = landedSeek(targetSec: 10, issuedAt: 0)
        _ = lead.needsSeek(
            behindSec: 0.45, trackSpeed: 1, rate: 1, playerSec: 10.1, pending: &pending, now: 0.6)
        precondition(abs(lead.aheadSec(rate: 1) - 0.45) < 1e-9, "\(lead.aheadSec(rate: 1))")

        pending = landedSeek(targetSec: 20, issuedAt: 1)
        _ = lead.needsSeek(
            behindSec: -0.1, trackSpeed: 1, rate: 1, playerSec: 20.1, pending: &pending, now: 1.4)
        precondition(abs(lead.aheadSec(rate: 1) - 0.35) < 1e-9, "\(lead.aheadSec(rate: 1))")
    }

    /// The time-pitch processing a seek waits for depends on the rate.
    static func learnsEachRateApart() {
        var lead = AudioOverlaySeekLead()
        var pending: AudioOverlayPendingSeek? = landedSeek(targetSec: 10, issuedAt: 0)
        _ = lead.needsSeek(
            behindSec: 0.24, trackSpeed: 0.8, rate: 0.8, playerSec: 10.1, pending: &pending,
            now: 0.6)
        precondition(abs(lead.aheadSec(rate: 0.8) - 0.24) < 1e-9, "\(lead.aheadSec(rate: 0.8))")
        precondition(lead.aheadSec(rate: 1) == 0)
    }

    private static func landedSeek(targetSec: Double, issuedAt: Double) -> AudioOverlayPendingSeek {
        var seek = AudioOverlayPendingSeek(id: 1, targetSec: targetSec, issuedAt: issuedAt)
        seek.landed = true
        return seek
    }
}

/// A player whose clock stands still for [stallSec] after every seek, then
/// plays on at [rate].
private struct StallingPlayer {
    let rate: Double
    let stallSec: Double
    private var targetSec = 0.0
    private var seekedAt = 0.0

    init(rate: Double, stallSec: Double) {
        self.rate = rate
        self.stallSec = stallSec
    }

    mutating func seek(to sec: Double, at now: Double) {
        targetSec = sec
        seekedAt = now
    }

    func positionSec(at now: Double) -> Double {
        targetSec + max(now - seekedAt - stallSec, 0) * rate
    }
}
