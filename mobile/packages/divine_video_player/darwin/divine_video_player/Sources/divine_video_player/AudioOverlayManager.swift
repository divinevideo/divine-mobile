import AVFoundation

/// Manages audio overlay tracks that play alongside the main video.
///
/// Each overlay is an independent `AVPlayer` instance positioned and
/// synced to the main video timeline. Drift correction keeps audio
/// aligned within ``driftThreshold``.
///
/// A track's ``AudioOverlayFade`` is played by an `AVAudioMix` on its player
/// item, whose volume ramps run in the item's own time: sample-exact, and
/// untouched by seeks, rate changes and the 0.2 s position sync. Its
/// ``AudioEqualizer`` is rendered into a copy of its sound that the player
/// plays instead; see ``EqualizedAudioFile``.
final class AudioOverlayManager {

    private let log = DivineVideoPlayerLog.shared
    private var overlays: [AudioOverlayEntry] = []
    private let driftThreshold: Double = 0.25
    private let logName = "AudioOverlayManager"

    /// Equalized copies of the tracks' sounds, by source and equalizer. Kept
    /// while a track plays one, so tracks set again — the editor sets them
    /// anew on every confirmed change — play theirs at once.
    private var equalizedFiles: [EqualizedFileKey: URL] = [:]

    /// Local copies of remote sources, for equalizing them again.
    private var downloads: [URL: URL] = [:]

    /// How long a changed equalizer has to stay put before it is rendered. A
    /// slider passes through several values a second, and every swap to a
    /// new copy is heard as a short gap; Android settles its looped clip
    /// audio over the same 500 ms.
    private let equalizerSettleSeconds = 0.5

    /// Called when a track's sound was swapped while it should be playing,
    /// so the owner can sync it to the picture again at once.
    var onNeedsSync: (() -> Void)?

    /// Replaces all audio overlays with the given track definitions.
    func setTracks(from tracksRaw: [[String: Any]]) {
        log.info(
            "Replacing audio overlays with \(tracksRaw.count) track(s)",
            name: logName
        )
        disposePlayers()
        defer { evictUnusedFiles() }

        for (index, map) in tracksRaw.enumerated() {
            guard let uri = map["uri"] as? String else {
                log.warning(
                    "Audio overlay track \(index): skipping track with no uri",
                    name: logName
                )
                continue
            }
            let vol = (map["volume"] as? NSNumber)?.floatValue ?? 1.0
            let videoStartMs = (map["videoStartMs"] as? NSNumber)?.doubleValue ?? 0
            let videoEndMs = (map["videoEndMs"] as? NSNumber)?.doubleValue
            let trackStartMs = (map["trackStartMs"] as? NSNumber)?.doubleValue ?? 0
            let trackEndMs = (map["trackEndMs"] as? NSNumber)?.doubleValue

            let url: URL
            if uri.hasPrefix("/") {
                url = URL(fileURLWithPath: uri)
            } else if let parsed = URL(string: uri) {
                url = parsed
            } else {
                log.warning(
                    "Audio overlay track \(index): skipping invalid uri",
                    name: logName
                )
                continue
            }

            let equalizer = AudioEqualizer.from(map["equalizer"])
            let equalizedFile = equalizer.flatMap {
                equalizedFiles[EqualizedFileKey(source: url, equalizer: $0)]
            }
            let overlay = AVPlayer(playerItem: AVPlayerItem(url: equalizedFile ?? url))

            let entry = AudioOverlayEntry(
                player: overlay,
                source: url,
                videoStartSec: videoStartMs / 1000.0,
                videoEndSec: videoEndMs.map { $0 / 1000.0 },
                trackStartSec: trackStartMs / 1000.0,
                trackEndSec: trackEndMs.map { $0 / 1000.0 },
                trackIndex: index,
                baseVolume: vol,
                fade: AudioOverlayFade(map: map),
                equalizer: equalizer
            )
            overlays.append(entry)
            if equalizedFile != nil {
                entry.playingEqualizer = equalizer
            } else if equalizer != nil {
                // Silent until its copy is ready, rather than heard unequalized.
                entry.isAwaitingEqualizer = true
                renderEqualizer(for: entry, after: 0)
            }
            applyVolume(to: entry)
            attachMix(to: entry)
        }
    }

