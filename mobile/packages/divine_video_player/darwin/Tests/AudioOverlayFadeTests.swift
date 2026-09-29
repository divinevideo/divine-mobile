import Foundation

/// The fade envelope an overlay track plays in the editor preview. It has to
/// match the one `pro_video_editor` bakes into the export — linear ramps from
/// and to silence, the quieter ramp winning where they overlap — or the
/// creator hears one fade while editing and another in the posted video.
@main
enum AudioOverlayFadeTests {
    static func main() {
        rampsAFadeInFromSilence()
        rampsAFadeOutToTheEndOfTheAudio()
        crossesOverlappingFadesAtTheQuieterLevel()
        cutsAFadeLongerThanTheAudioShort()
        needsNoRampWithoutAFade()
        readsTheFadeFromTheChannelMap()
        print("Audio overlay fade tests passed")
    }

    static func rampsAFadeInFromSilence() {
        let fade = AudioOverlayFade(fadeInSec: 1, fadeOutSec: 0)
        precondition(
            fade.ramps(audibleSec: 5) == [ramp(0, 1, 0, 1)],
            "\(fade.ramps(audibleSec: 5))"
        )
        precondition(fade.gain(atSec: 0.25, audibleSec: 5) == 0.25)
    }

    static func rampsAFadeOutToTheEndOfTheAudio() {
        let fade = AudioOverlayFade(fadeInSec: 0.5, fadeOutSec: 2)
        precondition(
            fade.ramps(audibleSec: 5) == [ramp(0, 0.5, 0, 1), ramp(3, 5, 1, 0)],
            "\(fade.ramps(audibleSec: 5))"
        )
    }

    /// Two one-second fades on a one-second track meet half-way at half level
    /// instead of the fade in jumping to full volume where the fade out
    /// starts.
    static func crossesOverlappingFadesAtTheQuieterLevel() {
        let fade = AudioOverlayFade(fadeInSec: 1, fadeOutSec: 1)
        precondition(
            fade.ramps(audibleSec: 1) == [ramp(0, 0.5, 0, 0.5), ramp(0.5, 1, 0.5, 0)],
            "\(fade.ramps(audibleSec: 1))"
        )
    }

    static func cutsAFadeLongerThanTheAudioShort() {
        let fade = AudioOverlayFade(fadeInSec: 4, fadeOutSec: 0)
        precondition(
            fade.ramps(audibleSec: 2) == [ramp(0, 2, 0, 0.5)],
            "\(fade.ramps(audibleSec: 2))"
        )
    }

    static func needsNoRampWithoutAFade() {
        let fade = AudioOverlayFade(fadeInSec: 0, fadeOutSec: 0)
        precondition(fade.isNone)
        precondition(fade.ramps(audibleSec: 5).isEmpty)
    }

    static func readsTheFadeFromTheChannelMap() {
        let fade = AudioOverlayFade(map: ["fadeInMs": NSNumber(value: 250), "fadeOutMs": NSNumber(value: 1500)])
        precondition(fade == AudioOverlayFade(fadeInSec: 0.25, fadeOutSec: 1.5))
        precondition(AudioOverlayFade(map: [:]).isNone)
    }

    private static func ramp(
        _ start: Double, _ end: Double, _ from: Double, _ to: Double
    ) -> AudioOverlayFade.Ramp {
        AudioOverlayFade.Ramp(startSec: start, endSec: end, fromGain: from, toGain: to)
    }
}
