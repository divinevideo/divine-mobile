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

    /// Whether a playing sound, [behindSec] seconds of its file behind where
    /// it belongs, is to be seeked onto the picture.
    ///
    /// While its [pending] seek has yet to play it is left alone, for up to
    /// ``restartTimeoutSec``. Once its clock has moved past the seek's target,
    /// how far behind it still is was the stall of that seek, learned for
    /// the next seek at [rate].
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
                let key = Self.key(rate)
                let stall = (stallSec[key] ?? 0) + behindSec / rate
                if abs(behindSec / rate) <= Self.maxStallSec {
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
    /// When it was issued, in seconds of system uptime.
    let issuedAt: TimeInterval
    /// Whether it completed. An interrupted seek is dropped instead.
    var landed = false
}
