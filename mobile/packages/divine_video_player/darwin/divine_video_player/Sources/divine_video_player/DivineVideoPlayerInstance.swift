import AVFoundation
#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif

/// Wraps a single AVQueuePlayer fed by an `AVMutableComposition` that
/// stitches multiple clips into a seamless timeline.
///
/// Communicates with Dart via per-player MethodChannel/EventChannel.
final class DivineVideoPlayerInstance: NSObject, FlutterStreamHandler, PlaybackDiagnosticResource {

    private var diagnosticDisposed = false
    private var diagnosticPendingLoads = 0
    var playbackDiagnosticState: PlaybackDiagnosticState {
        PlaybackDiagnosticState(
            disposed: diagnosticDisposed,
            hasPlayer: player != nil,
            isPlaying: (player?.rate ?? 0) != 0,
            hasTexture: textureOutput != nil,
            pendingLoads: diagnosticPendingLoads
        )
    }

    private let playerId: Int
    /// Identifies this player in diagnostic logs.
    ///
    /// Mirrors the Dart side's `_logTarget` so a `Player 665404 (feed[0])`
    /// line reads the same whichever half of the channel emitted it.
    private let logTarget: String
    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel

    private var player: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?

    /// The range `AVPlayerLooper` repeats, when that is shorter than the item.
    ///
    /// The direct path plays the asset untouched, so unlike the composition it
    /// cannot cut the common track end into a time range. Without this range
    /// the loop runs on to the end of the container, and over the stretch where
    /// the shorter track has already run out the picture stands still —
    /// measured on the simulator as 86 ms of held frame per lap.
    private var loopTimeRange: CMTimeRange?
    private var templateItem: AVPlayerItem?
    private var eventSink: FlutterEventSink?
    private var timeObserver: Any?
    private var currentItemObservation: NSKeyValueObservation?

    /// The edge-declick mix built for the loaded item — composition or direct —
    /// kept so it can be re-applied to every item `AVPlayerLooper` makes.
    ///
    /// The looper does not replay the template item — it builds its own copies,
    /// and a copy does not carry the template's `audioMix`. Setting it once at
    /// load time therefore declicks the first lap and no other, which is
    /// exactly the lap nobody is listening for.
    private var loopAudioMix: AVAudioMix?
    /// Bumped at the start of each `setClips` call, before that call awaits.
    /// A call that resumes after a newer one has started must not install —
    /// publishing its mix earlier would let prewarm stamp that mix onto the
    /// item still looping — and answers CANCELLED, as on Android.
    private var setClipsGeneration = 0

    /// The looping clip's audio, played outside the player once decoded; see
    /// [ClipAudioLoop]. The player is muted while it plays.
    private var clipAudioLoop: ClipAudioLoop?
    private var clipAudioGeneration = 0
    private var clipAudioSyncTimer: Timer?
    private var clipAudioSyncTicks = 0
    private var clipAudioStartRetry: DispatchWorkItem?
    private var clipAudioTakeover: DispatchWorkItem?
    private var timeControlObservation: NSKeyValueObservation?

    /// The local file whose audio is decoded into the loop, with the stretch
    /// of it one lap plays: the clip itself on the direct path, or the
    /// download [remoteClipLoader] kept of a streamed one. `AVAssetReader`
    /// refuses a remote asset.
    private var clipLoopSource: ClipAudioLoop.Source?

    /// Where the first lap starts on the item when the clip was cut to its
    /// first frame (see [lapStartPastEmptyEdits]), otherwise nil.
    private var firstFrameStart: CMTime?

    /// The longest empty edit ahead of the first frame that a looping clip is
    /// started past — the same bound Android applies.
    private static let maxLeadingEmptyEditSeconds = 0.1

    /// Streams a single remote clip to the player through a download it
    /// keeps; see [CachingAssetLoader].
    private var remoteClipLoader: CachingAssetLoader?

    /// A player item and everything the instance holds for it once it is
    /// installed. Builders return this instead of writing the instance's
    /// fields, so a build that overlaps another cannot leave its state behind
    /// on an item it did not build.
    private struct BuiltItem {
        let item: AVPlayerItem
        let offsets: [Double]
        let durations: [Double]
        var loopTimeRange: CMTimeRange?
        var firstFrameStart: CMTime?
        var loopSource: ClipAudioLoop.Source?
        var streamedLoop: StreamedLoop?
    }

    /// A streamed clip's download, and the stretch of the file one lap plays
    /// once it is written out.
    private struct StreamedLoop {
        let loader: CachingAssetLoader
        let fileStart: CMTime
        let duration: CMTime
    }
    private var statusObservation: NSKeyValueObservation?
    private var bufferingObservation: NSKeyValueObservation?
    private var likelyToKeepUpObservation: NSKeyValueObservation?
    /// One-shot KVO that defers `preroll(atRate:)` until `player.status`
    /// is `.readyToPlay`; calling earlier throws `NSInvalidArgumentException`.
    private var pendingPrerollObservation: NSKeyValueObservation?
    private var setClipsTimeoutWorkItem: DispatchWorkItem?
    private var bufferingWatchdogWorkItem: DispatchWorkItem?
    private var bufferingStallReported = false

    private static let setClipsTimeoutMs = 10_000
    private static let bufferingStallMs = 8_000
    private static let maxCommonTrackEndTrimMs = 500.0
    private static let maxCommonTrackEndTrimRatio = 0.10
    /// Length of the fade applied to each outer edge of the composition.
    ///
    /// A loop restart cuts from the composition's last sample straight back to
    /// its first, and that cut has never been tied to a zero crossing — it
    /// comes from a trim or a recording length. Unless both edges happen to
    /// sit near silence the step is audible as a click.
    ///
    /// The length is set by AVFoundation, not by taste. A volume ramp shorter
    /// than about 25 ms is not honoured over its own time range: it is
    /// stretched to that floor, so it never reaches its end value where it was
    /// asked to. Rendering a composition through this mix and dividing by the
    /// same composition rendered without it gives the gain actually applied to
    /// the last sample — the one the loop joins:
    ///
    ///     fade 10 ms -> 0.6034      fade 25 ms -> 0.0037
    ///     fade 20 ms -> 0.2032      fade 30 ms -> 0.0008
    ///
    /// At 10 ms the join still carries 60% of full amplitude, which is the
    /// click this was meant to remove. The floor measured 24.8 ms at both
    /// 44.1 kHz and 48 kHz, so it is a duration rather than a block of frames;
    /// 30 ms clears it and is still short enough not to read as a level
    /// change. The Android player has no such floor — it fades decoded frames
    /// — and stays at 10 ms, where its fade doubles as its audio latency.
    private static let edgeDeclickFadeSeconds = 0.030
    /// Timescale the audio mix's ramps are laid out in.
    private static let audioMixTimescale: CMTimeScale = 600

    /// Half of [duration], in whole [audioMixTimescale] ticks, toward zero.
    ///
    /// Bounds a fade against the clip it has to fit inside twice, so the cap
    /// must never overstate the clip: a half that rounded up while the clip
    /// rounded down would put the two fades over each other, and AVFoundation
    /// rejects overlapping ramps with an Objective-C
    /// NSInvalidArgumentException, which is not a Swift `Error` and would
    /// abort the process.
    ///
    /// Converted explicitly rather than through `CMTimeMakeWithSeconds`, which
    /// today truncates but whose rounding *direction* CMTime.h does not
    /// specify — the header only says the result may be rounded. Taking the
    /// exact `CMTime` the composition was built from also skips the lossy
    /// round trip through `Double` seconds.
    private static func halfFadeTicks(_ duration: CMTime?) -> Int64 {
        guard let duration, duration.isNumeric, duration.value > 0 else { return 0 }
        return CMTimeConvertScale(
            duration,
            timescale: audioMixTimescale,
            method: .roundTowardZero
        ).value / 2
    }

    /// A mix that fades [track] in from [loopStart] and out to [loopEnd] over
    /// [edgeDeclickFadeSeconds] each — the composition's edge fades, for a
    /// clip played straight from its asset. Nil for a clip too short to carry
    /// two fades.
    private static func edgeDeclickMix(
        track: AVAssetTrack,
        loopStart: CMTime,
        loopEnd: CMTime
    ) -> AVAudioMix? {
        let maxFadeTicks =
            Int64((edgeDeclickFadeSeconds * Double(audioMixTimescale)).rounded())
        let fadeTicks = min(maxFadeTicks, halfFadeTicks(CMTimeSubtract(loopEnd, loopStart)))
        guard fadeTicks > 0 else { return nil }
        let fade = CMTime(value: fadeTicks, timescale: audioMixTimescale)
        let fadeInEnd = CMTimeAdd(loopStart, fade)
        let flatEnd = CMTimeSubtract(loopEnd, fade)
        let params = AVMutableAudioMixInputParameters(track: track)
        // Silent up to the lap start, which a lap cut past an empty edit
        // opens after zero; the fade-in starts where each lap does.
        if CMTimeCompare(loopStart, .zero) > 0 {
            params.setVolume(0, at: .zero)
        }
        params.setVolumeRamp(
            fromStartVolume: 0,
            toEndVolume: 1,
            timeRange: CMTimeRange(start: loopStart, end: fadeInEnd)
        )
        if CMTimeCompare(flatEnd, fadeInEnd) > 0 {
            params.setVolumeRamp(
                fromStartVolume: 1,
                toEndVolume: 1,
                timeRange: CMTimeRange(start: fadeInEnd, end: flatEnd)
            )
        }
        // Ends exactly on loopEnd, the sample the looper joins.
        params.setVolumeRamp(
            fromStartVolume: 1,
            toEndVolume: 0,
            timeRange: CMTimeRange(start: flatEnd, end: loopEnd)
        )
        let mix = AVMutableAudioMix()
        mix.inputParameters = [params]
        return mix
    }

    /// AVFoundation's asset-option key for per-asset HTTP request headers.
    ///
    /// Headers supplied under this key propagate to *every* HTTP request
    /// AVFoundation derives from the asset — the HLS master/variant playlists,
    /// the media segments, and AES key requests — so a single hash-bound
    /// viewer-auth token authenticates gated HLS playback end-to-end without an
    /// `AVAssetResourceLoaderDelegate`. The key is an established but
    /// historically undocumented `String`; AVFoundation exposes no typed symbol
    /// for it, hence the literal. (The Android player has no equivalent
    /// propagation and instead re-derives the token per request via
    /// `httpHeadersForRequest` / `blobHashFromUrl`.)
    private static let avURLAssetHTTPHeaderFieldsKey = "AVURLAssetHTTPHeaderFieldsKey"

    // MARK: - Texture rendering

    /// Non-nil when the player renders into a Flutter texture instead of
    /// a platform view.
    private var textureOutput: VideoTextureOutput?

    /// Offsets of each clip on the global timeline (seconds).
    private var clipOffsets: [Double] = []
    /// Clip durations on the global timeline (seconds).
    private var clipDurations: [Double] = []
    private var clipCount: Int = 0
    private var totalDuration: Double = 0
    private var isLooping: Bool = false
    private var volume: Double = 1.0
    private var speed: Double = 1.0
    private var currentStatus: String = "idle"
    private var errorMessage: String?
    private var errorCode: String?
    private var firstFrameRendered: Bool = false
    private var videoWidth: Int = 0
    private var videoHeight: Int = 0
    /// While paused after an exact seek or composition swap, AVPlayer can settle
    /// one decoded frame behind the requested time during preroll/texture
    /// refresh. Keep reporting the requested timeline position until playback
    /// catches up or another seek replaces it, so Dart's timeline does not drift.
    private var reportedPositionOverrideMs: Int64?

