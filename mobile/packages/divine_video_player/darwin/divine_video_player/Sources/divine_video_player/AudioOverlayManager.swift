import AVFoundation

/// Manages audio overlay tracks that play alongside the main video.
///
/// Each overlay is an independent `AVPlayer` instance positioned and
/// synced to the main video timeline. Drift correction keeps audio
/// aligned within ``driftThreshold``.
///
/// A track's ``AudioOverlayFade`` is played by an `AVAudioMix` on its player
/// item, whose volume ramps run in the item's own time: sample-exact, and
/// untouched by seeks, rate changes and the 0.2 s position sync.
final class AudioOverlayManager {

    private let log = DivineVideoPlayerLog.shared
    private var overlays: [AudioOverlayEntry] = []
    private let driftThreshold: Double = 0.25
    private let logName = "AudioOverlayManager"

    /// Replaces all audio overlays with the given track definitions.
    func setTracks(from tracksRaw: [[String: Any]]) {
        log.info(
            "Replacing audio overlays with \(tracksRaw.count) track(s)",
            name: logName
        )
        disposeAll()

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

            let overlay = AVPlayer(playerItem: AVPlayerItem(url: url))

            let entry = AudioOverlayEntry(
                player: overlay,
                videoStartSec: videoStartMs / 1000.0,
                videoEndSec: videoEndMs.map { $0 / 1000.0 },
                trackStartSec: trackStartMs / 1000.0,
                trackEndSec: trackEndMs.map { $0 / 1000.0 },
                trackIndex: index,
                baseVolume: vol,
                fade: AudioOverlayFade(map: map)
            )
            applyVolume(to: entry)
            attachFadeMix(to: entry)
            overlays.append(entry)
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
        overlays[index].baseVolume = volume
        applyVolume(to: overlays[index])
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

    /// Releases all overlay players and clears the list.
    func disposeAll() {
        guard !overlays.isEmpty else { return }
        log.debug("Disposing \(overlays.count) audio overlay(s)", name: logName)
        for entry in overlays {
            entry.player.pause()
            entry.player.replaceCurrentItem(with: nil)
        }
        overlays.removeAll()
    }

    /// Sets the player's own volume: the track's level, or silence while a
    /// fade in waits for its mix, so a start inside the fade does not play
    /// its first moments at full level.
    private func applyVolume(to entry: AudioOverlayEntry) {
        let holdsSilent = entry.isAwaitingFadeMix && entry.fade.fadeInSec > 0
        entry.player.volume = holdsSilent ? 0 : entry.baseVolume
    }

    /// Puts the track's fade on its player item as an `AVAudioMix`.
    ///
    /// The mix needs the file's audio track and duration, which load
    /// asynchronously; a local file resolves them long before the 0.2 s
    /// position sync first starts the overlay.
    private func attachFadeMix(to entry: AudioOverlayEntry) {
        guard !entry.fade.isNone, let item = entry.player.currentItem else { return }
        entry.isAwaitingFadeMix = true
        applyVolume(to: entry)
        let asset = item.asset
        Task { @MainActor [weak self, weak entry] in
            let track = try? await asset.loadTracks(withMediaType: .audio).first
            let fileDuration = try? await asset.load(.duration)
            guard let self, let entry, entry.player.currentItem === item else { return }
            entry.isAwaitingFadeMix = false
            defer { self.applyVolume(to: entry) }
            guard let track else {
                self.log.warning(
                    "Audio overlay track \(entry.trackIndex): no audio track, playing without fade",
                    name: self.logName
                )
                return
            }
            let parameters = AVMutableAudioMixInputParameters(track: track)
            for ramp in self.fadeRamps(for: entry, fileDuration: fileDuration) {
                parameters.setVolumeRamp(
                    fromStartVolume: Float(ramp.fromGain),
                    toEndVolume: Float(ramp.toGain),
                    timeRange: CMTimeRange(
                        start: self.itemTime(entry.trackStartSec + ramp.startSec),
                        end: self.itemTime(entry.trackStartSec + ramp.endSec)
                    )
                )
            }
            let mix = AVMutableAudioMix()
            mix.inputParameters = [parameters]
            item.audioMix = mix
            self.log.debug(
                "Audio overlay track \(entry.trackIndex): fade in \(entry.fade.fadeInSec)s, " +
                    "fade out \(entry.fade.fadeOutSec)s attached",
                name: self.logName
            )
        }
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
        guard let audibleSec = ends.min() else {
            let fadeInOnly = AudioOverlayFade(fadeInSec: entry.fade.fadeInSec, fadeOutSec: 0)
            return fadeInOnly.ramps(audibleSec: entry.fade.fadeInSec)
        }
        return entry.fade.ramps(audibleSec: audibleSec)
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

/// Holds one audio overlay player and its scheduling metadata.
final class AudioOverlayEntry {
    let player: AVPlayer
    let videoStartSec: Double
    let videoEndSec: Double?
    let trackStartSec: Double
    let trackEndSec: Double?
    var isActive: Bool = false
    let trackIndex: Int
    /// The track's volume before its fade is applied.
    var baseVolume: Float
    let fade: AudioOverlayFade
    /// Whether the fade's audio mix is still loading.
    var isAwaitingFadeMix: Bool = false
    var lastPlayerStatus: AVPlayer.Status?
    var lastItemStatus: AVPlayerItem.Status?
    var lastItemErrorDescription: String?

    init(
        player: AVPlayer,
        videoStartSec: Double,
        videoEndSec: Double?,
        trackStartSec: Double,
        trackEndSec: Double?,
        trackIndex: Int,
        baseVolume: Float = 1.0,
        fade: AudioOverlayFade = AudioOverlayFade(fadeInSec: 0, fadeOutSec: 0)
    ) {
        self.player = player
        self.videoStartSec = videoStartSec
        self.videoEndSec = videoEndSec
        self.trackStartSec = trackStartSec
        self.trackEndSec = trackEndSec
        self.trackIndex = trackIndex
        self.baseVolume = baseVolume
        self.fade = fade
    }
}