    /// Sets volume for the overlay at `index`.
    func setTrackVolume(at index: Int, volume: Float) {
        guard index >= 0, index < overlays.count else {
            log.warning(
                "Audio overlay index \(index): volume update out of bounds",
                name: logName
            )
            return
        }
        log.debug(
            "Audio overlay track \(overlays[index].trackIndex): volume set to \(volume)",
            name: logName
        )
        let entry = overlays[index]
        let previousBoost = entry.boost
        entry.baseVolume = volume
        applyVolume(to: entry)
        if entry.boost != previousBoost { attachMix(to: entry) }
    }

    /// Sets the equalizer of the overlay at `index`; nil plays it unchanged.
    ///
    /// The track keeps playing what it played until the equalizer has stayed
    /// put for ``equalizerSettleSeconds`` and its copy is rendered.
    func setTrackEqualizer(at index: Int, equalizer: AudioEqualizer?) {
        guard index >= 0, index < overlays.count else { return }
        let entry = overlays[index]
        guard entry.equalizer != equalizer else { return }
        entry.equalizer = equalizer
        renderEqualizer(for: entry, after: equalizerSettleSeconds)
    }

    /// Gives `entry` the sound its equalizer asks for, [delay] seconds from
    /// now unless the equalizer changes again first: its own file, or an
    /// equalized copy, rendered off the main thread when none is kept.
    private func renderEqualizer(for entry: AudioOverlayEntry, after delay: Double) {
        entry.equalizerGeneration += 1
        let generation = entry.equalizerGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak entry] in
            guard let self, let entry, generation == entry.equalizerGeneration else { return }
            guard let equalizer = entry.equalizer else {
                self.play(entry, file: entry.source, equalizer: nil)
                return
            }
            let key = EqualizedFileKey(source: entry.source, equalizer: equalizer)
            if let file = self.equalizedFiles[key] {
                self.play(entry, file: file, equalizer: equalizer)
                return
            }
            let source = entry.source
            let download = self.downloads[source]
            Task { @MainActor [weak self, weak entry] in
                let rendered = await Task.detached(priority: .userInitiated) {
                    () -> (local: URL?, file: URL?) in
                    let local: URL?
                    if let download {
                        local = download
                    } else {
                        local = await EqualizedAudioFile.localCopy(of: source)
                    }
                    guard let local else { return (nil, nil) }
                    return (local, await EqualizedAudioFile.render(source: local, equalizer: equalizer))
                }.value
                guard let self else {
                    rendered.file.map { try? FileManager.default.removeItem(at: $0) }
                    return
                }
                if !source.isFileURL, let local = rendered.local {
                    if let kept = self.downloads[source], kept != local {
                        try? FileManager.default.removeItem(at: local)
                    } else {
                        self.downloads[source] = local
                    }
                }
                if let file = rendered.file { self.equalizedFiles[key] = file }
                guard let entry, generation == entry.equalizerGeneration,
                    self.overlays.contains(where: { $0 === entry })
                else {
                    self.evictUnusedFiles()
                    return
                }
                guard let file = rendered.file else {
                    self.log.warning(
                        "Audio overlay track \(entry.trackIndex): could not equalize its sound, "
                            + "playing it unchanged",
                        name: self.logName
                    )
                    entry.isAwaitingEqualizer = false
                    self.applyVolume(to: entry)
                    return
                }
                self.play(entry, file: file, equalizer: equalizer)
            }
        }
    }

    /// Swaps `entry`'s sound for [file], which plays [equalizer], and has a
    /// track that was playing synced to the picture again.
    private func play(_ entry: AudioOverlayEntry, file: URL, equalizer: AudioEqualizer?) {
        entry.isAwaitingEqualizer = false
        guard entry.playingEqualizer != equalizer else {
            applyVolume(to: entry)
            return
        }
        let wasActive = entry.isActive
        entry.player.pause()
        entry.isActive = false
        entry.player.replaceCurrentItem(with: AVPlayerItem(url: file))
        entry.playingEqualizer = equalizer
        entry.mixInputs = nil
        applyVolume(to: entry)
        attachMix(to: entry)
        evictUnusedFiles()
        log.info(
            "Audio overlay track \(entry.trackIndex): plays "
                + (equalizer == nil ? "its own sound" : "an equalized copy"),
            name: logName
        )
        if wasActive { onNeedsSync?() }
    }

    /// Deletes the equalized copies and downloads no track plays any more.
    private func evictUnusedFiles() {
        let playing = Set(
            overlays.compactMap { entry in
                entry.playingEqualizer.map { EqualizedFileKey(source: entry.source, equalizer: $0) }
            })
        for (key, file) in equalizedFiles where !playing.contains(key) {
            try? FileManager.default.removeItem(at: file)
            equalizedFiles[key] = nil
        }
        let sources = Set(overlays.map(\.source))
        for (source, file) in downloads where !sources.contains(source) {
            try? FileManager.default.removeItem(at: file)
            downloads[source] = nil
        }
    }

    /// Resumes playback of currently active overlays at the given speed.
    func resumeActive(speed: Double) {
        for entry in overlays where entry.isActive {
            log.info(
                "Audio overlay track \(entry.trackIndex): resuming at speed \(speed)",
                name: logName
            )
            entry.player.play()
            entry.player.rate = Float(speed)
            reportStatusIfChanged(for: entry, context: "resume")
        }
    }

    /// Pauses all overlay players and marks them inactive.
    func pauseAndDeactivateAll() {
        for entry in overlays {
            entry.player.pause()
            // Report the deactivation, not the call: pause arrives on every
            // stop and every pause tap, and re-logging already-idle tracks
            // spends bug-report capacity on a non-event.
            guard entry.isActive else { continue }
            entry.isActive = false
            log.info(
                "Audio overlay track \(entry.trackIndex): paused and deactivated",
                name: logName
            )
        }
    }

    /// Updates playback speed on currently active overlay players.
    func setSpeed(_ speed: Double) {
        for entry in overlays where entry.isActive {
            entry.player.rate = Float(speed)
        }
    }

    /// Syncs every overlay track to the current global video position.
    ///
    /// Starts, pauses, or drift-corrects each overlay based on whether
    /// the video position falls within that track's active range.
    func update(videoPositionSec: Double, isPlaying: Bool, speed: Double) {
        guard !overlays.isEmpty else { return }
        // Runs every 0.2 seconds on the main queue for every player instance.
        // Console-only so user bug reports retain capacity for state
        // transitions and failures, and debug-only because a console trace
        // never reaches a bug report in the first place.
        #if DEBUG
        print("[AudioOverlay] update: position \(videoPositionSec)")
        #endif
        for entry in overlays {
            reportStatusIfChanged(for: entry, context: "update")
            let inRange = videoPositionSec >= entry.videoStartSec &&
                (entry.videoEndSec == nil || videoPositionSec < entry.videoEndSec!)

            if inRange && isPlaying {
                let expectedAudioSec = entry.trackStartSec +
                    (videoPositionSec - entry.videoStartSec)

                // Clamp to trackEnd if set.
                if let trackEnd = entry.trackEndSec, expectedAudioSec >= trackEnd {
                    if entry.isActive {
                        entry.player.pause()
                        entry.isActive = false
                        log.info(
                            "Audio overlay track \(entry.trackIndex): reached track end",
                            name: logName
                        )
                    }
                    continue
                }

                if !entry.isActive {
                    let audioTime = CMTime(seconds: expectedAudioSec, preferredTimescale: 600)
                    log.info(
                        "Audio overlay track \(entry.trackIndex): starting playback " +
                            "at \(expectedAudioSec)s, speed \(speed)",
                        name: logName
                    )
                    seek(entry, to: audioTime, reason: "playback start")
                    entry.player.play()
                    entry.player.rate = Float(speed)
                    entry.isActive = true
                    reportStatusIfChanged(for: entry, context: "playback start")
                } else {
                    // Correct drift.
                    let actualSec = CMTimeGetSeconds(entry.player.currentTime())
                    let drift = abs(expectedAudioSec - actualSec)
                    if drift > driftThreshold {
                        #if DEBUG
                        print(
                            "[AudioOverlay] track \(entry.trackIndex): " +
                                "drift correction \(drift)s"
                        )
                        #endif
                        let audioTime = CMTime(seconds: expectedAudioSec, preferredTimescale: 600)
                        seek(entry, to: audioTime, reason: "drift correction")
                    }
                }
            } else {
                if entry.isActive {
                    entry.player.pause()
                    entry.isActive = false
                    log.info(
                        "Audio overlay track \(entry.trackIndex): paused outside active range",
                        name: logName
                    )
                }
            }
        }
    }

    /// Releases all overlay players, clears the list and deletes the files
    /// rendered or downloaded for them.
    func disposeAll() {
        disposePlayers()
        evictUnusedFiles()
    }

    private func disposePlayers() {
        guard !overlays.isEmpty else { return }
        log.debug("Disposing \(overlays.count) audio overlay(s)", name: logName)
        for entry in overlays {
            entry.player.pause()
            entry.player.replaceCurrentItem(with: nil)
        }
        overlays.removeAll()
    }

    /// Sets the player's own volume: the track's level up to 100 %, or
    /// silence while a fade in waits for its mix, so a start inside the fade
    /// does not play its first moments at full level, and while its first
    /// equalized copy renders. The level above 100 % is the mix's; see
    /// [attachMix].
    private func applyVolume(to entry: AudioOverlayEntry) {
        let holdsSilent =
            (entry.isAwaitingMix && entry.fade.fadeInSec > 0) || entry.isAwaitingEqualizer
        entry.player.volume = holdsSilent ? 0 : min(entry.baseVolume, 1)
    }

    /// Puts the track's fade and its boost above 100 % on its player item as
    /// an `AVAudioMix`, which amplifies where `AVPlayer.volume` is not known
    /// to: the export applies the same mix volumes.
    ///
    /// The mix needs the file's audio track and duration, which load
    /// asynchronously; a local file resolves them long before the 0.2 s
    /// position sync first starts the overlay. The fade and boost are read
    /// once they have, so the latest of overlapping calls wins. They are kept
    /// after that, so a later call — a volume dragged live — swaps the mix in
    /// at once and never holds a fading track silent while it reloads.
    private func attachMix(to entry: AudioOverlayEntry) {
        guard let item = entry.player.currentItem else { return }
        guard !entry.fade.isNone || entry.boost > 1 else {
            item.audioMix = nil
            return
        }
        // Once the track is loaded the mix is rebuilt at once, so a volume
        // dragged live never waits on, or goes silent for, a reload.
        if let inputs = entry.mixInputs, inputs.item === item {
            setMix(on: item, for: entry, track: inputs.track, fileDuration: inputs.fileDuration)
            return
        }
        entry.isAwaitingMix = true
        applyVolume(to: entry)
        let asset = item.asset
        Task { @MainActor [weak self, weak entry] in
            let track = try? await asset.loadTracks(withMediaType: .audio).first
            let fileDuration = try? await asset.load(.duration)
            guard let self, let entry, entry.player.currentItem === item else { return }
            entry.isAwaitingMix = false
            defer { self.applyVolume(to: entry) }
            guard let track else {
                self.log.warning(
                    "Audio overlay track \(entry.trackIndex): no audio track, playing without fade",
                    name: self.logName
                )
                return
            }
            entry.mixInputs = (item, track, fileDuration)
            self.setMix(on: item, for: entry, track: track, fileDuration: fileDuration)
        }
    }

    /// Puts `entry`'s current fade and boost on `item` as its audio mix.
    private func setMix(
        on item: AVPlayerItem,
        for entry: AudioOverlayEntry,
        track: AVAssetTrack,
        fileDuration: CMTime?
    ) {
        let boost = entry.boost
        let ramps = fadeRamps(for: entry, fileDuration: fileDuration)
        let parameters = AVMutableAudioMixInputParameters(track: track)
        // The level the track holds between ramps. Only set where no ramp
        // starts: AVFoundation rejects overlapping volume changes with an
        // Objective-C exception, which aborts the process.
        if boost > 1, ramps.first.map({ entry.trackStartSec + $0.startSec > 0 }) ?? true {
            parameters.setVolume(boost, at: .zero)
        }
        for ramp in ramps {
            parameters.setVolumeRamp(
                fromStartVolume: Float(ramp.fromGain),
                toEndVolume: Float(ramp.toGain),
                timeRange: CMTimeRange(
                    start: itemTime(entry.trackStartSec + ramp.startSec),
                    end: itemTime(entry.trackStartSec + ramp.endSec)
                )
            )
        }
        let mix = AVMutableAudioMix()
        mix.inputParameters = [parameters]
        item.audioMix = mix
        log.debug(
            "Audio overlay track \(entry.trackIndex): fade in \(entry.fade.fadeInSec)s, " +
                "fade out \(entry.fade.fadeOutSec)s, boost \(boost) attached",
            name: logName
        )
    }

    /// The fade ramps of `entry`, in seconds from its trim start.
    ///
    /// The fade out ends where the track stops sounding: the end of its slot
    /// on the video timeline, the end of its trimmed audio, or the end of the
    /// file, whichever comes first. With none of them known only the fade in
    /// can be placed.
    private func fadeRamps(
        for entry: AudioOverlayEntry,
        fileDuration: CMTime?
    ) -> [AudioOverlayFade.Ramp] {
        var ends: [Double] = []
        if let videoEnd = entry.videoEndSec { ends.append(videoEnd - entry.videoStartSec) }
        if let trackEnd = entry.trackEndSec { ends.append(trackEnd - entry.trackStartSec) }
        if let fileDuration, fileDuration.isNumeric, fileDuration.seconds.isFinite {
            ends.append(fileDuration.seconds - entry.trackStartSec)
        }
        let level = Double(entry.boost)
        guard let audibleSec = ends.min() else {
            let fadeInOnly = AudioOverlayFade(fadeInSec: entry.fade.fadeInSec, fadeOutSec: 0)
            return fadeInOnly.ramps(audibleSec: entry.fade.fadeInSec, level: level)
        }
        return entry.fade.ramps(audibleSec: audibleSec, level: level)
    }

    private func itemTime(_ seconds: Double) -> CMTime {
        CMTime(seconds: max(seconds, 0), preferredTimescale: 44_100)
    }

    private func seek(_ entry: AudioOverlayEntry, to time: CMTime, reason: String) {
        entry.player.seek(
            to: time,
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self, weak entry] completed in
            // AVFoundation does not document which queue delivers this, and
            // AVPlayer is not thread-safe. Every other read and write of
            // overlay state happens on the main queue, so hop back before
            // touching the entry's last-reported status fields.
            DispatchQueue.main.async {
                guard let self, let entry else { return }
                let message = "Audio overlay track \(entry.trackIndex): " +
                    "\(reason) seek completed=\(completed)"
                if completed {
                    self.log.debug(message, name: self.logName)
                } else {
                    self.log.warning(message, name: self.logName)
                }
                self.reportStatusIfChanged(
                    for: entry,
                    context: "\(reason) seek"
                )
            }
        }
    }

    private func reportStatusIfChanged(
        for entry: AudioOverlayEntry,
        context: String
    ) {
        let playerStatus = entry.player.status
        let itemStatus = entry.player.currentItem?.status
        let itemError = entry.player.currentItem?.error
        let itemErrorDescription = itemError.map { error in
            let nsError = error as NSError
            return "\(nsError.domain)(\(nsError.code)): \(nsError.localizedDescription)"
        }

        guard playerStatus != entry.lastPlayerStatus ||
            itemStatus != entry.lastItemStatus ||
            itemErrorDescription != entry.lastItemErrorDescription
        else {
            return
        }

        entry.lastPlayerStatus = playerStatus
        entry.lastItemStatus = itemStatus
        entry.lastItemErrorDescription = itemErrorDescription

        let errorDescription = itemErrorDescription ?? "none"
        let message = "Audio overlay track \(entry.trackIndex): \(context), " +
            "player.status=\(String(describing: playerStatus)), " +
            "currentItem.status=\(String(describing: itemStatus)), " +
            "currentItem.error=\(errorDescription)"
        if playerStatus == .failed || itemStatus == .failed || itemError != nil {
            log.error(message, name: logName)
        } else {
            log.info(message, name: logName)
        }
    }
}