    /// Audio overlay manager for synchronized audio tracks.
    private let audioOverlayManager = AudioOverlayManager()

    init(
        messenger: FlutterBinaryMessenger,
        playerId: Int,
        debugLabel: String? = nil
    ) {
        self.playerId = playerId
        logTarget = debugLabel.map { "Player \(playerId) (\($0))" }
            ?? "Player \(playerId)"

        methodChannel = FlutterMethodChannel(
            name: "divine_video_player/player_\(playerId)",
            binaryMessenger: messenger
        )
        eventChannel = FlutterEventChannel(
            name: "divine_video_player/player_\(playerId)/events",
            binaryMessenger: messenger
        )

        super.init()

        methodChannel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
        eventChannel.setStreamHandler(self)
    }

    /// Enables texture-based rendering for this player.
    ///
    /// Must be called before any clips are loaded. Returns the texture
    /// ID that Dart should pass to the `Texture` widget.
    func enableTextureOutput(registry: FlutterTextureRegistry) -> Int64 {
        let output = VideoTextureOutput(registry: registry) { [weak self] in
            guard let self, !self.firstFrameRendered else { return }
            self.firstFrameRendered = true
            self.sendStateUpdate()
        }
        // Recovery for compositor dead zones: if the 600 ms force window
        // delivers no frame, the seek landed on a time with no renderable
        // frame (e.g. exact boundary between composition segments). Retry
        // with a small tolerance to snap to the nearest decodable frame.
        output.onSeekStuck = { [weak self] stuckTime in
            guard let self else { return }
            self.player?.seek(
                to: stuckTime,
                toleranceBefore: CMTime(value: 1, timescale: 10),
                toleranceAfter: CMTime(value: 1, timescale: 10)
            ) { [weak self] _ in
                guard let self else { return }
                let actualTime = self.player?.currentTime() ?? stuckTime
                self.textureOutput?.forceRefresh(for: actualTime, isRetry: true)
                self.safePreroll(at: actualTime)
            }
        }
        textureOutput = output
        return output.textureId
    }

    // MARK: - MethodChannel handler

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setClips":
            handleSetClips(call, result: result)
        case "play":
            player?.play()
            player?.rate = Float(speed)
            audioOverlayManager.resumeActive(speed: speed)
            result(nil)
        case "pause":
            player?.pause()
            audioOverlayManager.pauseAndDeactivateAll()
            result(nil)
        case "stop":
            handleStop(result: result)
        case "seekTo":
            handleSeekTo(call, result: result)
        case "setVolume":
            handleSetVolume(call, result: result)
        case "setPlaybackSpeed":
            handleSetPlaybackSpeed(call, result: result)
        case "setLooping":
            handleSetLooping(call, result: result)
        case "jumpToClip":
            handleJumpToClip(call, result: result)
        case "setAudioTracks":
            handleSetAudioTracks(call, result: result)
        case "removeAllAudioTracks":
            handleRemoveAllAudioTracks(result: result)
        case "setAudioTrackVolume":
            handleSetAudioTrackVolume(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Clip composition

    /// Answers a `setClips` caller whose load was cancelled because the
    /// instance was disposed while it was suspended in an await.
    ///
    /// `DivineVideoPlayerController` swallows `CANCELLED`, so an awaiting
    /// caller is unblocked without surfacing an error — the same contract the
    /// Android instance uses. Never drop the result: `await setClips()` would
    /// stay pending for the life of the process.
    private func answerCancelledSetClips(
        _ result: @escaping FlutterResult,
        reason: String = "Disposed during setClips"
    ) {
        result(
            FlutterError(
                code: "CANCELLED",
                message: reason,
                details: nil
            )
        )
    }

    /// Whether the setClips call numbered [generation] was overtaken by a
    /// newer one, or the instance disposed, while it awaited — and if so
    /// answers it, drops [built]'s download and reports true.
    private func abandonsSetClips(
        _ generation: Int,
        built: BuiltItem? = nil,
        result: @escaping FlutterResult
    ) -> Bool {
        if diagnosticDisposed {
            if built?.streamedLoop?.loader !== remoteClipLoader {
                built?.streamedLoop?.loader.cancel()
            }
            answerCancelledSetClips(result)
            return true
        }
        guard generation != setClipsGeneration else { return false }
        if built?.streamedLoop?.loader !== remoteClipLoader {
            built?.streamedLoop?.loader.cancel()
        }
        answerCancelledSetClips(result, reason: "Superseded by a newer setClips")
        return true
    }

    private func handleSetClips(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
            let clipsRaw = args["clips"] as? [[String: Any]]
        else {
            result(
                FlutterError(code: "INVALID_ARGS", message: "clips required", details: nil)
            )
            return
        }

        armSetClipsTimeout()
        setClipsGeneration += 1
        let callGeneration = setClipsGeneration
        releaseClipAudioLoop()
        clipLoopSource = nil

        // Build the player item asynchronously.
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.diagnosticPendingLoads += 1
            defer { self.diagnosticPendingLoads -= 1 }
            do {
                // The direct path is the better one, but it cannot represent
                // every clip — a rotated video needs the composition's layer
                // instruction. It reports that itself.
                var direct: BuiltItem?
                if let clip = Self.soleDirectItemClip(in: clipsRaw) {
                    do {
                        direct = try await self.makeDirectPlayerItem(from: clip)
                    } catch CompositionError.directItemNotApplicable {
                        direct = nil
                        DivineVideoPlayerLog.shared.warning(
                            "Player \(self.playerId) uses the composition: "
                                + "clip needs rotation",
                            name: "DivineVideoPlayer.Load"
                        )
                    }
                }
                let built: BuiltItem
                if let direct {
                    built = direct
                } else {
                    built = try await self.makeCompositionPlayerItem(from: clipsRaw)
                }
                // dispose() can run while the above await is suspended; a
                // disposed instance must never resurrect a player/observers.
                // A newer setClips may have started too, and owns the player
                // from here.
                // Installing it now would loop this item under the newer mix,
                // or replace a queue the newer call already owns.
                guard !self.abandonsSetClips(callGeneration, built: built, result: result) else {
                    return
                }
                let playerItem = built.item
                let offsets = built.offsets
                let durations = built.durations
                self.loopAudioMix = playerItem.audioMix
                self.loopTimeRange = built.loopTimeRange
                self.firstFrameStart = built.firstFrameStart
                self.clipLoopSource = built.loopSource
                // The previous item keeps its download until this one takes
                // over the player.
                if self.remoteClipLoader !== built.streamedLoop?.loader {
                    self.remoteClipLoader?.cancel()
                }
                self.remoteClipLoader = built.streamedLoop?.loader
                self.clipOffsets = offsets
                self.clipDurations = durations
                self.clipCount = offsets.count
                self.totalDuration = offsets.last.map { $0 + (durations.last ?? 0) } ?? 0
                self.firstFrameRendered = false

                // Prevent pitch distortion when clips play at a speed other
                // than 1×. .timeDomain preserves pitch across the editor's
                // 0.25×–3× range at a fraction of .spectral's (phase vocoder)
                // CPU cost — the phase vocoder is a real-time hog that steals
                // cycles from video decode/render on weaker devices, showing up
                // as dropped or stuttering frames during sped-up preview.
                playerItem.audioTimePitchAlgorithm = .timeDomain
                self.templateItem = playerItem

                let requestedStartPositionMs = (args["startPositionMs"] as? NSNumber)?.int64Value
                let startPositionMs = requestedStartPositionMs ?? 0
                self.reportedPositionOverrideMs = requestedStartPositionMs
                // Many encoded videos in the feed have 1 black leading
                // frame at exactly time 0 — produced by the encoder
                // before the first real I-frame. Landing on that frame
                // is what causes the "black until play" bug for
                // preloaded items and the flash on loop restart.
                //
                // Diagnosed via composition.tracks segment.timeMapping
                // inspection (#3242): segment.target.start == 0 and
                // segment.source.start == 0, so this is encoder
                // pre-roll inside the source asset, NOT a Composition
                // gap. The fix is therefore a small forward seek when
                // no explicit start position was requested.
                //
                // 33ms ≈ 1 frame @ 30fps; videos in the feed are
                // ~29.9fps. `toleranceAfter` lets AVPlayer snap to the
                // next sync sample so we land on real content.
                //
                // Backend-side fix (proper solution): trim leading
                // black frames during transcoding. Tracked separately.
                //
                // A clip already cut to its first frame starts exactly there,
                // where every later lap starts too.
                let leadingBlackFrameSkip = CMTime(value: 1, timescale: 30)
                let startTime: CMTime
                if startPositionMs > 0 {
                    startTime = CMTime(value: startPositionMs, timescale: 1000)
                } else if let firstFrameStart = self.firstFrameStart {
                    startTime = firstFrameStart
                } else {
                    startTime = leadingBlackFrameSkip
                }

                if let existing = self.player {
                    self.configureQueue(with: playerItem)
                    await existing.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    guard !self.abandonsSetClips(callGeneration, result: result) else { return }
                    self.textureOutput?.forceRefresh(for: startTime)
                } else {
                    let newPlayer = AVQueuePlayer()
                    self.player = newPlayer
                    self.textureOutput?.attachPlayer(newPlayer)
                    self.addTimeObserver()
                    self.observeTimeControl()
                    self.observeCurrentItem()
                    self.configureQueue(with: playerItem)
                    await newPlayer.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    guard !self.abandonsSetClips(callGeneration, result: result) else { return }
                    self.textureOutput?.forceRefresh(for: startTime)
                }

                // Preroll so the texture has a real frame at startTime
                // even while paused. Deferred via safePreroll because
                // preroll throws before status reaches .readyToPlay.
                self.safePreroll(at: startTime)

                self.currentStatus = "ready"
                self.errorMessage = nil
                self.errorCode = nil
                self.clearSetClipsTimeout()
                self.startClipAudioLoop()
                // After the direct start: a download already complete answers
                // at once, and starting twice would decode twice.
                if let streamedLoop = built.streamedLoop {
                    self.decodeWhenDownloaded(streamedLoop)
                }
                DivineVideoPlayerLog.shared.info(
                    "Player \(self.playerId) ready: \(self.clipCount) clip(s), "
                        + "totalMs=\(Int(self.totalDuration * 1000))",
                    name: "DivineVideoPlayer.Load"
                )
                self.sendStateUpdate()
                result(nil)
            } catch {
                // A newer setClips already owns the player. Reporting this
                // load's failure would mark that video errored and clear its
                // timeout.
                guard !self.abandonsSetClips(callGeneration, result: result) else { return }
                self.currentStatus = "error"
                self.errorMessage = error.localizedDescription
                self.errorCode = self.errorCode(for: error as NSError)
                self.clearSetClipsTimeout()
                self.clearBufferingWatchdog(resetReported: true)
                let message =
                    "Player \(self.playerId) composition failed: "
                    + "\(error.localizedDescription)"
                if self.errorCode == "media_processing" {
                    DivineVideoPlayerLog.shared.warning(
                        message,
                        name: "DivineVideoPlayer.Load"
                    )
                } else {
                    DivineVideoPlayerLog.shared.error(
                        message,
                        name: "DivineVideoPlayer.Load"
                    )
                }
                self.sendStateUpdate()
                result(
                    FlutterError(
                        code: "COMPOSITION_ERROR",
                        message: error.localizedDescription,
                        details: self.errorCode.map { ["errorCode": $0] }
                    )
                )
            }
        }
    }

