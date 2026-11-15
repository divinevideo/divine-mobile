import Foundation

/// An overlay seek stands still for a moment before its sound plays on. The
/// sync has to aim its seeks past that stall, or a stall beyond the drift
/// threshold re-seeks the sound every other sync, heard as the music
/// cutting out.
@main
enum AudioOverlaySeekLeadTests {
    static func main() {
        stopsReseekingASoundWhoseSeeksStandStillPastTheThreshold()
        leavesSoundsAtOneRateAloneWhenTheirStallIsUnderTheThreshold()
        learnsTheSameStallFromSoundsSeekingTogether()
        waitsForASeekToPlayBeforeCorrectingIt()
        correctsASoundWhoseSeekNeverPlays()
        learnsNothingFromASoundInTheWrongPlace()
        aimsLessFarAheadAfterASeekOvershoots()
        learnsNothingWhenTheRateChangedSinceTheSeek()
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
            seekId += 1
            pending = lead.seek(id: seekId, onto: now * trackSpeed, rate: trackSpeed, issuedAt: now)
            pending?.landed = true
            player.seek(to: pending!.targetSec, at: now)
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

    /// Three and four sounds at 1x restart together at every lap, and each
    /// seek stands still 0.15 s: under the threshold, so nothing is ever
    /// corrected, and every lap aims the same 0.15 s ahead. Learning from the
    /// estimate another sound had just updated taught 0.15, 0.30, then
    /// 0.45 s, put the next lap 0.3 s ahead and corrected it.
    static func leavesSoundsAtOneRateAloneWhenTheirStallIsUnderTheThreshold() {
        for players in [3, 4] {
            let run = simulateLoop(players: players, rate: 1, stallSec: 0.15, seconds: 32)
            precondition(run.corrections == 0, "\(players) sounds re-seeked \(run.corrections) times")
            for ahead in run.aheadSecAtLapStarts.dropFirst() {
                precondition(abs(ahead - 0.15) < 1e-9, "\(players) sounds aimed \(ahead)s ahead")
            }
        }
    }

    /// Three sounds at 0.8x whose seeks stand still 0.45 s, past the
    /// threshold: each is corrected once in the first lap, the laps after
    /// start on the picture.
    static func learnsTheSameStallFromSoundsSeekingTogether() {
        let run = simulateLoop(players: 3, rate: 0.8, stallSec: 0.45, seconds: 32)
        precondition(run.corrections == 3, "re-seeked \(run.corrections) times")
        for ahead in run.aheadSecAtLapStarts.dropFirst() {
            precondition(abs(ahead - 0.45 * 0.8) < 1e-9, "aimed \(ahead)s ahead")
        }
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

        pending = lead.seek(id: 2, onto: 19.55, rate: 1, issuedAt: 1)
        pending?.landed = true
        _ = lead.needsSeek(
            behindSec: -0.1, trackSpeed: 1, rate: 1, playerSec: 20.1, pending: &pending, now: 1.4)
        precondition(abs(lead.aheadSec(rate: 1) - 0.35) < 1e-9, "\(lead.aheadSec(rate: 1))")
    }

    /// A seek issued at 1x and measured after the speed changed played part
    /// of its file at another pace: its lag says nothing about either rate.
    static func learnsNothingWhenTheRateChangedSinceTheSeek() {
        var lead = AudioOverlaySeekLead()
        var pending: AudioOverlayPendingSeek? = landedSeek(targetSec: 10, issuedAt: 0)
        _ = lead.needsSeek(
            behindSec: 0.1, trackSpeed: 1, rate: 0.5, playerSec: 10.1, pending: &pending, now: 0.6)
        precondition(lead.stallSec.isEmpty, "\(lead.stallSec)")
        precondition(pending == nil)
    }

    /// The time-pitch processing a seek waits for depends on the rate.
    static func learnsEachRateApart() {
        var lead = AudioOverlaySeekLead()
        var pending: AudioOverlayPendingSeek? = landedSeek(targetSec: 10, issuedAt: 0, rate: 0.8)
        _ = lead.needsSeek(
            behindSec: 0.24, trackSpeed: 0.8, rate: 0.8, playerSec: 10.1, pending: &pending,
            now: 0.6)
        precondition(abs(lead.aheadSec(rate: 0.8) - 0.24) < 1e-9, "\(lead.aheadSec(rate: 0.8))")
        precondition(lead.aheadSec(rate: 1) == 0)
    }

    /// [players] sounds at [rate], restarted together at every lap of a
    /// 3.389 s video looping at 1x and synced every 0.2 s for [seconds], the
    /// way the editor plays them; every seek stands still [stallSec].
    private static func simulateLoop(
        players count: Int, rate: Double, stallSec: Double, seconds: Double
    ) -> (corrections: Int, aheadSecAtLapStarts: [Double]) {
        let lap = 3.389
        var lead = AudioOverlaySeekLead()
        var players = Array(repeating: StallingPlayer(rate: rate, stallSec: stallSec), count: count)
        var pending = [AudioOverlayPendingSeek?](repeating: nil, count: count)
        var seekId = 0
        var corrections = 0
        var aheads: [Double] = []
        var lastLap = -1

        func seek(_ index: Int, to expectedSec: Double, at now: Double) {
            seekId += 1
            var seek = lead.seek(id: seekId, onto: expectedSec, rate: rate, issuedAt: now)
            seek.landed = true
            pending[index] = seek
            players[index].seek(to: seek.targetSec, at: now)
        }

        for tick in 1...Int(seconds / 0.2) {
            let now = Double(tick) * 0.2
            let lapIndex = Int(now / lap)
            let expectedSec = now.truncatingRemainder(dividingBy: lap) * rate
            let lapStarts = lapIndex != lastLap
            if lapStarts {
                lastLap = lapIndex
                aheads.append(lead.aheadSec(rate: rate))
            }
            for index in 0..<count {
                if lapStarts {
                    seek(index, to: expectedSec, at: now)
                    continue
                }
                let playerSec = players[index].positionSec(at: now)
                if lead.needsSeek(
                    behindSec: expectedSec - playerSec, trackSpeed: rate, rate: rate,
                    playerSec: playerSec, pending: &pending[index], now: now)
                {
                    corrections += 1
                    seek(index, to: expectedSec, at: now)
                }
            }
        }
        return (corrections, aheads)
    }

    private static func landedSeek(
        targetSec: Double, issuedAt: Double, rate: Double = 1, assumedStallSec: Double = 0
    ) -> AudioOverlayPendingSeek {
        var seek = AudioOverlayPendingSeek(
            id: 1, targetSec: targetSec, rate: rate, assumedStallSec: assumedStallSec,
            issuedAt: issuedAt)
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
