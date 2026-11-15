import Foundation

/// Keeps an audio overlay's seeks from leaving it behind the picture.
///
/// An `AVPlayer` clock stands still for a moment after every seek before its
/// sound plays on: about 0.1 s for a plain sound on a phone speaker, more for
/// a sound at its own speed through the spectral time-pitch algorithm, and
/// over 0.4 s on a Bluetooth route. The sound resumes that far behind the
/// picture. Where that is beyond ``driftThresholdSec``, correcting it with
/// another seek stalls it again, and the overlay was re-seeked every 0.4 s,
/// heard as the music cutting out every few hundred milliseconds.
///
/// So a seek aims ahead by how long the last seek at the same rate stood
/// still, measured once its clock moves again, and a sound whose seek has not
/// played yet is not corrected.
struct AudioOverlaySeekLead {

    /// How far, in seconds of video, a sound may be off the picture before
    /// it is seeked back onto it.
    static let driftThresholdSec = 0.25

    /// How long a seek may take to play before its sound is corrected anyway.
    static let restartTimeoutSec = 1.0

    /// The longest stall a seek is trusted to explain. A sound further off
    /// than that is in the wrong place, not restarting.
    static let maxStallSec = 1.0

    /// How far past its seek's target a player's clock must have moved to
    /// count as playing again, in seconds of its file.
    static let resumedSec = 0.01

    /// How long, in seconds of wall time, a seek stood still at a player
    /// rate, by the rate in hundredths. The rate decides the time-pitch
    /// processing a restart waits for.
    private(set) var stallSec: [Int: Double] = [:]

    /// How far ahead of where the sound belongs a seek at [rate] aims, in
    /// seconds of its file: what it plays while its clock stands still.
    func aheadSec(rate: Double) -> Double {
        (stallSec[Self.key(rate)] ?? 0) * rate
    }

    /// A seek at [rate] onto [sec] of the player's file, the place the sound
    /// belongs now, aimed ``aheadSec(rate:)`` past it. It keeps the stall it
    /// assumed, so what it measures is its own stall, whatever other tracks
    /// have learned since.
    func seek(id: Int, onto sec: Double, rate: Double, issuedAt: TimeInterval)
        -> AudioOverlayPendingSeek
    {
        let stall = stallSec[Self.key(rate)] ?? 0
        return AudioOverlayPendingSeek(
            id: id,
            targetSec: max(sec + stall * rate, 0),
            rate: rate,
            assumedStallSec: stall,
            issuedAt: issuedAt
        )
    }

    /// Whether a playing sound, [behindSec] seconds of its file behind where
    /// it belongs, is to be seeked onto the picture.
    ///
    /// While its [pending] seek has yet to play it is left alone, for up to
    /// ``restartTimeoutSec``. Once its clock has moved past the seek's target,
    /// the stall the seek assumed plus how far behind the sound still is was
    /// that seek's stall, kept for the next seek at its rate. Tracks that
    /// seek together at one rate each measure their own stall, so they teach
    /// the same value instead of adding up.
    mutating func needsSeek(
        behindSec: Double,
        trackSpeed: Double,
        rate: Double,
        playerSec: Double,
        pending: inout AudioOverlayPendingSeek?,
        now: TimeInterval
    ) -> Bool {
        guard rate > 0, trackSpeed > 0 else { return false }
        if let seek = pending {
            if seek.landed, playerSec > seek.targetSec + Self.resumedSec {
                pending = nil
                // A rate changed since the seek plays its file at another
                // pace than the one its stall was assumed for.
                let key = Self.key(seek.rate)
                if key == Self.key(rate), abs(behindSec / rate) <= Self.maxStallSec {
                    let stall = seek.assumedStallSec + behindSec / rate
                    stallSec[key] = min(max(stall, 0), Self.maxStallSec)
                }
            } else if now - seek.issuedAt < Self.restartTimeoutSec {
                return false
            } else {
                pending = nil
            }
        }
        return abs(behindSec) / trackSpeed > Self.driftThresholdSec
    }

    private static func key(_ rate: Double) -> Int { Int((rate * 100).rounded()) }
}

/// A seek of an overlay's player that has not played yet.
struct AudioOverlayPendingSeek {
    /// Tells this seek's completion from a later seek's.
    let id: Int
    /// Where it seeks to, in the time of the file the player has.
    let targetSec: Double
    /// The player rate it was issued at.
    let rate: Double
    /// The stall it was aimed past, in seconds of wall time.
    let assumedStallSec: Double
    /// When it was issued, in seconds of system uptime.
    let issuedAt: TimeInterval
    /// Whether it completed. An interrupted seek is dropped instead.
    var landed = false
}