    /// Whether a clip may skip the composition once its asset is loaded.
    ///
    /// The composition rights a rotated track with a layer instruction.
    /// `AVPlayerItemVideoOutput` hands the pixel buffer over as decoded and
    /// applies no `preferredTransform`, and the Apple side — unlike Android —
    /// sends Dart no rotation to compensate with. HLS is exempt: its renditions
    /// are upright, and an HLS asset exposes no tracks to inspect anyway.
    private static func directItemSuitsRotation(
        _ asset: AVURLAsset,
        isHls: Bool
    ) async -> Bool {
        if isHls { return true }
        do {
            guard
                let track = try await asset.loadTracks(withMediaType: .video).first
            else { return false }
            let (naturalSize, transform) = try await track.load(
                .naturalSize, .preferredTransform
            )
            return transform.standardized(for: naturalSize).isEffectivelyIdentity
        } catch {
            // Unreadable is not upright; let the composition handle it.
            return false
        }
    }

    /// Whether [uri] may skip the composition and be played from the asset.
    ///
    /// A single unchanged clip has nothing to compose, and `AVPlayerLooper`
    /// only closes the seam over the asset itself — over a composition of the
    /// same file it does not. Remote URLs stay on the composition path, which
    /// owns the buffering and header handling for them: played straight from a
    /// remote asset, every copy the looper makes of the item stalled picture
    /// and sound at each restart on an iPad Air (M4), though it looped cleanly
    /// in the simulator.
    private static func takesDirectItemPath(_ uri: String) -> Bool {
        if URL(string: uri)?.pathExtension.lowercased() == "m3u8" { return true }
        return !uri.hasPrefix("http")
    }

    /// The single clip of [clipsRaw] the direct-item path can represent
    /// exactly, otherwise nil.
    ///
    /// Two sources qualify, for different reasons. An HLS `AVURLAsset` exposes
    /// **no** tracks — `loadTracks` returns an empty array — so a composition
    /// built from one always ends in
    /// [CompositionError.noPlayableVideoTracks] and can never play. A local
    /// file qualifies because there is nothing to compose: `AVPlayerLooper`
    /// closes the seam over the asset itself and does not over a composition
    /// of the same file.
    ///
    /// Rotation is decided later, against the loaded asset, in
    /// [directItemSuitsRotation] — it cannot be read from the URL.
    ///
    /// The diversion is deliberately narrow. A composition can start a clip
    /// part-way in and rescale it; an `AVPlayerItem` carries the whole asset
    /// from zero, so a non-zero `startMs` or an off-speed clip has no exact
    /// representation here and would report a timeline that does not match
    /// what plays. Those keep taking the composition path exactly as they do
    /// today rather than playing something subtly wrong. Multi-clip timelines
    /// likewise still need a composition to stitch.
    private static func soleDirectItemClip(
        in clipsRaw: [[String: Any]]
    ) -> [String: Any]? {
        guard clipsRaw.count == 1, let clip = clipsRaw.first,
            let uri = clip["uri"] as? String,
            Self.takesDirectItemPath(uri),
            (clip["startMs"] as? NSNumber)?.int64Value ?? 0 == 0,
            (clip["volume"] as? NSNumber)?.doubleValue ?? 1.0 == 1.0,
            (clip["playbackSpeed"] as? NSNumber)?.doubleValue ?? 1.0 == 1.0
        else { return nil }
        return clip
    }

    /// Builds a player item straight from the asset, bypassing the
    /// composition.
    ///
    /// This is the path every unchanged single clip takes, HLS and local file
    /// alike, because `AVPlayerLooper` only closes the loop seam over an asset
    /// and not over a composition of the same file.
    ///
    /// Trimming has no composition time range to live in, so it is applied
    /// twice over: as `forwardPlaybackEndTime`, which bounds playback, and —
    /// when the trim is what decides the loop — as the looper's own range,
    /// which is the only one honoured when it wraps. That range also starts
    /// each lap past the empty edits; see [lapStartPastEmptyEdits].
    ///
    /// `trimToCommonTrackEnd` cannot be honoured for an HLS asset: the common
    /// track end comes from `load(.timeRange)` on the asset's video and audio
    /// tracks, and an HLS asset has none to load, so the clip plays to the
    /// playlist's end, as it does on Android (#8897).
    ///
    /// A rotated clip cannot come here at all; [directItemSuitsRotation] sends
    /// it back to the composition, which rights it with a layer instruction.
    /// Per-clip volume changes likewise stay on the composition path; a direct
    /// item's audio mix only fades its two edges, like the composition's.
    ///
    /// Throws [CompositionError.directItemNotApplicable] when the loaded asset
    /// turns out to need the composition after all.
    private func makeDirectPlayerItem(
        from clipMap: [String: Any]
    ) async throws -> BuiltItem {
        guard let uri = clipMap["uri"] as? String else {
            throw CompositionError.noPlayableVideoTracks
        }
        // A bare file path is not a URL with a scheme, and URL(string:) turns
        // one into something AVURLAsset cannot load. The composition path
        // already draws this distinction; this one never needed to, because
        // until now it only ever saw HLS URLs.
        let url: URL
        if uri.hasPrefix("/") {
            url = URL(fileURLWithPath: uri)
        } else if let parsed = URL(string: uri) {
            url = parsed
        } else {
            throw CompositionError.noPlayableVideoTracks
        }
        let httpHeaders = clipMap["httpHeaders"] as? [String: String]
        let assetOptions: [String: Any]? = httpHeaders.map {
            [Self.avURLAssetHTTPHeaderFieldsKey: $0]
        }
        let asset = AVURLAsset(url: url, options: assetOptions)
        let isHls = url.pathExtension.lowercased() == "m3u8"
        guard await Self.directItemSuitsRotation(asset, isHls: isHls) else {
            throw CompositionError.directItemNotApplicable
        }
        let assetDuration = try await asset.load(.duration)

        // soleDirectItemClip guarantees startMs == 0, so the item's timeline is
        // [0, endTime] and the reported duration is endTime itself.
        let endTime = Self.clampedEndTime(
            requestedEndMs: clipMap["endMs"] as? NSNumber,
            assetDuration: assetDuration
        )
        guard endTime.isNumeric, endTime.seconds > 0 else {
            throw CompositionError.noPlayableVideoTracks
        }

        // The same cuts the composition makes: each lap starts at the first
        // frame and ends where the shorter of the two tracks runs out, not at
        // the end of the container. Here they cannot be cut into a time range
        // — the asset stays untouched — so the looper is given them as its
        // range instead.
        var loopStart = CMTime.zero
        var loopEnd = endTime
        let trimToCommonTrackEnd =
            (clipMap["trimToCommonTrackEnd"] as? NSNumber)?.boolValue ?? false
        if trimToCommonTrackEnd {
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            if let videoTrack = videoTracks.first {
                loopStart = await Self.lapStartPastEmptyEdits(
                    video: videoTrack,
                    audio: audioTracks.first
                )
            }
            if let videoTrack = videoTracks.first, let audioTrack = audioTracks.first {
                do {
                    let videoRange = try await videoTrack.load(.timeRange)
                    let audioRange = try await audioTrack.load(.timeRange)
                    if let commonEnd = boundedCommonTrackEnd(
                        startTime: .zero,
                        requestedEnd: endTime,
                        videoEnd: videoRange.end,
                        audioEnd: audioRange.end
                    ) {
                        loopEnd = CMTimeMinimum(loopEnd, commonEnd)
                    }
                } catch {
                    DivineVideoPlayerLog.shared.warning(
                        "Player \(playerId) could not read track durations: "
                            + "\(error.localizedDescription)",
                        name: "DivineVideoPlayer.Load"
                    )
                }
            }
        }

        let playerItem = AVPlayerItem(asset: asset)
        // The looper joins the last sample before loopEnd straight to the
        // first, and loopEnd is where the picture ends — usually a few
        // milliseconds into sound that carries on — so the join is a click on
        // every lap unless both edges fade. The mix addresses this asset's own
        // audio track, which every copy the looper makes shares; it replaces
        // whatever the last composition left, whose input parameters address
        // another asset's tracks. An HLS asset has no track to address.
        //
        // A processing tap that blended the material past loopEnd into each
        // lap's head was tried and measured under AVPlayerLooper: it held
        // playback ~360 ms at every start and ~420 ms at every join with a
        // tap per item. A volume mix leaves the looper's joins gapless.
        var audioTrack: AVAssetTrack?
        if !isHls {
            do {
                audioTrack = try await asset.loadTracks(withMediaType: .audio).first
            } catch {
                DivineVideoPlayerLog.shared.warning(
                    "Player \(playerId) could not load audio track for edge-declick "
                        + "mix: \(error.localizedDescription)",
                    name: "DivineVideoPlayer.Load"
                )
            }
        }
        guard CMTimeCompare(loopStart, loopEnd) < 0 else {
            throw CompositionError.noPlayableVideoTracks
        }
        let mix = audioTrack.flatMap {
            Self.edgeDeclickMix(track: $0, loopStart: loopStart, loopEnd: loopEnd)
        }
        // The shared mix is published only when this item is installed.
        // Writing it here would let a newer load stamp its fades onto the
        // item still looping, before that load replaces the queue.
        playerItem.audioMix = mix
        // forwardPlaybackEndTime and the looper describe the same boundary two
        // ways, and both are needed: the looper honours only its own range
        // when it wraps, while a player that is not looping — or stops looping
        // later — has only forwardPlaybackEndTime to end the item where Dart
        // was told it ends. loopEnd never exceeds endTime, so one comparison
        // covers both trims. The start lives in the looper's range alone: a
        // player that plays the clip once starts it wherever it is told to.
        if CMTimeCompare(loopEnd, assetDuration) < 0 {
            playerItem.forwardPlaybackEndTime = loopEnd
        }
        var built = BuiltItem(item: playerItem, offsets: [0], durations: [loopEnd.seconds])
        if CMTimeCompare(loopStart, .zero) > 0 || CMTimeCompare(loopEnd, assetDuration) < 0 {
            built.loopTimeRange = CMTimeRange(start: loopStart, end: loopEnd)
        }
        if CMTimeCompare(loopStart, .zero) > 0 { built.firstFrameStart = loopStart }
        if url.isFileURL {
            built.loopSource = ClipAudioLoop.Source(
                url: url,
                fileStart: loopStart,
                duration: CMTimeSubtract(loopEnd, loopStart),
                itemStart: loopStart
            )
        }
        return built
    }

    /// Builds a player item backed by an AVMutableComposition of every clip.
    private func makeCompositionPlayerItem(
        from clipsRaw: [[String: Any]]
    ) async throws -> BuiltItem {
        let build = try await buildComposition(from: clipsRaw)
        do {
            return try makeCompositionPlayerItem(from: build)
        } catch {
            build.loader?.cancel()
            throw error
        }
    }

