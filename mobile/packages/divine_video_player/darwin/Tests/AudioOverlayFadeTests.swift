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
        playsTheEnvelopeAtABoostedLevel()
        readsTheFadeFromTheChannelMap()
        dipsWhereTheVolumeCurveDips()
        splitsAStretchWhereFadeAndCurveBothChange()
        runsToTheCurvesEndWhenTheTrackEndIsUnknown()
        readsTheVolumeCurveFromTheChannelMap()
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

    static func playsTheEnvelopeAtABoostedLevel() {
        let fade = AudioOverlayFade(fadeInSec: 1, fadeOutSec: 2)
        precondition(
            fade.ramps(audibleSec: 5, level: 3) == [ramp(0, 1, 0, 3), ramp(3, 5, 3, 0)],
            "\(fade.ramps(audibleSec: 5, level: 3))"
        )
    }

    static func readsTheFadeFromTheChannelMap() {
        let fade = AudioOverlayFade(map: ["fadeInMs": NSNumber(value: 250), "fadeOutMs": NSNumber(value: 1500)])
        precondition(fade == AudioOverlayFade(fadeInSec: 0.25, fadeOutSec: 1.5))
        precondition(AudioOverlayFade(map: [:]).isNone)
    }

    /// The curve is on the video timeline and the ramps on the track's, which
    /// starts half a second in. The ducked stretch keeps a flat ramp, since a
    /// mix holds only the level its last ramp ended at.
    static func dipsWhereTheVolumeCurveDips() {
        let curve = AudioOverlayVolumeCurve(timesSec: [1, 1.25, 3, 3.5], volumes: [1, 0.25, 0.25, 1])
        let ramps = AudioOverlayFade(fadeInSec: 0, fadeOutSec: 0)
            .ramps(audibleSec: 5, level: 1, curve: curve, videoStartSec: 0.5)
        precondition(
            ramps == [ramp(0.5, 0.75, 1, 0.25), ramp(0.75, 2.5, 0.25, 0.25), ramp(2.5, 3, 0.25, 1)],
            "\(ramps)"
        )
    }

    /// A fade in under a falling curve is their product, which is not a
    /// straight line, so the stretch is split into short ramps.
    static func splitsAStretchWhereFadeAndCurveBothChange() {
        let curve = AudioOverlayVolumeCurve(timesSec: [0, 1], volumes: [1, 0.5])
        let ramps = AudioOverlayFade(fadeInSec: 1, fadeOutSec: 0)
            .ramps(audibleSec: 5, level: 2, curve: curve, videoStartSec: 0)
        // The split first second, then the curve's half level held to the end.
        precondition(ramps.count == AudioOverlayFade.productSteps + 1, "\(ramps)")
        precondition(ramps.first!.fromGain == 0)
        // Half-way: fade 0.5 × curve 0.75 × level 2.
        let middle = ramps[AudioOverlayFade.productSteps / 2]
        precondition(abs(middle.fromGain - 0.75) < 1e-9, "\(middle)")
        precondition(ramps.last! == ramp(1, 5, 1, 1), "\(ramps.last!)")
    }

    static func runsToTheCurvesEndWhenTheTrackEndIsUnknown() {
        let curve = AudioOverlayVolumeCurve(timesSec: [2, 2.5], volumes: [1, 0.25])
        let ramps = AudioOverlayFade(fadeInSec: 0, fadeOutSec: 3)
            .ramps(audibleSec: nil, level: 1, curve: curve, videoStartSec: 1)
        precondition(ramps == [ramp(1, 1.5, 1, 0.25)], "\(ramps)")
    }

    static func readsTheVolumeCurveFromTheChannelMap() {
        let curve = AudioOverlayVolumeCurve(map: [
            "volumeCurve": [750, 1, 1000.5, 0.25].map { NSNumber(value: $0) }
        ])
        precondition(curve == AudioOverlayVolumeCurve(timesSec: [0.75, 1.0005], volumes: [1, 0.25]))
        precondition(curve!.volume(atSec: 0) == 1)
        precondition(AudioOverlayVolumeCurve(map: [:]) == nil)
        precondition(AudioOverlayVolumeCurve(map: ["volumeCurve": [NSNumber(value: 1)]]) == nil)
    }

    private static func ramp(
        _ start: Double, _ end: Double, _ from: Double, _ to: Double
    ) -> AudioOverlayFade.Ramp {
        AudioOverlayFade.Ramp(startSec: start, endSec: end, fromGain: from, toGain: to)
    }
}
