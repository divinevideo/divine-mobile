import AVFoundation
import Foundation

/// Where an overlay track's file plays at a moment of the video. A track
/// with its own speed has to land where `pro_video_editor` exports it — its
/// trim in the file, its slot and fades in the video — or the preview plays
/// a different stretch of the song than the posted video.
@main
enum AudioOverlayEntryTests {
    static func main() {
        playsTheFileOneToOneAtNormalSpeed()
        advancesTheFileFasterThanTheVideoWhenSpedUp()
        advancesTheFileSlowerThanTheVideoWhenSlowedDown()
        print("Audio overlay entry tests passed")
    }

    static func playsTheFileOneToOneAtNormalSpeed() {
        let entry = entry(speed: 1)
        precondition(entry.audioSec(atVideoSec: 7) == 12, "\(entry.audioSec(atVideoSec: 7))")
        precondition(entry.fileSec(ofVideoSec: 3) == 3)
        precondition(entry.videoSec(ofFileSec: 3) == 3)
    }

    /// Two seconds into its slot, a track at 2x has played four seconds of
    /// the file past its trim start.
    static func advancesTheFileFasterThanTheVideoWhenSpedUp() {
        let entry = entry(speed: 2)
        precondition(entry.audioSec(atVideoSec: 7) == 14, "\(entry.audioSec(atVideoSec: 7))")
        precondition(entry.fileSec(ofVideoSec: 3) == 6)
        precondition(entry.videoSec(ofFileSec: 6) == 3)
    }

    static func advancesTheFileSlowerThanTheVideoWhenSlowedDown() {
        let entry = entry(speed: 0.5)
        precondition(entry.audioSec(atVideoSec: 7) == 11, "\(entry.audioSec(atVideoSec: 7))")
        precondition(entry.fileSec(ofVideoSec: 3) == 1.5)
        precondition(entry.videoSec(ofFileSec: 1.5) == 3)
    }

    /// A track whose slot starts at video second 5 and whose trim starts at
    /// file second 10.
    private static func entry(speed: Double) -> AudioOverlayEntry {
        AudioOverlayEntry(
            player: AVPlayer(),
            source: URL(fileURLWithPath: "/song.m4a"),
            videoStartSec: 5,
            videoEndSec: 20,
            trackStartSec: 10,
            trackEndSec: nil,
            speed: speed,
            trackIndex: 0
        )
    }
}