    private func makeCompositionPlayerItem(from build: BuiltComposition) throws -> BuiltItem {
        let composition = build.composition
        let videoComposition = build.videoComposition
        let audioMix = build.audioMix
        let playerItem = AVPlayerItem(asset: composition)
        // Validate BEFORE assigning. -[AVPlayerItem setVideoComposition:]
        // throws an Objective-C NSInvalidArgumentException on an invalid
        // composition (zero render size or zero/invalid frame duration).
        // That exception is not a Swift Error, so the enclosing do/catch
        // can't catch it and the process aborts (SIGABRT). Rejecting the
        // bad values here surfaces the failure as a FlutterError instead.
        guard (videoComposition?.renderSize ?? composition.naturalSize).isPositive else {
            throw CompositionError.invalidRenderSize
        }
        if let videoComposition {
            let frameDuration = videoComposition.frameDuration
            guard frameDuration.isNumeric, frameDuration.seconds > 0 else {
                throw CompositionError.invalidFrameDuration
            }
            playerItem.videoComposition = videoComposition
        }
        if let audioMix { playerItem.audioMix = audioMix }
        var built = BuiltItem(item: playerItem, offsets: build.offsets, durations: build.durations)
        // A first clip cut past its empty edit shows a frame at zero.
        if CMTimeCompare(build.firstClipFileStart, .zero) > 0 { built.firstFrameStart = .zero }
        if let loader = build.loader {
            built.streamedLoop = StreamedLoop(
                loader: loader,
                fileStart: build.firstClipFileStart,
                duration: composition.duration
            )
        }
        return built
    }

    /// Hands the loop the file [streamedLoop]'s download is written to, once
    /// it is complete — at once if it already is.
    private func decodeWhenDownloaded(_ streamedLoop: StreamedLoop) {
        // Not the struct itself: it holds the loader, which holds this.
        let fileStart = streamedLoop.fileStart
        let duration = streamedLoop.duration
        streamedLoop.loader.onDownloaded = { [weak self, weak loader = streamedLoop.loader] fileURL in
            guard let self, let loader, loader === self.remoteClipLoader else { return }
            self.clipLoopSource = ClipAudioLoop.Source(
                url: fileURL,
                fileStart: fileStart,
                duration: duration,
                itemStart: .zero
            )
            if self.clipAudioLoop == nil { self.startClipAudioLoop() }
        }
    }

    /// Clamps a requested end time to the media that exists in the asset.
    ///
    /// `insertTimeRange` silently inserts only existing media, so an end past the
    /// source would otherwise leave reported duration longer than playback. The
    /// feed relies on this because it caps clips before knowing the source length.
    private static func clampedEndTime(
        requestedEndMs: NSNumber?,
        assetDuration: CMTime
    ) -> CMTime {
        guard let requestedEndMs else { return assetDuration }
        let requestedEnd = CMTime(value: requestedEndMs.int64Value, timescale: 1000)
        return (assetDuration.isNumeric && CMTimeCompare(requestedEnd, assetDuration) > 0)
            ? assetDuration
            : requestedEnd
    }

    /// A composition, and what the item built from it needs besides.
    private struct BuiltComposition {
        let composition: AVMutableComposition
        let videoComposition: AVVideoComposition?
        let offsets: [Double]
        let durations: [Double]
        let audioMix: AVMutableAudioMix?
        /// Where in its file the first clip starts.
        let firstClipFileStart: CMTime
        /// The download a single streamed looping clip loads through.
        let loader: CachingAssetLoader?
    }

    /// Builds an AVMutableComposition that stitches all clips into a
    /// single continuous timeline.
    private func buildComposition(
        from clipsRaw: [[String: Any]]
    ) async throws -> BuiltComposition {
        var loader: CachingAssetLoader?
        var built = false
        // A build that fails drops its download; one that succeeds hands it on.
        defer { if !built { loader?.cancel() } }
        let composition = AVMutableComposition()
        guard
            let videoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        else {
            throw CompositionError.cannotCreateTrack
        }
        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        var insertTime = CMTime.zero
        var offsets: [Double] = []
        var durations: [Double] = []
        // The same durations the composition is actually built from, kept as
        // CMTime. Seconds are lossy here: the audio mix's last ramp has to end
        // exactly where the composition ends, and a round trip through Double
        // moves that edge by up to one tick of the mix's timescale.
        var scaledDurations: [CMTime] = []
        var videoComposition: AVMutableVideoComposition?
        var layerInstruction: AVMutableVideoCompositionLayerInstruction?
        var clipVolumes: [Float] = []
        var firstClipFileStart = CMTime.zero

        for clipMap in clipsRaw {
            guard let uri = clipMap["uri"] as? String else {
                DivineVideoPlayerLog.shared.warning(
                    "\(logTarget) skipped a clip: missing uri",
                    name: "DivineVideoPlayer.Load"
                )
                continue
            }
            let startMs = (clipMap["startMs"] as? NSNumber)?.int64Value ?? 0
            let endMs = clipMap["endMs"] as? NSNumber
            let clipVol = (clipMap["volume"] as? NSNumber)?.floatValue ?? 1.0
            let clipSpeed = (clipMap["playbackSpeed"] as? NSNumber)?.doubleValue ?? 1.0
            let httpHeaders = clipMap["httpHeaders"] as? [String: String]
            let trimToCommonTrackEnd =
                (clipMap["trimToCommonTrackEnd"] as? NSNumber)?.boolValue ?? false

            let url: URL
            if uri.hasPrefix("/") {
                url = URL(fileURLWithPath: uri)
            } else if let parsed = URL(string: uri) {
                url = parsed
            } else {
                DivineVideoPlayerLog.shared.warning(
                    "\(logTarget) skipped a clip: unparseable uri",
                    name: "DivineVideoPlayer.Load"
                )
                continue
            }

            let assetOptions: [String: Any]? = httpHeaders.map {
                [Self.avURLAssetHTTPHeaderFieldsKey: $0]
            }
            let asset: AVURLAsset
            // A single streamed clip loads through a download the player
            // keeps, so its audio can be decoded into the loop without
            // fetching the file a second time. Only a clip the loop can stand
            // in for — whole, at full volume and normal speed, not HLS — and
            // only on a surface that loops a finished clip, which is what
            // trimToCommonTrackEnd declares. isLooping cannot tell: the feed
            // turns looping on only once the clip has loaded.
            if clipsRaw.count == 1, startMs == 0, clipVol == 1.0, clipSpeed == 1.0,
                trimToCommonTrackEnd,
                url.pathExtension.lowercased() != "m3u8",
                let clipLoader = CachingAssetLoader(remoteURL: url, headers: httpHeaders ?? [:])
            {
                loader = clipLoader
                asset = clipLoader.asset
            } else {
                asset = AVURLAsset(url: url, options: assetOptions)
            }

            // Load duration and tracks.
            let assetDuration = try await asset.load(.duration)
            let assetVideoTracks = try await asset.loadTracks(withMediaType: .video)
            let assetAudioTracks = try await asset.loadTracks(withMediaType: .audio)

            guard let sourceVideoTrack = assetVideoTracks.first else {
                DivineVideoPlayerLog.shared.warning(
                    "\(logTarget) skipped a clip: no video track",
                    name: "DivineVideoPlayer.Load"
                )
                continue
            }
            let (naturalSize, transform) = try await sourceVideoTrack.load(
                .naturalSize, .preferredTransform
            )
            let displaySize = naturalSize.applying(transform).absoluteSize
            guard displaySize.isPositive else {
                DivineVideoPlayerLog.shared.warning(
                    "\(logTarget) skipped a clip: non-positive display size",
                    name: "DivineVideoPlayer.Load"
                )
                continue
            }
            let standardizedTransform = transform.standardized(for: naturalSize)

            var startTime = CMTime(value: startMs, timescale: 1000)
            // A looping clip starts past the empty edits that open its
            // tracks. Only one that starts at zero, as on Android: an
            // explicit start is the caller's own cut.
            if trimToCommonTrackEnd, startMs == 0 {
                startTime = await Self.lapStartPastEmptyEdits(
                    video: sourceVideoTrack,
                    audio: assetAudioTracks.first
                )
            }
            var endTime = Self.clampedEndTime(
                requestedEndMs: endMs,
                assetDuration: assetDuration
            )
            // The asset duration is the *longest* track, so ending there leaves
            // a stretch where the shorter track has already run out — silence,
            // or a frozen frame. On a looping player that stretch is the seam.
            // Clamping may only ever shorten: an earlier explicit trim wins.
            if trimToCommonTrackEnd, let sourceAudioTrack = assetAudioTracks.first {
                do {
                    let videoRange = try await sourceVideoTrack.load(.timeRange)
                    let audioRange = try await sourceAudioTrack.load(.timeRange)
                    if let commonEnd = boundedCommonTrackEnd(
                        startTime: startTime,
                        requestedEnd: endTime,
                        videoEnd: videoRange.end,
                        audioEnd: audioRange.end
                    ) {
                        endTime = CMTimeMinimum(endTime, commonEnd)
                    }
                } catch {
                    DivineVideoPlayerLog.shared.warning(
                        "\(logTarget) could not read track durations: "
                            + "\(error.localizedDescription)",
                        name: "DivineVideoPlayer.Load"
                    )
                }
            }
            let timeRange = CMTimeRange(start: startTime, end: endTime)
            let clipDuration = CMTimeSubtract(endTime, startTime)
            guard CMTimeCompare(clipDuration, .zero) > 0 else {
                DivineVideoPlayerLog.shared.warning(
                    "\(logTarget) skipped a clip: non-positive duration",
                    name: "DivineVideoPlayer.Load"
                )
                continue
            }

            if offsets.isEmpty {
                composition.naturalSize = displaySize
                videoTrack.preferredTransform = transform
                if !standardizedTransform.isEffectivelyIdentity {
                    let instruction = AVMutableVideoCompositionLayerInstruction(
                        assetTrack: videoTrack
                    )
                    let mutableVideoComposition = AVMutableVideoComposition()
                    mutableVideoComposition.renderSize = displaySize
                    mutableVideoComposition.sourceTrackIDForFrameTiming = videoTrack.trackID
                    // iOS 16+ deprecates the synchronous minFrameDuration
                    // accessor — it returns an undefined value for an un-loaded
                    // track property — so load it asynchronously like the
                    // sibling track properties above. Even once loaded it can be
                    // valid-but-zero on assets without frame-timing metadata, and
                    // setVideoComposition rejects a zero/non-numeric frameDuration,
                    // so guard and fall back to 30fps.
                    let minFrameDuration = try await sourceVideoTrack.load(
                        .minFrameDuration
                    )
                    if minFrameDuration.isNumeric, minFrameDuration.seconds > 0 {
                        mutableVideoComposition.frameDuration = minFrameDuration
                    } else {
                        mutableVideoComposition.frameDuration = CMTime(value: 1, timescale: 30)
                    }
                    layerInstruction = instruction
                    videoComposition = mutableVideoComposition
                }
            }
            layerInstruction?.setTransform(standardizedTransform, at: insertTime)

            try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: insertTime)

            if let sourceAudioTrack = assetAudioTracks.first {
                try audioTrack?.insertTimeRange(timeRange, of: sourceAudioTrack, at: insertTime)
            }

            // Scale the just-inserted segment to achieve per-clip playback speed.
            // A speed of 2.0 halves the presentation duration; 0.5 doubles it.
            let scaledDuration: CMTime
            if clipSpeed != 1.0, clipSpeed > 0 {
                let scaledSeconds = CMTimeGetSeconds(clipDuration) / clipSpeed
                let candidate = CMTime(seconds: scaledSeconds, preferredTimescale: 600)
                // A pathological playbackSpeed can round the scaled duration to
                // zero or overflow it to a non-numeric CMTime. Like
                // setVideoComposition:, scaleTimeRange throws an uncatchable
                // Objective-C NSInvalidArgumentException on such a duration, so
                // fall back to the unscaled clip rather than abort the process.
                if candidate.isNumeric, candidate.seconds > 0 {
                    scaledDuration = candidate
                    let insertedRange = CMTimeRange(start: insertTime, duration: clipDuration)
                    composition.scaleTimeRange(insertedRange, toDuration: candidate)
                } else {
                    scaledDuration = clipDuration
                }
            } else {
                scaledDuration = clipDuration
            }

            if offsets.isEmpty { firstClipFileStart = startTime }
            offsets.append(CMTimeGetSeconds(insertTime))
            durations.append(CMTimeGetSeconds(scaledDuration))
            scaledDurations.append(scaledDuration)
            clipVolumes.append(clipVol)
            insertTime = CMTimeAdd(insertTime, scaledDuration)
        }