/// An equalized copy of a sound; see ``EqualizedAudioFile``.
struct EqualizedFileKey: Hashable {
    let source: URL
    let equalizer: AudioEqualizer
}

/// Holds one audio overlay player and its scheduling metadata.
final class AudioOverlayEntry {
    let player: AVPlayer
    /// The track's own sound, which its player plays unless equalized.
    let source: URL
    let videoStartSec: Double
    let videoEndSec: Double?
    let trackStartSec: Double
    let trackEndSec: Double?
    var isActive: Bool = false
    let trackIndex: Int
    /// The track's volume before its fade is applied, above 1 when boosted.
    var baseVolume: Float
    let fade: AudioOverlayFade
    /// Whether the fade and boost's audio mix is still loading.
    var isAwaitingMix: Bool = false
    /// What the mix is built from, once loaded for `item`; see `attachMix`.
    var mixInputs: (item: AVPlayerItem, track: AVAssetTrack, fileDuration: CMTime?)?

    /// The part of [baseVolume] above 100 %, as a gain; 1 when there is none.
    var boost: Float { max(baseVolume, 1) }
    /// The equalizer the track is to play with.
    var equalizer: AudioEqualizer?
    /// The equalizer of the sound its player has now: nil for [source]
    /// itself, otherwise an equalized copy.
    var playingEqualizer: AudioEqualizer?
    /// Whether the track waits, silent, for its first equalized copy.
    var isAwaitingEqualizer = false
    /// Bumped by every equalizer change, so a render still running belongs
    /// to the latest.
    var equalizerGeneration = 0
    var lastPlayerStatus: AVPlayer.Status?
    var lastItemStatus: AVPlayerItem.Status?
    var lastItemErrorDescription: String?

    init(
        player: AVPlayer,
        source: URL,
        videoStartSec: Double,
        videoEndSec: Double?,
        trackStartSec: Double,
        trackEndSec: Double?,
        trackIndex: Int,
        baseVolume: Float = 1.0,
        fade: AudioOverlayFade = AudioOverlayFade(fadeInSec: 0, fadeOutSec: 0),
        equalizer: AudioEqualizer? = nil
    ) {
        self.player = player
        self.source = source
        self.videoStartSec = videoStartSec
        self.videoEndSec = videoEndSec
        self.trackStartSec = trackStartSec
        self.trackEndSec = trackEndSec
        self.trackIndex = trackIndex
        self.baseVolume = baseVolume
        self.fade = fade
        self.equalizer = equalizer
    }
}