        guard !offsets.isEmpty else {
            throw CompositionError.noPlayableVideoTracks
        }
        if let videoComposition, let layerInstruction {
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: insertTime)
            instruction.layerInstructions = [layerInstruction]
            videoComposition.instructions = [instruction]
        }

        // Build an AVAudioMix that applies per-clip volume using time ranges on
        // the single composition audio track. AVQueuePlayer.volume multiplies on
        // top automatically, so 0.0 here = muted for that clip regardless of the
        // global volume.
        //
        // The video's two outer edges also fade, because AVPlayerLooper joins
        // them directly on every loop restart (#6468). Everything between keeps
        // its flat gain — only the join is audible, not the cuts inside it.
        //
        // The fade is folded into the gain it starts and ends at rather than
        // layered over it. Ramps may not overlap: AVFoundation rejects a ramp
        // that crosses an existing one with an Objective-C
        // NSInvalidArgumentException, which is not a Swift Error and would
        // abort the process. Folding also keeps a muted video silent.
        var audioMix: AVMutableAudioMix?
        if let audioTrack {
            let params = AVMutableAudioMixInputParameters(track: audioTrack)
            // Each edge is capped by the clip it sits in, and only by that
            // clip. Capping both by a single minimum would let one short clip
            // at either end shorten the fade at the *other* end too — and
            // below the ~25 ms floor described on [edgeDeclickFadeSeconds] a
            // ramp is stretched and never reaches zero, so the edge that did
            // not need shortening would silently stop declicking.
            //
            // [halfFadeTicks] rounds toward zero, so each cap can only ever
            // understate its clip — a fade that fits twice in the truncated
            // length fits twice in the real one. Each cap is half its own
            // clip, so on a single clip the two fades still cannot meet, and
            // on several they sit in different clips entirely.
            let maxFadeTicks =
                Int64((Self.edgeDeclickFadeSeconds * Double(Self.audioMixTimescale)).rounded())
            let fadeInTicks = min(maxFadeTicks, Self.halfFadeTicks(scaledDurations.first))
            let fadeOutTicks = min(maxFadeTicks, Self.halfFadeTicks(scaledDurations.last))
            let fadeIn = CMTime(value: fadeInTicks, timescale: Self.audioMixTimescale)
            let fadeOut = CMTime(value: fadeOutTicks, timescale: Self.audioMixTimescale)
            let lastIndex = scaledDurations.count - 1
            var t = CMTime.zero
            for (i, clipDuration) in scaledDurations.enumerated() {
                // Exactly the duration the composition was built from, so the
                // last clip's end is the composition's end and the fade out
                // reaches zero on the sample the loop actually joins.
                let clipEnd = CMTimeAdd(t, clipDuration)
                let vol = clipVolumes[i]
                var flatStart = t
                var flatEnd = clipEnd
                if i == 0, fadeInTicks > 0 {
                    flatStart = CMTimeAdd(t, fadeIn)
                    params.setVolumeRamp(
                        fromStartVolume: 0,
                        toEndVolume: vol,
                        timeRange: CMTimeRange(start: t, end: flatStart)
                    )
                }
                if i == lastIndex, fadeOutTicks > 0 {
                    flatEnd = CMTimeSubtract(clipEnd, fadeOut)
                }
                if CMTimeCompare(flatEnd, flatStart) > 0 {
                    params.setVolumeRamp(
                        fromStartVolume: vol,
                        toEndVolume: vol,
                        timeRange: CMTimeRange(start: flatStart, end: flatEnd)
                    )
                }
                if i == lastIndex, fadeOutTicks > 0,
                    CMTimeCompare(flatEnd, flatStart) >= 0
                {
                    params.setVolumeRamp(
                        fromStartVolume: vol,
                        toEndVolume: 0,
                        timeRange: CMTimeRange(start: flatEnd, end: clipEnd)
                    )
                }
                t = clipEnd
            }
            let mix = AVMutableAudioMix()
            mix.inputParameters = [params]
            audioMix = mix
        }

        built = true
        return BuiltComposition(
            composition: composition,
            videoComposition: videoComposition,
            offsets: offsets,
            durations: durations,
            audioMix: audioMix,
            firstClipFileStart: firstClipFileStart,
            loader: loader
        )
    }

    // MARK: - Seek

    private func handleSeekTo(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
            let positionMs = args["positionMs"] as? Int
        else {
            result(nil)
            return
        }
        let targetPositionMs = Int64(positionMs)
        reportedPositionOverrideMs = targetPositionMs
        let time = CMTime(value: targetPositionMs, timescale: 1000)
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            guard let self else {
                result(nil)
                return
            }
            self.textureOutput?.forceRefresh(for: time)
            self.syncAudioOverlays()
            // The loop's sound runs on its own clock; the seek only moved
            // the picture.
            self.realignClipAudioLoop(force: true)
            // Preroll primes the output pipeline at the new position;
            // without it a paused player near a clip boundary keeps
            // returning the pre-seek buffer until play() is pressed.
            self.safePreroll(at: time)
            result(nil)
        }
    }

    // MARK: - Volume / Speed / Looping

    private func handleSetVolume(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
            let vol = args["volume"] as? Double
        else {
            result(nil)
            return
        }
        volume = vol
        player?.volume = Float(vol)
        if clipAudioTakeover != nil { finishClipAudioTakeover() }
        clipAudioLoop?.volume = Float(vol)
        result(nil)
    }

    private func handleSetPlaybackSpeed(_ call: FlutterMethodCall, result: @escaping FlutterResult)
    {
        guard let args = call.arguments as? [String: Any],
            let spd = args["speed"] as? Double
        else {
            result(nil)
            return
        }
        speed = spd
        player?.rate = Float(spd)
        audioOverlayManager.setSpeed(spd)
        // The loop plays the recording at its own rate and has no stretcher
        // to follow a speed change with, so an off-speed player keeps its
        // own sound.
        if spd == 1.0 {
            if clipAudioLoop == nil { startClipAudioLoop() }
        } else {
            releaseClipAudioLoop()
        }
        result(nil)
    }

    private func handleSetLooping(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
            let loop = args["looping"] as? Bool
        else {
            result(nil)
            return
        }
        isLooping = loop
        rebuildQueueForLoopingChange()
        if loop {
            if clipAudioLoop == nil { startClipAudioLoop() }
        } else {
            releaseClipAudioLoop()
        }
        result(nil)
    }

    private func handleJumpToClip(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
            let index = args["index"] as? Int,
            index >= 0, index < clipOffsets.count
        else {
            result(nil)
            return
        }
        let targetPositionMs = Int64((clipOffsets[index] * 1000).rounded())
        reportedPositionOverrideMs = targetPositionMs
        let targetTime = CMTime(seconds: clipOffsets[index], preferredTimescale: 600)
        player?.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) {
            [weak self] _ in
            guard let self else {
                result(nil)
                return
            }
            self.textureOutput?.forceRefresh(for: targetTime)
            self.syncAudioOverlays()
            // Same stuck-frame guard as handleSeekTo: a paused player
            // landing on a clip boundary keeps returning the pre-seek
            // buffer until preroll primes the output pipeline.
            self.safePreroll(at: targetTime)
            result(nil)
        }
    }

    // MARK: - Stop

    private func handleStop(result: @escaping FlutterResult) {
        audioOverlayManager.pauseAndDeactivateAll()
        clearSetClipsTimeout()
        clearBufferingWatchdog(resetReported: true)
        // Pause and clear media so the surface goes blank.
        player?.pause()
        releaseClipAudioLoop()
        clipLoopSource = nil
        remoteClipLoader?.cancel()
        remoteClipLoader = nil
        playerLooper = nil
        templateItem = nil
        player?.removeAllItems()
        clipOffsets = []
        clipDurations = []
        clipCount = 0
        totalDuration = 0
        firstFrameRendered = false
        reportedPositionOverrideMs = nil
        currentStatus = "idle"
        errorMessage = nil  // clear stale error so sendStateUpdate never emits
                            // status="error" after media has been released.
        errorCode = nil
        sendStateUpdate()
        result(nil)
    }

    // MARK: - Audio overlay tracks

    private func handleSetAudioTracks(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
            let tracksRaw = args["tracks"] as? [[String: Any]]
        else {
            result(
                FlutterError(code: "INVALID_ARGS", message: "tracks list required", details: nil))
            return
        }
        audioOverlayManager.setTracks(from: tracksRaw)
        DivineVideoPlayerLog.shared.info(
            "\(logTarget) set \(tracksRaw.count) audio overlay track(s)",
            name: "DivineVideoPlayer.Audio"
        )
        syncAudioOverlays()
        result(nil)
    }

    private func handleRemoveAllAudioTracks(result: @escaping FlutterResult) {
        audioOverlayManager.disposeAll()
        result(nil)
    }

    private func handleSetAudioTrackVolume(
        _ call: FlutterMethodCall, result: @escaping FlutterResult
    ) {
        guard let args = call.arguments as? [String: Any],
            let index = args["index"] as? Int,
            let vol = args["volume"] as? Double
        else {
            result(nil)
            return
        }
        audioOverlayManager.setTrackVolume(at: index, volume: Float(vol))
        result(nil)
    }

    /// Syncs audio overlays to the current global video position.
    private func syncAudioOverlays() {
        guard let player else { return }
        audioOverlayManager.update(
            videoPositionSec: max(CMTimeGetSeconds(player.currentTime()), 0),
            isPlaying: player.rate > 0,
            speed: speed
        )
    }

    // MARK: - Observers

    private func addTimeObserver() {
        guard let player else { return }
        let interval = CMTime(seconds: 0.2, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] _ in
            self?.syncAudioOverlays()
            self?.sendStateUpdate()
        }
    }

    // MARK: - Loop audio

    /// Decodes the direct clip's audio into a loop that replaces the
    /// player's own sound, when there is one to decode and it can follow the
    /// player: a single looping local clip at normal speed.
    private func startClipAudioLoop() {
        releaseClipAudioLoop()
        let generation = clipAudioGeneration
        guard isLooping, speed == 1.0, clipCount == 1, let source = clipLoopSource else {
            return
        }
        // make is nonisolated, so the decode runs off the main actor.
        Task { @MainActor [weak self] in
            let loop = await ClipAudioLoop.make(source: source)
            guard let self, generation == self.clipAudioGeneration,
                !self.diagnosticDisposed, let loop
            else {
                loop?.release()
                return
            }
            self.adoptClipAudioLoop(loop)
        }
    }

    /// Hands the sound from the player to [loop].
    ///
    /// A player that is not playing switches at once. A playing one — a
    /// streamed clip whose download completes during its first lap — starts
    /// the loop silent and in step, and the two cross over once it is heard:
    /// two copies of the same sound a few milliseconds apart, so the crossing
    /// is not heard, and there is no seam mid-lap to be heard either.
    private func adoptClipAudioLoop(_ loop: ClipAudioLoop) {
        clipAudioLoop = loop
        loop.onStoppedByConfigurationChange = { [weak self, weak loop] in
            guard let self, let loop, loop === self.clipAudioLoop else { return }
            DivineVideoPlayerLog.shared.info(
                "Player \(self.playerId) loop audio stopped by an output change; placing it again",
                name: "DivineVideoPlayer.AudioLoop"
            )
            self.realignClipAudioLoop()
        }
        DivineVideoPlayerLog.shared.info(
            "Player \(playerId) loops its audio outside AVPlayer: \(loop.seamDescription)",
            name: "DivineVideoPlayer.AudioLoop"
        )
        if player?.timeControlStatus == .playing {
            loop.volume = 0
            realignClipAudioLoop()
            crossClipAudioOver(to: loop, step: 0)
        } else {
            loop.volume = Float(volume)
            player?.isMuted = true
            realignClipAudioLoop()
        }
        clipAudioSyncTicks = 0
        clipAudioSyncTimer?.invalidate()
        clipAudioSyncTimer = Timer.scheduledTimer(
            withTimeInterval: Self.clipAudioSyncInterval,
            repeats: true
        ) { [weak self] _ in
            DispatchQueue.main.async { self?.checkClipAudioLoop() }
        }
    }

    /// Starts the loop against the picture while the player plays, and stops
    /// it otherwise — keyed to the player's actual state, so its own pauses
    /// (a buffering stall, backgrounding) stop the sound as well.
    ///
    /// A loop already playing is left alone unless [force]d by a seek: the
    /// queue player reports `.playing` again every time `AVPlayerLooper`
    /// moves on to its next item, and placing the loop again there stopped
    /// the sound at every seam while the new item's clock was still stopped.
    private func realignClipAudioLoop(attempt: Int = 0, force: Bool = false) {
        clipAudioStartRetry?.cancel()
        clipAudioStartRetry = nil
        guard let loop = clipAudioLoop else { return }
        guard player?.timeControlStatus == .playing, let item = player?.currentItem else {
            if clipAudioTakeover != nil { finishClipAudioTakeover() }
            loop.pause()
            return
        }
        if force {
            loop.pause()
        } else if loop.isRunning {
            return
        }
        clipAudioDriftChecks = 0
        if loop.start(alignedTo: item) || attempt >= Self.clipAudioStartAttempts { return }
        // The player says it plays before its clock moves; try again once it
        // does.
        let retry = DispatchWorkItem { [weak self] in
            self?.realignClipAudioLoop(attempt: attempt + 1)
        }
        clipAudioStartRetry = retry
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.clipAudioStartRetryInterval,
            execute: retry
        )
    }

    /// Measures the loop against the picture and places it again when the
    /// two have separated.
    ///
    /// The usual cause is the picture holding at the seam: `AVPlayerLooper`
    /// starts its next item a little after the last one ends — ~10 ms on an
    /// iPad Air (M4) for some clips, ~200 ms for others, whatever the clip's
    /// sound does meanwhile — while the loop runs on without a gap. An output
    /// route change, or the host clock drifting from the audio hardware's,
    /// separates them too.
    private func checkClipAudioLoop() {
        guard let loop = clipAudioLoop, player?.timeControlStatus == .playing,
            let item = player?.currentItem
        else { return }
        guard let offset = loop.offset(from: item) else { return }
        let offsetMs = Int((offset * 1000).rounded())
        clipAudioSyncTicks += 1
        if clipAudioSyncTicks % Self.clipAudioSyncLogEvery == 1 {
            DivineVideoPlayerLog.shared.info(
                "Player \(playerId) loop audio \(offsetMs) ms from the picture",
                name: "DivineVideoPlayer.AudioLoop"
            )
        }
        guard abs(offset) > Self.clipAudioReplaceThreshold else {
            clipAudioDriftChecks = 0
            return
        }
        // One reading is not enough: a single late render time reads as
        // drift that is not there.
        clipAudioDriftChecks += 1
        guard clipAudioDriftChecks >= Self.clipAudioDriftChecksToReplace else { return }
        clipAudioDriftChecks = 0
        if loop.start(alignedTo: item) {
            DivineVideoPlayerLog.shared.info(
                "Player \(playerId) loop audio \(offsetMs) ms off the picture; placed it again",
                name: "DivineVideoPlayer.AudioLoop"
            )
        }
    }

    /// Moves the sound from the player to [loop] over
    /// [clipAudioTakeoverSteps], starting when the loop is first heard.
    private func crossClipAudioOver(to loop: ClipAudioLoop, step: Int) {
        guard loop === clipAudioLoop else { return }
        let nominal = Float(volume)
        let progress = Float(step) / Float(Self.clipAudioTakeoverSteps)
        loop.volume = nominal * progress
        player?.volume = nominal * (1 - progress)
        if step >= Self.clipAudioTakeoverSteps {
            finishClipAudioTakeover()
            return
        }
        let next = DispatchWorkItem { [weak self] in
            self?.crossClipAudioOver(to: loop, step: step + 1)
        }
        clipAudioTakeover = next
        let delay = step == 0 ? loop.startToHeardSeconds : Self.clipAudioTakeoverStepInterval
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: next)
    }

    /// Completes a takeover at once: the loop has the sound at full level
    /// and the player is muted. Also the way out when playback pauses or the
    /// volume changes mid-takeover, so the two never sound together.
    private func finishClipAudioTakeover() {
        clipAudioTakeover?.cancel()
        clipAudioTakeover = nil
        guard let loop = clipAudioLoop else { return }
        loop.volume = Float(volume)
        player?.isMuted = true
        player?.volume = Float(volume)
    }

    /// Gives the sound back to the player, and drops any decode still
    /// running.
    private func releaseClipAudioLoop() {
        clipAudioGeneration += 1
        clipAudioSyncTimer?.invalidate()
        clipAudioSyncTimer = nil
        clipAudioStartRetry?.cancel()
        clipAudioStartRetry = nil
        clipAudioTakeover?.cancel()
        clipAudioTakeover = nil
        guard let loop = clipAudioLoop else { return }
        loop.release()
        clipAudioLoop = nil
        player?.isMuted = false
        player?.volume = Float(volume)
    }

    private func observeTimeControl() {
        timeControlObservation?.invalidate()
        timeControlObservation = player?.observe(\.timeControlStatus, options: [.new]) {
            [weak self] _, _ in
            DispatchQueue.main.async { self?.realignClipAudioLoop() }
        }
    }

    private var clipAudioDriftChecks = 0
    private static let clipAudioSyncInterval: TimeInterval = 0.5
    private static let clipAudioSyncLogEvery = 20
    private static let clipAudioDriftChecksToReplace = 2
    private static let clipAudioReplaceThreshold = 0.030
    private static let clipAudioStartRetryInterval: TimeInterval = 0.01
    private static let clipAudioStartAttempts = 100
    private static let clipAudioTakeoverSteps = 6
    private static let clipAudioTakeoverStepInterval: TimeInterval = 0.01

    private func configureQueue(with item: AVPlayerItem) {
        guard let player else { return }
        playerLooper = nil
        player.removeAllItems()
        if isLooping {
            if let range = loopTimeRange {
                playerLooper = AVPlayerLooper(
                    player: player,
                    templateItem: item,
                    timeRange: range
                )
            } else {
                playerLooper = AVPlayerLooper(player: player, templateItem: item)
            }
        } else {
            player.insert(item, after: nil)
        }
        prewarmLoopingOutputs()
        attachCurrentItemOutputs()
    }

    private func rebuildQueueForLoopingChange() {
        guard let player, let item = templateItem else { return }
        // `currentTime()` answers an invalid time whenever the queue has no
        // current item — an item still loading, or a queue already drained by
        // an earlier rebuild. `AVPlayerItem` raises `NSInvalidArgumentException`
        // on a seek to one rather than ignoring it, so restarting from the
        // beginning is the only safe resume position.
        let playerTime = player.currentTime()
        let resumeTime = playerTime.isNumeric ? playerTime : .zero
        let shouldResume = player.rate > 0
        currentStatus = "ready"
        configureQueue(with: item)
        player.seek(to: resumeTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            guard let self else { return }
            self.textureOutput?.forceRefresh(for: resumeTime)
            self.syncAudioOverlays()
            if shouldResume {
                self.player?.play()
                self.player?.rate = Float(self.speed)
                self.audioOverlayManager.resumeActive(speed: self.speed)
            }
        }
    }

    /// Where a looping clip's laps start: past the empty edit that opens
    /// [video] or [audio], whichever ends later; zero when neither has one.
    ///
    /// Every Divine derivative opens its video track with a 21–23 ms empty
    /// edit, and some open the audio track with one of a few milliseconds.
    /// `AVPlayerLooper` does not join an item that starts with either to the
    /// next one gaplessly: each lap started ~200 ms late on an iPad Air (M4)
    /// and ~330–400 ms late on macOS and the simulator, the last frame held
    /// all that time, and a composition cut from zero held it ~55 ms. Started
    /// past both, every lap joined on time.
    private static func lapStartPastEmptyEdits(
        video: AVAssetTrack,
        audio: AVAssetTrack?
    ) async -> CMTime {
        let videoStart = await leadingEmptyEditEnd(of: video)
        guard let audio else { return videoStart }
        return CMTimeMaximum(videoStart, await leadingEmptyEditEnd(of: audio))
    }

    /// Where [track]'s media starts, when an empty edit of at most
    /// [maxLeadingEmptyEditSeconds] holds it back; zero otherwise.
    private static func leadingEmptyEditEnd(of track: AVAssetTrack) async -> CMTime {
        guard let segments = try? await track.load(.segments),
            let first = segments.first, first.isEmpty
        else { return .zero }
        let end = first.timeMapping.target.end
        guard end.isNumeric, end.seconds > 0, end.seconds <= maxLeadingEmptyEditSeconds else {
            return .zero
        }
        return end
    }

    private func boundedCommonTrackEnd(
        startTime: CMTime,
        requestedEnd: CMTime,
        videoEnd: CMTime,
        audioEnd: CMTime
    ) -> CMTime? {
        let containerEnd = CMTimeMaximum(videoEnd, audioEnd)
        let playbackEnd = CMTimeMinimum(requestedEnd, containerEnd)
        let commonEnd = CMTimeMinimum(videoEnd, audioEnd)
        guard commonEnd.isNumeric,
              playbackEnd.isNumeric,
              CMTimeCompare(commonEnd, startTime) > 0,
              CMTimeCompare(playbackEnd, commonEnd) > 0
        else {
            return nil
        }

        let trimMs = CMTimeSubtract(playbackEnd, commonEnd).seconds * 1000
        let playableDurationMs = CMTimeSubtract(playbackEnd, startTime).seconds * 1000
        guard trimMs.isFinite,
              playableDurationMs.isFinite,
              playableDurationMs > 0
        else {
            return nil
        }

        let trimLimitMs = min(
            Self.maxCommonTrackEndTrimMs,
            playableDurationMs * Self.maxCommonTrackEndTrimRatio
        )
        return trimMs <= trimLimitMs ? commonEnd : nil
    }

    /// Calls `AVPlayer.preroll(atRate:)` only when the player is ready;
    /// otherwise defers via a one-shot KVO on `status`. No-op while
    /// `player.rate != 0` (preroll is only useful when paused).
    ///
    /// Must be called on the main thread — `pendingPrerollObservation`
    /// is mutated here without synchronization. All current callers
    /// (setClips Task @MainActor, MethodChannel callbacks, seek
    /// completion handlers) are already main-queue.
    private func safePreroll(at time: CMTime) {
        assert(Thread.isMainThread, "safePreroll must be called on the main thread")
        guard let player = self.player else { return }
        guard player.rate == 0 else { return }
        if player.status == .readyToPlay {
            player.preroll(atRate: 1.0) { [weak self] prerolled in
                guard prerolled else { return }
                // `preroll(atRate:)` completion runs on an unspecified
                // internal queue. Hop to main before touching
                // `currentItem` / `step(byCount:)` / `textureOutput`.
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.nudgeOutputQueue()
                    self.textureOutput?.forceRefresh(for: time)
                    // `step(byCount:)` enqueues into the player's
                    // internal pipeline and the resulting frame is not
                    // available on `copyPixelBuffer` until the next
                    // runloop iteration. Defer the synchronous pull
                    // attempt one tick so it has a chance to succeed —
                    // and only flip `firstFrameRendered` (via
                    // `deliverFrame`→`onFirstFrame`) when a real
                    // `CVPixelBuffer` is actually in the texture.
                    // Otherwise Flutter would hide the loader over an
                    // empty texture and render one frame of black
                    // before the display-link path catches up.
                    DispatchQueue.main.async { [weak self] in
                        self?.textureOutput?.tryPullFrameNow(at: time)
                    }
                }
            }
            return
        }
        pendingPrerollObservation?.invalidate()
        pendingPrerollObservation = player.observe(
            \.status,
            options: [.new]
        ) { [weak self] obsPlayer, _ in
            guard obsPlayer.status == .readyToPlay else { return }
            // KVO callbacks fire on whichever queue mutated the
            // observed key. `pendingPrerollObservation` mutation and
            // the inner preroll must happen on main.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.pendingPrerollObservation?.invalidate()
                self.pendingPrerollObservation = nil
                guard obsPlayer.rate == 0 else { return }
                obsPlayer.preroll(atRate: 1.0) { [weak self] prerolled in
                    guard prerolled else { return }
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        self.nudgeOutputQueue()
                        self.textureOutput?.forceRefresh(for: time)
                        // See sibling branch above: defer the pull one
                        // runloop tick so `step(byCount:)` has produced
                        // a frame, and only mark the controller as
                        // ready when a real `CVPixelBuffer` lands in
                        // the Flutter texture.
                        DispatchQueue.main.async { [weak self] in
                            self?.textureOutput?.tryPullFrameNow(at: time)
                        }
                    }
                }
            }
        }
    }

    /// Forces `AVPlayerItemVideoOutput` to populate its frame queue while
    /// the player is paused.
    ///
    /// `preroll(atRate:)` warms the decoder buffer but does not push a
    /// frame into the video-output queue — that queue only fills when the
    /// player's timebase advances. On a paused player at rate=0, the
    /// timebase never advances, so `copyPixelBuffer(forItemTime:)` keeps
    /// returning `nil` and the Flutter `Texture` stays black until
    /// `play()` is called.
    ///
    /// `step(byCount: 1)` followed by `step(byCount: -1)` advances the
    /// timebase by one frame and back, netting to the same position but
    /// causing the output to enqueue a frame in the process — the only
    /// reliable way to produce the first paused frame on iOS.
    private func nudgeOutputQueue() {
        guard let item = player?.currentItem, item.canStepForward else { return }
        item.step(byCount: 1)
        if item.canStepBackward {
            item.step(byCount: -1)
        }
    }

    private func observeCurrentItem() {
        currentItemObservation = player?.observe(
            \.currentItem,
            options: [.new]
        ) { [weak self] _, _ in
            self?.attachCurrentItemOutputs()
        }
        attachCurrentItemOutputs()
    }

    /// Hands the looper's queued items to the texture output so each one
    /// carries a video output before it becomes current.
    ///
    /// `AVPlayerLooper` builds its copies asynchronously, so the set can still
    /// be empty right after the looper is created and fills in later; running
    /// this again on every current-item change picks up whatever it has by
    /// then. It is idempotent — an item already warmed is skipped.
    ///
    /// With no looper the set is empty on purpose: that is what drops the
    /// previous looper's items, outputs and decoders when looping is switched
    /// off, instead of holding them until dispose.
    private func prewarmLoopingOutputs() {
        textureOutput?.prewarm(items: playerLooper?.loopingPlayerItems ?? [])
        // The looper prerolls the next lap's audio ahead of the join, so an
        // edge fade handed over only when an item becomes current misses the
        // very samples it exists for.
        if let loopAudioMix {
            playerLooper?.loopingPlayerItems.forEach { item in
                if item.audioMix !== loopAudioMix { item.audioMix = loopAudioMix }
            }
        }
    }

    private func attachCurrentItemOutputs() {
        guard let item = player?.currentItem else { return }
        prewarmLoopingOutputs()
        if let loopAudioMix, item.audioMix !== loopAudioMix {
            item.audioMix = loopAudioMix
        }
        textureOutput?.attach(to: item)
        observeStatus(for: item)
        observeBuffering(for: item)
        observeEnd(for: item)
    }

    private func observeStatus(for item: AVPlayerItem) {
        statusObservation?.invalidate()
        statusObservation = item.observe(
            \.status,
            options: [.new]
        ) { [weak self] item, _ in
            DispatchQueue.main.async { [weak self] in
                guard let self, item === self.player?.currentItem else { return }
                switch item.status {
                case .readyToPlay:
                    self.clearSetClipsTimeout()
                    self.currentStatus = "ready"
                    self.errorMessage = nil
                    self.errorCode = nil
                    self.updateVideoSize(from: item)
                case .failed:
                    self.clearSetClipsTimeout()
                    self.clearBufferingWatchdog(resetReported: true)
                    self.currentStatus = "error"
                    self.errorMessage = item.error?.localizedDescription
                    if let itemError = item.error as NSError? {
                        self.errorCode = self.errorCode(for: itemError)
                    } else {
                        self.errorCode = nil
                    }
                    let message =
                        "Player \(self.playerId) item failed: "
                        + "\(item.error?.localizedDescription ?? "unknown")"
                    if self.errorCode == "media_processing" {
                        DivineVideoPlayerLog.shared.warning(
                            message,
                            name: "DivineVideoPlayer.Playback"
                        )
                    } else {
                        DivineVideoPlayerLog.shared.error(
                            message,
                            name: "DivineVideoPlayer.Playback"
                        )
                    }
                default:
                    break
                }
                self.sendStateUpdate()
            }
        }
    }

    private func observeBuffering(for item: AVPlayerItem) {
        bufferingObservation?.invalidate()
        likelyToKeepUpObservation?.invalidate()
        bufferingObservation = nil
        likelyToKeepUpObservation = nil
        clearBufferingWatchdog(resetReported: true)

        bufferingObservation = item.observe(
            \.isPlaybackBufferEmpty,
            options: [.initial, .new]
        ) { [weak self] observedItem, _ in
            DispatchQueue.main.async { [weak self] in
                guard let self, observedItem === self.player?.currentItem else { return }
                if observedItem.isPlaybackBufferEmpty && observedItem.status != .failed {
                    self.armBufferingWatchdog()
                } else {
                    self.clearBufferingWatchdog(resetReported: true)
                }
                self.sendStateUpdate()
            }
        }

        likelyToKeepUpObservation = item.observe(
            \.isPlaybackLikelyToKeepUp,
            options: [.new]
        ) { [weak self] observedItem, _ in
            DispatchQueue.main.async { [weak self] in
                guard let self, observedItem === self.player?.currentItem else { return }
                if observedItem.isPlaybackLikelyToKeepUp {
                    self.clearBufferingWatchdog(resetReported: true)
                }
                self.sendStateUpdate()
            }
        }
    }

    private func armSetClipsTimeout() {
        clearSetClipsTimeout()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            DivineVideoPlayerLog.shared.warning(
                "Player \(self.playerId) load froze: never reached ready within "
                    + "\(Self.setClipsTimeoutMs)ms",
                name: "DivineVideoPlayer.Freeze"
            )
            self.setClipsTimeoutWorkItem = nil
        }
        setClipsTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + .milliseconds(Self.setClipsTimeoutMs),
            execute: workItem
        )
    }

    private func clearSetClipsTimeout() {
        setClipsTimeoutWorkItem?.cancel()
        setClipsTimeoutWorkItem = nil
    }

    private func armBufferingWatchdog() {
        guard !bufferingStallReported, bufferingWatchdogWorkItem == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.bufferingStallReported = true
            self.bufferingWatchdogWorkItem = nil
            DivineVideoPlayerLog.shared.warning(
                "Player \(self.playerId) appears frozen: still buffering after "
                    + "\(Self.bufferingStallMs)ms",
                name: "DivineVideoPlayer.Freeze"
            )
        }
        bufferingWatchdogWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + .milliseconds(Self.bufferingStallMs),
            execute: workItem
        )
    }

    private func clearBufferingWatchdog(resetReported: Bool) {
        bufferingWatchdogWorkItem?.cancel()
        bufferingWatchdogWorkItem = nil
        if resetReported {
            bufferingStallReported = false
        }
    }

    private func observeEnd(for item: AVPlayerItem) {
        NotificationCenter.default.removeObserver(
            self,
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
    }

    @objc private func playerDidFinish() {
        guard !isLooping else { return }
        audioOverlayManager.pauseAndDeactivateAll()
        currentStatus = "completed"
        sendStateUpdate()
    }

    // MARK: - State broadcasting

    private func sendStateUpdate() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.sendStateUpdate()
            }
            return
        }
        sendStateUpdateOnMain()
    }

    private func sendStateUpdateOnMain() {
        guard !isBackgrounded, let player, let sink = eventSink else { return }

        let currentTime = CMTimeGetSeconds(player.currentTime())
        let actualPositionMs = currentTime.millisecondsClamped
        let positionMs: Int
        if let overrideMs = reportedPositionOverrideMs {
            if player.rate > 0 && Int64(actualPositionMs) >= overrideMs {
                reportedPositionOverrideMs = nil
                positionMs = actualPositionMs
            } else {
                positionMs = Int(max(overrideMs, 0))
            }
        } else {
            positionMs = actualPositionMs
        }
        let reportedTime = Double(positionMs) / 1000.0
        let durationMs = totalDuration.millisecondsClamped

        // Determine current clip index.
        var clipIndex = 0
        for i in 0..<clipOffsets.count {
            let clipEnd = clipOffsets[i] + clipDurations[i]
            if reportedTime < clipEnd + 0.01 {
                clipIndex = i
                break
            }
            clipIndex = i
        }

        let status: String
        if currentStatus == "error" || currentStatus == "completed" {
            status = currentStatus
        } else if player.rate > 0 {
            status = "playing"
        } else if player.currentItem?.isPlaybackBufferEmpty == true {
            status = "buffering"
        } else if currentStatus == "ready" && player.rate == 0 {
            status = "paused"
        } else {
            status = currentStatus
        }

        var map: [String: Any] = [
            "status": status,
            "positionMs": positionMs,
            "durationMs": durationMs,
            "bufferedPositionMs": bufferedPositionMs(for: player),
            "currentClipIndex": clipIndex,
            "clipCount": clipCount,
            "isLooping": isLooping,
            "volume": volume,
            "playbackSpeed": speed,
            "isFirstFrameRendered": firstFrameRendered,
            "videoWidth": videoWidth,
            "videoHeight": videoHeight,
        ]
        if let errorMessage {
            map["errorMessage"] = errorMessage
        }
        if let errorCode = resolvedErrorCode() {
            map["errorCode"] = errorCode
        }
        sink(map)
    }

    /// Maps the current player error to a canonical error code string that
    /// matches the values defined in `NativePlayerErrorCode` on the Dart side.
    private func resolvedErrorCode() -> String? {
        let nsError: NSError?
        if let itemError = player?.currentItem?.error as NSError? {
            nsError = itemError
        } else if currentStatus == "error" {
            nsError = nil
        } else {
            return nil
        }

        guard let err = nsError else {
            return currentStatus == "error" ? (errorCode ?? "unknown") : nil
        }

        return errorCode(for: err)
    }

    private func errorCode(for err: NSError) -> String {
        // HTTP errors carried inside AVFoundation errors.
        if let httpResponse = err.userInfo["NSURLErrorFailingURLResponseErrorKey"] as? HTTPURLResponse {
            if httpResponse.statusCode == 202 {
                return "media_processing"
            }
            if httpResponse.statusCode == 401 {
                return "auth_required"
            }
            if httpResponse.statusCode == 403 {
                return "forbidden"
            }
            if httpResponse.statusCode == 404 {
                return "not_found"
            }
            return httpResponse.statusCode >= 500 ? "http_server_error" : "http_client_error"
        }

        if err.localizedDescription.contains("HTTP 202") {
            return "media_processing"
        }

        switch (err.domain, err.code) {
        case (NSURLErrorDomain, NSURLErrorNotConnectedToInternet),
             (NSURLErrorDomain, NSURLErrorNetworkConnectionLost),
             (NSURLErrorDomain, NSURLErrorDataNotAllowed):
            return "network_error"
        case (NSURLErrorDomain, NSURLErrorTimedOut):
            return "timeout"
        case (NSURLErrorDomain, NSURLErrorUserAuthenticationRequired):
            return "auth_required"
        default:
            // AVFoundation format / decoder errors.
            if err.domain == AVFoundationErrorDomain {
                let code = AVError.Code(rawValue: err.code)
                switch code {
                case .decodeFailed, .noCompatibleAlternatesForExternalDisplay:
                    return "decoder_error"
                case .fileFormatNotRecognized, .contentIsNotAuthorized:
                    return "parse_error"
                default:
                    break
                }
            }
            return "unknown"
        }
    }

    // MARK: - FlutterStreamHandler

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
        -> FlutterError?
    {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    // MARK: - Accessors for view factory

    func getPlayer() -> AVPlayer? { player }

    /// Marks the controller as having produced its first renderable
    /// frame. Called by the platform view path when
    /// `AVPlayerLayer.isReadyForDisplay` flips to `true`, and by the
    /// texture path's `VideoTextureOutput.onFirstFrame` callback when
    /// a real `CVPixelBuffer` has actually been delivered to the
    /// Flutter texture (either via `tryPullFrameNow` from
    /// `safePreroll` for prefetched items, or via the
    /// frame-driver poll once playback begins). Flipping this flag
    /// hides the loader overlay in Flutter, so it must only happen
    /// after the texture has a buffer — otherwise the texture renders
    /// one frame of black before the next display-link tick.
    func setFirstFrameRendered() {
        guard !firstFrameRendered else { return }
        firstFrameRendered = true
        sendStateUpdate()
    }

    // MARK: - Video size

    private func updateVideoSize(from item: AVPlayerItem) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let size = item.presentationSize
            guard size.isPositive else { return }
            self.videoWidth = Int(abs(size.width))
            self.videoHeight = Int(abs(size.height))
            self.sendStateUpdate()
        }
    }

    // MARK: - Buffered position

    private func bufferedPositionMs(for player: AVPlayer) -> Int {
        guard let item = player.currentItem,
            let range = item.loadedTimeRanges.first?.timeRangeValue
        else {
            return 0
        }
        let bufferedEnd = CMTimeGetSeconds(
            CMTimeAdd(range.start, range.duration)
        )
        return bufferedEnd.millisecondsClamped
    }

    // MARK: - App Lifecycle

    /// Whether the player was playing before the app went to background.
    private var wasPlayingBeforePause = false

    /// Suspends `EventChannel` sends while the app is backgrounded. A periodic
    /// time-observer tick (or a KVO / end-of-item callback) firing during the
    /// resign-active → suspend window would otherwise reach `sink(...)` after
    /// the Flutter shell is torn down, throwing
    /// `NSInternalInconsistencyException: Sending a message before the
    /// FlutterEngine has been run.` This is the EventChannel analog of
    /// `VideoTextureOutput.suspendFrameDelivery()`.
    private var isBackgrounded = false

    func onAppBackgrounded() {
        // Stop the texture frame driver first: nothing renders while the
        // app is inactive, so every frame pushed now is wasted work.
        // Unconditional: the driver polls even while the player is paused,
        // and a paused-player seek/forceRefresh can still push a frame.
        // This gate does not protect the engine's shell — a player created
        // after this point starts with delivery enabled — so the plugin
        // disposes the engine's players before the shell is destroyed
        // (#9342).
        textureOutput?.suspendFrameDelivery()
        wasPlayingBeforePause = player?.rate ?? 0 > 0
        if wasPlayingBeforePause {
            player?.pause()
            audioOverlayManager.pauseAndDeactivateAll()
            // Runs synchronously on the resign-active callback while the shell
            // is still alive, so the final paused state reaches Dart before the
            // gate below closes.
            sendStateUpdate()
        }
        isBackgrounded = true
    }

    func onAppForegrounded() {
        isBackgrounded = false
        textureOutput?.resumeFrameDelivery()
        if wasPlayingBeforePause {
            player?.play()
            player?.rate = Float(speed)
            audioOverlayManager.resumeActive(speed: speed)
            wasPlayingBeforePause = false
        }
        // Resync unconditionally: a status change suppressed by the gate
        // while backgrounded (e.g. a paused item that failed on a dropped
        // connection) would otherwise leave Dart on stale state until the
        // next interaction.
        sendStateUpdate()
    }

    // MARK: - Dispose

    /// Releases the player. With `engineTearingDown` the owning engine's
    /// shell is being destroyed (or already is), so nothing here may call
    /// into it: the texture stays registered — the shell drops the registry
    /// with itself — and the channel handlers are cleared through the
    /// messenger's own shell-guarded paths.
    func dispose(engineTearingDown: Bool = false) {
        diagnosticDisposed = true
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        statusObservation?.invalidate()
        statusObservation = nil
        bufferingObservation?.invalidate()
        bufferingObservation = nil
        likelyToKeepUpObservation?.invalidate()
        likelyToKeepUpObservation = nil
        currentItemObservation?.invalidate()
        currentItemObservation = nil
        pendingPrerollObservation?.invalidate()
        pendingPrerollObservation = nil
        timeControlObservation?.invalidate()
        timeControlObservation = nil
        releaseClipAudioLoop()
        remoteClipLoader?.cancel()
        remoteClipLoader = nil
        clearSetClipsTimeout()
        clearBufferingWatchdog(resetReported: true)
        NotificationCenter.default.removeObserver(self)
        textureOutput?.dispose(unregisterTexture: !engineTearingDown)
        textureOutput = nil
        playerLooper = nil
        player?.pause()
        player?.removeAllItems()
        player = nil
        audioOverlayManager.disposeAll()
        eventSink = nil
        methodChannel.setMethodCallHandler(nil)
        eventChannel.setStreamHandler(nil)
    }
}

// MARK: - Error type

private enum CompositionError: Error, LocalizedError {
    case cannotCreateTrack
    case noPlayableVideoTracks
    case invalidRenderSize
    case invalidFrameDuration
    case directItemNotApplicable

    var errorDescription: String? {
        switch self {
        case .cannotCreateTrack:
            return "Failed to create composition track."
        case .noPlayableVideoTracks:
            return "No playable video tracks found."
        case .invalidRenderSize:
            return "Video composition has an invalid render size."
        case .invalidFrameDuration:
            return "Video composition has an invalid frame duration."
        case .directItemNotApplicable:
            return "Clip needs the composition path."
        }
    }
}

private extension Double {
    /// Millisecond conversion safe against NaN and ±infinity, which
    /// `Int.init(_: Double)` traps on. AVFoundation time queries can
    /// return non-numeric values — e.g. `loadedTimeRanges` yields an
    /// indefinite CMTime at the readyToPlay transition on macOS 26,
    /// and `max(NaN, 0)` returns NaN rather than 0.
    var millisecondsClamped: Int {
        guard isFinite else { return 0 }
        return Int(max(self, 0) * 1000)
    }
}

private extension CGSize {
    var absoluteSize: CGSize {
        CGSize(width: abs(width), height: abs(height))
    }

    var isPositive: Bool {
        width.isFinite && height.isFinite && width > 0 && height > 0
    }
}

private extension CGAffineTransform {
    var isEffectivelyIdentity: Bool {
        abs(a - 1) < 0.001
            && abs(b) < 0.001
            && abs(c) < 0.001
            && abs(d - 1) < 0.001
            && abs(tx) < 0.001
            && abs(ty) < 0.001
    }

    func standardized(for size: CGSize) -> CGAffineTransform {
        var transform = self
        if close(a, 1) && close(b, 0) && close(c, 0) && close(d, 1) {
            transform.tx = 0
            transform.ty = 0
        } else if close(a, -1) && close(b, 0) && close(c, 0) && close(d, -1) {
            transform.tx = size.width
            transform.ty = size.height
        } else if close(a, 0) && close(b, -1) && close(c, 1) && close(d, 0) {
            transform.tx = 0
            transform.ty = size.width
        } else if close(a, 0) && close(b, 1) && close(c, -1) && close(d, 0) {
            transform.tx = size.height
            transform.ty = 0
        } else if close(a, -1) && close(b, 0) && close(c, 0) && close(d, 1) {
            transform.tx = size.width
            transform.ty = 0
        } else if close(a, 1) && close(b, 0) && close(c, 0) && close(d, -1) {
            transform.tx = 0
            transform.ty = size.height
        } else if close(a, 0) && close(b, -1) && close(c, -1) && close(d, 0) {
            transform.tx = size.height
            transform.ty = size.width
        } else if close(a, 0) && close(b, 1) && close(c, 1) && close(d, 0) {
            transform.tx = 0
            transform.ty = 0
        }
        return transform
    }

    private func close(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool {
        abs(lhs - rhs) < 0.001
    }
}
