// ABOUTME: AVFoundation-based camera controller for iOS
// ABOUTME: Handles camera initialization, preview, recording, and controls

import AVFoundation
import Flutter
import UIKit

/// Controller for AVFoundation-based camera operations.
/// Handles camera initialization, preview, video recording, and camera controls.
class CameraController: NSObject {
    private var captureSession: AVCaptureSession?
    /// Separate AVCaptureSession used solely for audio capture during recording.
    /// flutter's camera_avfoundation plugin uses this two-session pattern to
    /// avoid reconfiguring the running video session when audio is added,
    /// which would otherwise cause a black-frame stall and a Main-thread
    /// freeze (~200-500ms) on the first record tap.
    private var audioCaptureSession: AVCaptureSession?
    private var videoDevice: AVCaptureDevice?
    private var audioDevice: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var audioOutput: AVCaptureAudioDataOutput?

    /// Optional second, preview-sized video data output dedicated to the live
    /// preview texture. Runs `.previewOptimized` stabilization (iOS 17+) so the
    /// preview stays smooth and does not jump/jerk when recording starts, while
    /// `videoOutput` keeps the user-selected overscan mode for the recorded
    /// file. Nil when the dual-output path is unavailable (older iOS,
    /// unsupported device, or the session rejects a second video data output);
    /// the controller then drives the texture from `videoOutput` as before.
    private var previewOutput: AVCaptureVideoDataOutput?

    /// Still-photo output for single-frame capture (stop-motion). Added at
    /// session setup alongside the video data output; AVCapturePhotoOutput
    /// coexists with AVCaptureVideoDataOutput (unlike AVCaptureMovieFileOutput).
    private var photoOutput: AVCapturePhotoOutput?
    /// Retains in-flight photo capture delegates until their completion fires —
    /// AVCapturePhotoOutput does not retain its delegate.
    private var activePhotoDelegates: [PhotoCaptureDelegate] = []

    // AVAssetWriter for video recording (replaces AVCaptureMovieFileOutput)
    private var assetWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    /// When true the shared AVAudioSession is configured with
    /// `.measurement`, the mode Apple documents as minimising system-supplied
    /// signal processing on the input signal. The default `.videoRecording`
    /// mode runs speech-tuned noise suppression that gates instruments away
    /// (#7796). Set once per session from `initialize(preferUnprocessedAudio:)`.
    private var prefersUnprocessedAudio = false

    /// The AVAudioSession mode this controller wants for capture.
    private var desiredAudioSessionMode: AVAudioSession.Mode {
        prefersUnprocessedAudio ? .measurement : .videoRecording
    }

    /// Set by the AVAudioSession interruption observer. While true the
    /// audio capture path is known to be silent and we skip appending
    /// audio buffers to the asset writer.
    ///
    /// Synchronized via `audioInterruptedLock` because writes happen on
    /// `sessionQueue` (interruption handler) but reads happen on
    /// `videoOutputQueue` (`captureOutput`) — without a lock those
    /// cross-queue accesses are an unsynchronized data race on a plain
    /// `Bool`.
    private let audioInterruptedLock = NSLock()
    private var _audioInterrupted: Bool = false
    private var audioInterrupted: Bool {
        get {
            audioInterruptedLock.lock()
            defer { audioInterruptedLock.unlock() }
            return _audioInterrupted
        }
        set {
            audioInterruptedLock.lock()
            _audioInterrupted = newValue
            audioInterruptedLock.unlock()
        }
    }

    /// Diagnostics for the finished-clip audio log (#4779 family): how many
    /// audio buffers reached the writer and the loudest peak seen during
    /// the recording (dBFS, 0 = full scale). A populated track whose peak
    /// stayed near -160 is the silent-AAC signature. Written on
    /// `videoOutputQueue`, read once after the writer finished — same loose
    /// cross-queue convention as `lastVideoFrameEndPTS`.
    private var appendedAudioBufferCount = 0
    private var maxAudioPeakDb: Float = -160

    /// Audio-alignment diagnostics (#7888). "Recording starts, but the first
    /// couple of seconds have no sound" is not reproducible in-house — five
    /// captures on an M4 iPad all put the audio track at 0ms — so the finished
    /// clip has to carry its own evidence, or every such report costs another
    /// blind investigation.
    ///
    /// Nothing in the capture path couples the two tracks: the writer session
    /// is anchored on the first video frame, while audio comes from a separate
    /// AVCaptureSession whose first buffer can land either side of that anchor
    /// (measured -66ms to +35ms). A device whose mic takes longer to deliver
    /// pushes that gap into audible territory, and only the numbers below can
    /// tell that apart from the alternatives — a slow attach on the record
    /// tap, or a mic that delivered nothing at all.
    ///
    /// Both audio PTS fields hold the timestamp *after*
    /// `retimedToVideoClock(_:)`, so they are comparable with the anchor. The
    /// raw audio-clock reading is preserved separately in `audioClockOffset`.
    ///
    /// Written on `videoOutputQueue`, read once after the writer finished —
    /// same loose cross-queue convention as `lastVideoFrameEndPTS`.
    private var writerAnchorPTS: CMTime?
    private var firstAppendedAudioPTS: CMTime?
    /// How far the audio capture session's clock sat from the video capture
    /// session's clock when this recording's first audio buffer was retimed
    /// (`converted - raw`). The two sessions stamp their buffers on different
    /// clocks, and a field log from an iPhone on iOS 26.6 measured the audio
    /// clock 0.9–1.8s *behind* the video clock. Appended unconverted, that
    /// offset makes the writer edit out the first 0.9–1.8s of sound, play the
    /// rest that far ahead of the picture, and leave the tail silent (#7888).
    private var audioClockOffset: CMTime?
    /// PTS of the first audio buffer the delegate saw for this recording,
    /// recorded before every gate that can drop it — the writer session not
    /// being open yet, an interruption in progress, or no audio writer input
    /// at all. Inside those gates a clip whose mic never delivered and a clip
    /// whose buffers were all discarded report the same nothing, which is the
    /// one distinction this field exists to make.
    private var firstSeenAudioPTS: CMTime?
    /// Wall-clock instant the record request entered the native layer, and how
    /// long `attachAudioToSessionIfNeeded()` blocked. A slow attach delays the
    /// *whole* recording — video included — so it loses leading content
    /// without shifting audio against video. Distinguishing that from real
    /// leading silence is the point of measuring both.
    private var recordRequestTime: Date?
    private var lastAudioAttachMs: Double = 0
    /// Which branch the most recent `attachAudioToSessionIfNeeded()` took, and
    /// what the shared session looked like on entry. A drifted category forces
    /// the slow deactivate/reconfigure/activate cycle inline on the record tap,
    /// which delays the whole recording rather than just audio.
    ///
    /// Process-wide, not per recording: the deferred pre-warm, the
    /// interruption-ended handler and `resumePreview()` all attach again and
    /// can land mid-recording.
    private var lastAudioAttachPath = "unknown"
    private var lastAudioEntryRoute = "unknown"
    /// The pair above as it stood for *this* recording, snapshotted at the
    /// record tap next to `lastAudioAttachMs`. Reading the live values at
    /// stop time would print one attach's path beside another attach's
    /// duration: `sessionQueue` is serial, so the deferred pre-warm cannot
    /// overlap the tap's attach — it becomes ready at its deadline and runs
    /// straight after it, mid-recording, overwriting the pair while
    /// `lastAudioAttachMs` still holds the tap's own cost.
    private var recordingAudioAttachPath = "unknown"
    private var recordingAudioEntryRoute = "unknown"
    /// Wall clock at which the writer session was anchored, i.e. when capture
    /// actually began. Against `recordRequestTime` this is the tap-to-capture
    /// delay the user experiences as lost leading content.
    private var writerSessionStartedAt: Date?
    
    private var textureRegistry: FlutterTextureRegistry

    /// Re-asserts the owning (UI) engine's diagnostics sink before emitting
    /// native-only diagnostics that fire without a method call — the
    /// audio-session interruption observer, the sample-buffer delegate's
    /// first-frame / writer-start breadcrumbs, the frame watchdog and
    /// init-timeout timers, and the max-duration auto-stop's recording-
    /// finalization breadcrumbs. iOS has no Activity-attachment lifecycle to
    /// bind sink ownership to, so this keeps a background engine that
    /// registered the plugin from stealing these UI-only events. See #5128.
    private let reclaimLogSink: (() -> Void)?

    private var textureId: Int64 = -1
    private var pixelBufferRef: CVPixelBuffer?
    private var latestSampleBuffer: CMSampleBuffer?
    private let pixelBufferLock = NSLock()
    
    private var currentLens: AVCaptureDevice.Position = .back
    private var currentFlashMode: AVCaptureDevice.FlashMode = .off
    private var currentTorchMode: AVCaptureDevice.TorchMode = .off
    private var isRecording: Bool = false
    private var isPaused: Bool = false
    
    // Screen brightness for front camera "torch" mode
    private var originalBrightness: CGFloat?
    private var screenFlashFeatureEnabled: Bool = true
    
    // Whether to mirror front camera video output
    private var mirrorFrontCameraOutput: Bool = true

    // Requested video stabilization mode. Applied to the video connection,
    // so it affects both the live preview texture and the recorded file.
    // Defaults to .off to preserve existing behaviour until the user opts in.
    private var requestedStabilizationMode: AVCaptureVideoStabilizationMode = .off

    /// True once `previewOutput` is wired and able to carry `.previewOptimized`.
    private var previewOptimizedActive = false

    /// True while the preview texture should be fed from `previewOutput` rather
    /// than `videoOutput` — i.e. the dual-output path is active AND the user has
    /// a non-off stabilization mode selected.
    ///
    /// Synchronized because writes happen while applying stabilization on
    /// `sessionQueue`, while reads happen on `videoOutputQueue` in
    /// `captureOutput`.
    private let previewDrivesTextureLock = NSLock()
    private var _previewDrivesTexture = false
    private var previewDrivesTexture: Bool {
        get {
            previewDrivesTextureLock.lock()
            defer { previewDrivesTextureLock.unlock() }
            return _previewDrivesTexture
        }
        set {
            previewDrivesTextureLock.lock()
            _previewDrivesTexture = newValue
            previewDrivesTextureLock.unlock()
        }
    }

    // Auto lens switching via zoom
    // When true, uses a virtual multi-camera device (builtInTripleCamera,
    // builtInDualWideCamera, etc.) for smooth cross-fade between lenses.
    private var autoLensSwitchRequested: Bool = true
    
    // Auto flash mode - checks brightness once when recording starts
    private var isAutoFlashMode: Bool = false
    private var autoFlashTorchEnabled: Bool = false
    
    // Thresholds for "dark" detection:
    // iOS keeps ISO low and uses longer exposure times, so we need higher exposure thresholds
    // Front camera: Higher exposure threshold since screen flash is less intrusive
    // Back camera: Higher thresholds to avoid triggering in normal indoor light
    private let frontCameraIsoThreshold: Float = 500
    private let frontCameraExposureThreshold: Float = 0.040  // 40ms
    private let backCameraIsoThreshold: Float = 600
    private let backCameraExposureThreshold: Float = 0.030  // 30ms
    
    private var minZoom: CGFloat = 1.0
    private var maxZoom: CGFloat = 1.0
    private var currentZoom: CGFloat = 1.0
    // Scale factor to convert native videoZoomFactor to user-facing zoom.
    // Virtual multi-camera devices (builtInTripleCamera, builtInDualWideCamera)
    // start at ultra-wide where native 1.0 = 0.5x user. Wide angle = native 2.0 = 1.0x user.
    // So scale = 0.5 for those devices, 1.0 for single-lens cameras.
    private var nativeToUserZoomScale: CGFloat = 1.0
    // Portrait-Modus: 9:16, e.g: 1080x1920
    private var aspectRatio: CGFloat = 9.0 / 16.0
    
    private var hasFrontCamera: Bool = false
    private var hasBackCamera: Bool = false
    private var hasFlash: Bool = false
    private var isFocusPointSupported: Bool = false
    private var isExposurePointSupported: Bool = false
    
    // Multi-lens support
    private var hasUltraWideCamera: Bool = false
    private var hasTelephotoCamera: Bool = false
    private var hasMacroCamera: Bool = false
    private var hasFrontUltraWideCamera: Bool = false
    
    // Current lens type (more granular than just position)
    private var currentLensType: String = "back"
    
    private var recordingStartTime: Date?
    private var currentRecordingURL: URL?
    private var recordingCompletion: (([String: Any]?, String?) -> Void)?
    private var maxDurationTimer: Timer?
    private var maxDurationMs: Int?
    private var isWriterSessionStarted: Bool = false

    /// End PTS (`presentationTime + frameDuration`) of the last video frame
    /// appended to the asset writer. Used at finalize to bound the writer
    /// session to the video's actual end, so a look-ahead stabilization mode
    /// (which delays video ~0.5–1s behind audio) can't leave the clip ending on
    /// a frozen frame while audio keeps playing. The frame's *end* — not its
    /// start — so the last frame keeps its full display duration and short
    /// recordings don't collapse toward zero.
    private var lastVideoFrameEndPTS: CMTime?
    
    /// Completion handler for camera switch - called when first frame from new camera arrives
    private var switchCameraCompletion: (([String: Any]?, String?) -> Void)?
    
    /// Completion handler for camera initialization - called when first frame arrives
    private var initializationCompletion: (([String: Any]?, String?) -> Void)?
    
    /// Timeout timer for initialization (fallback if no frames arrive)
    private var initializationTimeoutTimer: Timer?
    
    private let sessionQueue = DispatchQueue(label: "com.divine_camera.session")
    private let videoOutputQueue = DispatchQueue(label: "com.divine_camera.videoOutput")
    
    init(
        textureRegistry: FlutterTextureRegistry,
        reclaimLogSink: (() -> Void)? = nil
    ) {
        self.textureRegistry = textureRegistry
        self.reclaimLogSink = reclaimLogSink
        super.init()
        checkCameraAvailability()
        registerAudioSessionInterruptionObserver()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Checks which cameras are available on the device.
    private func checkCameraAvailability() {
        // Check front camera
        let frontDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .front
        )
        hasFrontCamera = !frontDiscoverySession.devices.isEmpty
        
        // Check front ultra-wide camera (iOS 13+, available on some iPads)
        if #available(iOS 13.0, *) {
            let frontUltraWideDiscoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInUltraWideCamera],
                mediaType: .video,
                position: .front
            )
            hasFrontUltraWideCamera = !frontUltraWideDiscoverySession.devices.isEmpty
        }
        
        // Check back cameras
        let backDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        )
        hasBackCamera = !backDiscoverySession.devices.isEmpty
        
        // Check ultra-wide camera (iOS 13+)
        if #available(iOS 13.0, *) {
            let ultraWideDiscoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInUltraWideCamera],
                mediaType: .video,
                position: .back
            )
            hasUltraWideCamera = !ultraWideDiscoverySession.devices.isEmpty
        }
        
        // Check telephoto camera
        let telephotoDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTelephotoCamera],
            mediaType: .video,
            position: .back
        )
        hasTelephotoCamera = !telephotoDiscoverySession.devices.isEmpty
        
        // Check for macro capability (iOS 15+ on devices with ultra-wide lens capable of macro)
        // Macro is typically available on ultra-wide lens on iPhone 13 Pro and later
        if #available(iOS 15.0, *) {
            if hasUltraWideCamera {
                // On iOS 15+, devices with ultra-wide can support macro mode
                // The ultra-wide lens on Pro models has minimum focus distance for macro
                if let ultraWideDevice = AVCaptureDevice.default(
                    .builtInUltraWideCamera,
                    for: .video,
                    position: .back
                ) {
                    // Check if the ultra-wide supports close focus (macro)
                    // Devices supporting macro typically have minimum focus distance < 0.5m
                    let format = ultraWideDevice.activeFormat
                    if format.autoFocusSystem == .phaseDetection || format.autoFocusSystem == .contrastDetection {
                        // Ultra-wide with autofocus can typically do macro
                        hasMacroCamera = true
                    }
                }
            }
        }
        
        DivineCameraLog.shared.debug("[DivineCameraController] Camera availability: front=\(hasFrontCamera), " +
              "frontUltraWide=\(hasFrontUltraWideCamera), back=\(hasBackCamera), " +
              "ultraWide=\(hasUltraWideCamera), telephoto=\(hasTelephotoCamera), macro=\(hasMacroCamera)")
        
        // Log virtual multi-camera device availability
        if #available(iOS 13.0, *) {
            let hasTriple = AVCaptureDevice.default(
                .builtInTripleCamera, for: .video, position: .back
            ) != nil
            let hasDualWide = AVCaptureDevice.default(
                .builtInDualWideCamera, for: .video, position: .back
            ) != nil
            let hasDual = AVCaptureDevice.default(
                .builtInDualCamera, for: .video, position: .back
            ) != nil
            DivineCameraLog.shared.debug("[DivineCameraController] Virtual devices: " +
                  "triple=\(hasTriple), dualWide=\(hasDualWide), dual=\(hasDual)")
        }
    }
    
    /// Configures the audio session for video recording with proper Bluetooth headphone routing.
    ///
    /// When AVCaptureSession has an audio input, iOS defaults to routing audio output to the
    /// built-in speaker (not earpiece, not headphones) because it assumes the user wants to
    /// hear themselves during recording. This causes audio to come from the speaker even when
    /// Bluetooth headphones are connected.
    ///
    /// By explicitly setting ONLY allowBluetoothA2DP (without allowBluetooth), we tell iOS to:
    /// - Route audio playback to Bluetooth headphones in A2DP (music) mode
    /// - Use the built-in microphone for recording (NOT the Bluetooth mic)
    /// This prevents iOS from switching to HFP (phone call) mode which causes the
    /// "call started/ended" sounds on Bluetooth headsets.
    @discardableResult
    private func configureAudioSessionForRecording() -> Bool {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Use playAndRecord category since we need both:
            // - Record: Microphone capture for video (uses built-in mic)
            // - Play: Playing selected sounds through Bluetooth headphones (uses A2DP)
            //
            // Options:
            // - defaultToSpeaker: Use speaker (not earpiece) when no headphones connected
            // - allowBluetoothA2DP: Route playback to Bluetooth in A2DP mode
            //
            // IMPORTANT: Do NOT include .allowBluetooth!
            // .allowBluetooth enables HFP (Hands-Free Profile) which:
            // - Triggers "call started/ended" sounds on headsets
            // - Switches to low-quality phone audio
            // - Routes microphone input through Bluetooth (not needed for video)
            //
            // Deactivate the current session first so any in-flight AVPlayer
            // (.playback category) fully releases its audio pipeline before we
            // switch categories. Without this, setCategory on an active session
            // can fail or the mic gets no samples because the session
            // transitions while still active.
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            // Mode picks the input processing:
            // - .videoRecording (default) applies system-level noise
            //   suppression tuned for direct capture, which keeps speech
            //   clean but treats sustained non-speech as noise and gates it
            //   away — that is what eats an instrument (#7796).
            // - .measurement is the mode Apple documents as minimising
            //   system-supplied signal processing, so music survives at its
            //   real level. It costs the camera-adjacent mic selection and
            //   level normalisation .videoRecording does for speech, which is
            //   why it is opt-in rather than the default.
            var mode = desiredAudioSessionMode
            do {
                try audioSession.setCategory(
                    .playAndRecord,
                    mode: mode,
                    options: [.defaultToSpeaker, .allowBluetoothA2DP]
                )
            } catch {
                // A device that refuses .measurement must still record: the
                // outer catch returns false, and a false here means the clip
                // ships with no audio track at all — a far worse outcome than
                // the processing the user opted out of.
                guard mode != .videoRecording else { throw error }
                DivineCameraLog.shared.warning(
                    "Audio session rejected mode=\(mode.rawValue) "
                        + "(\(error.localizedDescription)) — falling back to "
                        + "videoRecording",
                    name: "DivineCamera.AudioSession"
                )
                mode = .videoRecording
                try audioSession.setCategory(
                    .playAndRecord,
                    mode: mode,
                    options: [.defaultToSpeaker, .allowBluetoothA2DP]
                )
                // Stop asking for a mode this device refuses. Left set, the
                // reuse path in attachAudioToSessionIfNeeded() would read a
                // permanent mode mismatch and tear the audio capture session
                // down and back up before every recording, and its cheap
                // setActive(true) interruption recovery would never run
                // again. initialize() re-arms the preference, so the refusal
                // only latches for this capture session.
                prefersUnprocessedAudio = false
            }
            try audioSession.setActive(true)
            DivineCameraLog.shared.info(
                "Audio session configured: A2DP playback, built-in mic for "
                    + "recording, mode=\(mode.rawValue)",
                name: "DivineCamera.AudioSession"
            )
            return true
        } catch {
            DivineCameraLog.shared.error(
                "Failed to configure audio session: \(error.localizedDescription)",
                name: "DivineCamera.AudioSession"
            )
            return false
        }
    }

    /// Observe AVAudioSession interruptions (Spotify, phone calls, Siri,
    /// alarms). On `.began` we mark audio as interrupted so any in-flight
    /// recording stops trying to append audio buffers. On `.ended` with
    /// `.shouldResume` we attempt to reactivate the session and restart the
    /// audio capture session so the next recording (or the remainder of the
    /// current one) gets sound back.
    private func registerAudioSessionInterruptionObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        // Native-only event: reclaim the UI engine's diagnostics sink before
        // any logging below.
        reclaimLogSink?()

        switch type {
        case .began:
            // Access goes through the lock-backed `audioInterrupted`
            // accessor so cross-queue reads from `videoOutputQueue`
            // (captureOutput) see a consistent value.
            self.audioInterrupted = true
            DivineCameraLog.shared.warning(
                "AVAudioSession interruption began — audio capture paused "
                    + "(reason=\(Self.interruptionReasonDescription(info)))",
                name: "DivineCamera.AudioSession"
            )
        case .ended:
            let shouldResume: Bool = {
                guard let raw = info[AVAudioSessionInterruptionOptionKey] as? UInt else {
                    return false
                }
                return AVAudioSession.InterruptionOptions(rawValue: raw).contains(.shouldResume)
            }()
            DivineCameraLog.shared.info(
                "AVAudioSession interruption ended (shouldResume=\(shouldResume))",
                name: "DivineCamera.AudioSession"
            )
            // Always try to recover — even when shouldResume is false the
            // user can still press record again and we want a working session.
            // attachAudioToSessionIfNeeded() must run on sessionQueue (it
            // mutates capture-session state); the lock-backed
            // `audioInterrupted` accessor handles cross-queue safety.
            // Only clear `audioInterrupted` after a successful recovery —
            // otherwise `captureOutput` would resume appending audio from a
            // still-broken session and re-introduce the silent-AAC-track
            // failure this patch eliminates. If recovery fails, keep the
            // flag set so the next recording continues without audio.
            sessionQueue.async { [weak self] in
                guard let self = self else { return }
                // While paused (app locked / backgrounded) don't re-grab
                // the mic; resumePreview() recovers instead.
                guard !self.isPaused else { return }
                if self.attachAudioToSessionIfNeeded() {
                    self.audioInterrupted = false
                } else {
                    DivineCameraLog.shared.error(
                        "Audio recovery failed; next recording continues without audio",
                        name: "DivineCamera.AudioSession"
                    )
                }
            }
        @unknown default:
            break
        }
    }

    /// Human-readable interruption reason for the diagnostics log.
    /// `builtInMicMuted` (iPad hardware mic mute) silently kills capture
    /// and is invisible without this.
    private static func interruptionReasonDescription(
        _ info: [AnyHashable: Any]
    ) -> String {
        guard #available(iOS 14.5, *),
              let raw = info[AVAudioSessionInterruptionReasonKey] as? UInt else {
            return "unspecified"
        }
        if #available(iOS 17.0, *),
           AVAudioSession.InterruptionReason(rawValue: raw) == .routeDisconnected {
            return "routeDisconnected"
        }
        switch AVAudioSession.InterruptionReason(rawValue: raw) {
        case .default: return "default"
        case .builtInMicMuted: return "builtInMicMuted"
        default: return "raw(\(raw))"
        }
    }

    /// Gets metadata for the currently active camera lens.
    private func getCurrentLensMetadata() -> [String: Any]? {
        guard let device = videoDevice else {
            return nil
        }
        return extractCameraMetadata(device: device, lensType: currentLensType)
    }
    
    /// Extracts metadata from an AVCaptureDevice.
    /// For C2PA compliance, only values that iOS actually provides are included.
    /// Estimated values (focalLength, sensorSize, minFocusDistance) are left as nil.
    private func extractCameraMetadata(device: AVCaptureDevice, lensType: String) -> [String: Any] {
        let format = device.activeFormat
        let formatDescription = format.formatDescription
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        
        // iOS doesn't expose physical focal length directly
        // This would need to come from EXIF data of captured images
        let focalLength: Double? = nil
        
        // Aperture IS available on iOS via lensAperture property
        let aperture: Double = Double(device.lensAperture)
        
        var fieldOfView: Double? = nil
        
        // Field of view is available on the format
        let fov = format.videoFieldOfView
        if fov > 0 {
            fieldOfView = Double(fov)
        }
        
        // Try to get more accurate field of view from device formats
        if #available(iOS 13.0, *) {
            // Get geometric distortion corrected field of view if available
            if let videoFormat = device.formats.first(where: { $0 === format }) {
                fieldOfView = Double(videoFormat.videoFieldOfView)
            }
        }
        
        // Min focus distance
        // Note: iOS doesn't expose actual minimum focus distance values.
        // For C2PA compliance, we leave this as nil rather than providing estimates.
        let minFocusDistance: Double? = nil
        
        // Optical stabilization
        let hasOpticalStabilization = device.activeFormat.isVideoStabilizationModeSupported(.cinematic) ||
                                      device.activeFormat.isVideoStabilizationModeSupported(.standard)
        
        // Sensor size - iOS doesn't expose actual sensor dimensions
        let sensorWidth: Double? = nil
        let sensorHeight: Double? = nil
        
        // Calculate 35mm equivalent focal length from field of view
        // This IS accurate as it's mathematically derived from FOV which iOS provides.
        // Formula: FOV = 2 * arctan(sensor_diagonal / (2 * focal_length))
        // For 35mm film: diagonal = 43.27mm
        // Therefore: focal_length_35mm = 43.27 / (2 * tan(FOV/2))
        var focalLengthEquivalent35mm: Double? = nil
        if let fov = fieldOfView, fov > 0 {
            let fovRadians = fov * .pi / 180.0
            let equivalent = 43.27 / (2.0 * tan(fovRadians / 2.0))
            focalLengthEquivalent35mm = equivalent
        }
        
        // Check if this is a multi-camera logical device
        var isLogicalCamera = false
        var physicalCameraIds: [String] = []
        if #available(iOS 13.0, *) {
            let physicalDevices = device.constituentDevices
            isLogicalCamera = physicalDevices.count > 1
            physicalCameraIds = physicalDevices.map { $0.uniqueID }
        }
        
        // Camera unique identifier
        let cameraId = device.uniqueID
        
        // Exposure duration in seconds (live value)
        let exposureDuration = CMTimeGetSeconds(device.exposureDuration)
        
        // ISO sensitivity (live value)
        let iso = Double(device.iso)
        
        return [
            "lensType": lensType,
            "cameraId": cameraId,
            "focalLength": focalLength as Any,
            "focalLengthEquivalent35mm": focalLengthEquivalent35mm as Any,
            "aperture": aperture,
            "sensorWidth": sensorWidth as Any,
            "sensorHeight": sensorHeight as Any,
            "pixelArrayWidth": Int(dimensions.width),
            "pixelArrayHeight": Int(dimensions.height),
            "minFocusDistance": minFocusDistance as Any,
            "fieldOfView": fieldOfView as Any,
            "hasOpticalStabilization": hasOpticalStabilization,
            "isLogicalCamera": isLogicalCamera,
            "physicalCameraIds": physicalCameraIds,
            "exposureDuration": exposureDuration,
            "iso": iso
        ]
    }
    
    /// Returns a list of available lens types on this device.
    private func getAvailableLenses() -> [String] {
        var lenses: [String] = []
        if hasFrontCamera { lenses.append("front") }
        if hasFrontUltraWideCamera { lenses.append("frontUltraWide") }
        if hasBackCamera { lenses.append("back") }
        if hasUltraWideCamera { lenses.append("ultraWide") }
        if hasTelephotoCamera { lenses.append("telephoto") }
        if hasMacroCamera { lenses.append("macro") }
        return lenses
    }
    
    /// Gets the AVCaptureDevice for the specified lens type.
    private func getDeviceForLensType(_ lensType: String) -> AVCaptureDevice? {
        switch lensType {
        case "front":
            return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        case "frontUltraWide":
            if #available(iOS 13.0, *) {
                return AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .front)
            }
            return nil
        case "back":
            // When auto lens switch is enabled, use virtual multi-camera
            // devices for smooth cross-fade transitions between lenses.
            if autoLensSwitchRequested {
                if #available(iOS 13.0, *) {
                    if let device = AVCaptureDevice.default(
                        .builtInTripleCamera, for: .video, position: .back
                    ) {
                        return device
                    }
                    if let device = AVCaptureDevice.default(
                        .builtInDualWideCamera, for: .video, position: .back
                    ) {
                        return device
                    }
                }
                if let device = AVCaptureDevice.default(
                    .builtInDualCamera, for: .video, position: .back
                ) {
                    return device
                }
            }
            return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        case "ultraWide":
            if #available(iOS 13.0, *) {
                return AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
            }
            return nil
        case "telephoto":
            return AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back)
        case "macro":
            // Macro uses ultra-wide lens on iOS
            if #available(iOS 13.0, *) {
                return AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
            }
            return nil
        default:
            return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        }
    }
    
    /// Gets the position for the specified lens type.
    private func getPositionForLensType(_ lensType: String) -> AVCaptureDevice.Position {
        switch lensType {
        case "front", "frontUltraWide":
            return .front
        default:
            return .back
        }
    }
    
    /// Initializes the camera with the specified lens.
    private var videoQualityPreset: AVCaptureSession.Preset = .high

    /// Target H.264 bitrate in bits per second for the recording
    /// AVAssetWriter. Mirrors `DivineVideoQuality.bitrate` in
    /// `lib/src/models/video_quality.dart`.
    private var videoEncodingBitRate = 8_000_000

    /// Initializes the camera with the specified lens and video quality.
    func initialize(lens: String, videoQuality: String, enableScreenFlash: Bool = true, mirrorFrontCameraOutput: Bool = true, enableAutoLensSwitch: Bool = true, preferUnprocessedAudio: Bool = false, completion: @escaping ([String: Any]?, String?) -> Void) {
        self.autoLensSwitchRequested = enableAutoLensSwitch
        self.prefersUnprocessedAudio = preferUnprocessedAudio
        currentLensType = lens
        currentLens = getPositionForLensType(lens)
        screenFlashFeatureEnabled = enableScreenFlash
        self.mirrorFrontCameraOutput = mirrorFrontCameraOutput
        
        // Fallback to available camera if requested lens is not available
        if getDeviceForLensType(currentLensType) == nil {
            // Try back camera first, then front
            if hasBackCamera {
                DivineCameraLog.shared.warning(
                    "Requested lens \(lens) not available, falling back to back camera",
                    name: "DivineCamera.Lifecycle"
                )
                currentLensType = "back"
                currentLens = .back
            } else if hasFrontCamera {
                DivineCameraLog.shared.warning(
                    "Requested lens \(lens) not available, falling back to front camera",
                    name: "DivineCamera.Lifecycle"
                )
                currentLensType = "front"
                currentLens = .front
            }
        }
        
        // Map video quality string to AVCaptureSession.Preset and target bitrate
        switch videoQuality {
        case "sd":
            videoQualityPreset = .medium
            videoEncodingBitRate = 2_000_000
        case "hd":
            videoQualityPreset = .hd1280x720
            videoEncodingBitRate = 4_000_000
        case "fhd":
            videoQualityPreset = .hd1920x1080
            videoEncodingBitRate = 8_000_000
        case "uhd":
            if #available(iOS 9.0, *) {
                videoQualityPreset = .hd4K3840x2160
            } else {
                videoQualityPreset = .hd1920x1080
            }
            videoEncodingBitRate = 20_000_000
        case "highest":
            videoQualityPreset = .high
            videoEncodingBitRate = 20_000_000
        case "lowest":
            videoQualityPreset = .low
            videoEncodingBitRate = 2_000_000
        default:
            videoQualityPreset = .hd1920x1080
            videoEncodingBitRate = 8_000_000
        }
        
        sessionQueue.async { [weak self] in
            self?.setupCamera(completion: completion)
        }
    }
    
    /// Sets up the camera session.
    private func setupCamera(completion: @escaping ([String: Any]?, String?) -> Void) {
        // NOTE: We do NOT explicitly configure AVAudioSession here.
        // AVCaptureSession automatically manages the audio session when an
        // audio input device is added below. Explicitly setting .playAndRecord
        // with .allowBluetooth/.allowBluetoothA2DP causes iOS to establish a
        // Bluetooth audio connection, which triggers spurious play/pause events
        // on connected devices (AirPods, Apple Watch) via MPRemoteCommandCenter.
        
        // Create capture session
        let session = AVCaptureSession()
        
        // CRITICAL: Disable automatic audio session configuration!
        // By default, AVCaptureSession automatically configures the audio session when
        // an audio input is added, which overrides our manual configuration and routes
        // audio output to the speaker instead of connected Bluetooth headphones.
        // Setting this to false lets us control the audio session ourselves.
        session.automaticallyConfiguresApplicationAudioSession = false
        
        session.beginConfiguration()
        
        // Setup video input FIRST (before setting preset)
        guard let videoDevice = getDeviceForLensType(currentLensType) else {
            completion(nil, "No camera available for lens type: \(currentLensType)")
            return
        }
        
        self.videoDevice = videoDevice
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            
            // Add input before setting preset
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                self.videoInput = videoInput
            } else {
                completion(nil, "Cannot add video input")
                return
            }
            
            // Now set preset AFTER adding input - try requested quality with fallback
            let presetsToTry: [AVCaptureSession.Preset] = [
                videoQualityPreset,
                .hd4K3840x2160,
                .hd1920x1080,
                .hd1280x720,
                .high,
                .medium,
                .low
            ]
            
            var presetSet = false
            for preset in presetsToTry {
                if session.canSetSessionPreset(preset) {
                    session.sessionPreset = preset
                    if preset != videoQualityPreset {
                        DivineCameraLog.shared.warning(
                            "Requested capture preset not supported, falling back to: \(preset.rawValue)",
                            name: "DivineCamera.Lifecycle"
                        )
                    }
                    presetSet = true
                    break
                }
            }
            
            if !presetSet {
                DivineCameraLog.shared.warning(
                    "Could not set any preferred capture preset",
                    name: "DivineCamera.Lifecycle"
                )
            }
        } catch {
            completion(nil, "Failed to create video input: \(error.localizedDescription)")
            return
        }
        
        // NOTE: Audio input/output are intentionally NOT added here.
        // AudioToolbox + AVAudioSession.setCategory trigger dyld image-load
        // notifications + an XPC roundtrip to mediaserverd, which freezes the
        // main thread on the first camera open. We add them lazily in
        // startRecording() instead, mirroring flutter's camera_avfoundation
        // plugin (setUpCaptureSessionForAudioIfNeeded). The session preset
        // remains video-only, audio gets attached when the user actually records.
        
        // Setup video output for preview
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        // Don't discard late frames - we need them for the texture
        videoOutput.alwaysDiscardsLateVideoFrames = false
        
        // Use a dedicated queue for video output to avoid blocking the session queue
        videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            self.videoOutput = videoOutput
            DivineCameraLog.shared.debug("DivineCamera: Video output added successfully")
            
            // Set video orientation to portrait
            if let connection = videoOutput.connection(with: .video) {
                DivineCameraLog.shared.debug("DivineCamera: Video connection established")
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                // Mirror pixels only for front camera when mirrorFrontCameraOutput is enabled
                // When mirrored here, Flutter doesn't need to apply preview transform
                // When NOT mirrored here, Flutter applies visual transform for selfie preview
                if connection.isVideoMirroringSupported {
                    let isFront = currentLens == .front
                    connection.isVideoMirrored = isFront && mirrorFrontCameraOutput
                }
            }
        } else {
            DivineCameraLog.shared.error("DivineCamera: Cannot add video output to session", name: "DivineCamera.Setup")
        }

        // Still-photo output for single-frame (stop-motion) capture. Safe to add
        // here: AVCapturePhotoOutput does not conflict with the video data output.
        let photoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            self.photoOutput = photoOutput
            if let connection = photoOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                if connection.isVideoMirroringSupported {
                    let isFront = currentLens == .front
                    connection.isVideoMirrored = isFront && mirrorFrontCameraOutput
                }
            }
            DivineCameraLog.shared.debug("DivineCamera: Photo output added successfully")
        } else {
            DivineCameraLog.shared.error("DivineCamera: Cannot add photo output to session", name: "DivineCamera.Setup")
        }

        // Optional preview-optimized output (iOS 17+). A second, preview-sized
        // data output carries `.previewOptimized`, so the live preview stays
        // smooth and does not jump when recording starts. `videoOutput` keeps
        // the user-selected overscan mode for the recorded file. Added AFTER the
        // photo output so that, on any device with an output-count limit, the
        // existing photo capture wins and this optional output falls back to the
        // single-output preview path.
        setupPreviewOptimizedOutputIfPossible(session: session)

        // NOTE: AVCaptureAudioDataOutput is also added lazily in startRecording().
        
        // NOTE: MovieOutput is intentionally NOT added here during initialization.
        // AVCaptureMovieFileOutput conflicts with AVCaptureVideoDataOutput on some devices,
        // causing the video data output delegate to not receive frames.
        // MovieOutput will be added dynamically when recording starts and removed when it stops.
        
        session.commitConfiguration()
        
        // Get camera properties
        updateCameraProperties(device: videoDevice)

        // Re-assert the requested stabilization mode on the freshly built
        // video connection (a no-op while the mode is still .off).
        applyVideoStabilization()

        // Set initial zoom to 1.0x (wide angle) for virtual multi-camera devices.
        // Without this, the camera starts at native 1.0 which is the ultra-wide (0.5x).
        if nativeToUserZoomScale < 1.0 {
            let nativeWideZoom = 1.0 / nativeToUserZoomScale  // 2.0 for triple/dualWide
            do {
                try videoDevice.lockForConfiguration()
                videoDevice.videoZoomFactor = nativeWideZoom
                videoDevice.unlockForConfiguration()
                currentZoom = 1.0
            } catch {
                DivineCameraLog.shared.warning("DivineCamera: Failed to set initial zoom to 1.0x: \(error.localizedDescription)", name: "DivineCamera.Setup")
            }
        }
        
        // Start session first so frames start flowing
        session.startRunning()
        self.captureSession = session
        
        // Debug: Check session and connection status
        DivineCameraLog.shared.debug("DivineCamera: Session running: \(session.isRunning)")
        if let connection = self.videoOutput?.connection(with: .video) {
            DivineCameraLog.shared.debug("DivineCamera: Video connection active: \(connection.isActive), enabled: \(connection.isEnabled)")
        } else {
            DivineCameraLog.shared.error("DivineCamera: No video connection available", name: "DivineCamera.Setup")
        }
        
        // Watchdog: Check if frames are flowing after 1 second
        // On some iOS devices/versions, AVCaptureSession can be "stuck" and not deliver frames
        // until it's restarted. This watchdog detects this condition and restarts the session.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }

            // Native-only event (watchdog timer, no method call): reclaim the
            // UI engine's diagnostics sink before the watchdog breadcrumbs.
            self.reclaimLogSink?()

            self.pixelBufferLock.lock()
            let hasReceivedFrames = self.pixelBufferRef != nil
            self.pixelBufferLock.unlock()
            
            if !hasReceivedFrames {
                DivineCameraLog.shared.warning("DivineCamera: WATCHDOG - no frames received after 1s, restarting session", name: "DivineCamera.Setup")
                self.sessionQueue.async { [weak self] in
                    guard let self = self, let session = self.captureSession else { return }
                    
                    // Stop and restart the session to "kick" it
                    session.stopRunning()

                    // Brief pause before restarting
                    self.sessionQueue.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        guard let self = self, let session = self.captureSession else { return }
                        session.startRunning()
                        DivineCameraLog.shared.debug("DivineCamera: ✅ Session restarted by watchdog")
                    }
                }
            } else {
                DivineCameraLog.shared.debug("DivineCamera: ✅ Watchdog: Frames are flowing normally")
            }
        }
        
        // Register texture after session is running
        textureId = textureRegistry.register(self)
        DivineCameraLog.shared.debug("DivineCamera: Registered texture with ID: \(textureId)")
        
        // NOTE: AVAssetWriter (VideoToolbox) and audio stack (AudioToolbox)
        // pre-warming used to live here, but doing dlopen() on a background
        // queue while Main is still wiring up the camera page causes dyld to
        // post process-wide image-load notifications that block Main on its
        // next lazy symbol bind — that was the original 1s freeze on open.
        //
        // Both pre-warms now run from AppDelegate at app launch instead, so
        // by the time the user reaches the camera page everything is warm
        // and Main is not blocked.
        
        // Store completion handler to call when first frame arrives
        // This ensures the camera is truly delivering frames before we report success
        self.initializationCompletion = completion
        
        // Set a timeout in case frames don't arrive (fallback to complete anyway)
        DispatchQueue.main.async { [weak self] in
            self?.initializationTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                // Native-only entry (init-timeout timer, no method call): the
                // first-frame caller reclaims at captureOutput, but the
                // once-only guard means that never runs on the timeout path.
                self?.reclaimLogSink?()
                self?.completeInitializationIfNeeded(timedOut: true)
            }
        }
    }
    
    /// Lazily sets up a SEPARATE AVCaptureSession for audio capture and starts
    /// it. This is the two-session pattern used by flutter's camera_avfoundation
    /// plugin. Why two sessions:
    ///
    /// - Adding an audio input to the running video session causes a pipeline
    ///   reconfiguration → black-frame stall on the preview + Main-thread
    ///   freeze (~200-500ms) the first time it happens.
    /// - A dedicated audio session runs in parallel and only does audio work,
    ///   so attaching/starting it never disturbs the video preview.
    /// - The audio sample buffer delegate routes samples to the AVAssetWriter
    ///   exactly like before — so the recording output is unchanged.
    ///
    /// Both sessions have automaticallyConfiguresApplicationAudioSession = false
    /// and we manage AVAudioSession ourselves via configureAudioSessionForRecording().
    ///
    /// Returns true if audio is available, false if the user denied permission
    /// or no audio device exists. Returning false is non-fatal — recording
    /// continues without audio (matches the previous behaviour).
    private func attachAudioToSessionIfNeeded() -> Bool {
        // Already set up with input/output wired to a capture session?
        //
        // Two recovery cases on this path:
        //   1. Category drift — the feed's AVPlayer can reset the shared
        //      session to .playback between recordings. We must do a full
        //      reconfigure (deactivate + setCategory + activate).
        //   2. Audio interruption (e.g. Spotify briefly took over) — the
        //      category stays .playAndRecord but iOS deactivates our
        //      session and stops the audio AVCaptureSession. We must
        //      reactivate (setActive(true) only) before restarting capture.
        //
        // IMPORTANT: do NOT call configureAudioSessionForRecording() when
        // the category is already correct. Its setActive(false) step
        // silently breaks the audio route while the audio AVCaptureSession
        // is running — buffers keep flowing but contain digital silence,
        // producing a recording with a valid AAC track that has no sound.
        if let existing = self.audioCaptureSession,
           self.audioInput != nil,
           self.audioOutput != nil {
            let session = AVAudioSession.sharedInstance()
            // Mode is part of the contract, not just category: a session left
            // on .videoRecording would keep gating instruments away even
            // though the user asked for unprocessed capture (#7796).
            let needsReconfigure = session.category != .playAndRecord
                || session.mode != desiredAudioSessionMode
            self.lastAudioEntryRoute = "category=\(session.category.rawValue)"
                + ",mode=\(session.mode.rawValue)"
                + ",running=\(existing.isRunning)"
            self.lastAudioAttachPath = needsReconfigure
                ? "reconfigure" : (existing.isRunning ? "warm" : "restart")
            if needsReconfigure {
                // CRITICAL: stop the audio AVCaptureSession before the
                // setActive(false)/setActive(true) cycle inside
                // configureAudioSessionForRecording(). If we don't, the
                // capture session keeps the now-stale audio route attached
                // and continues delivering buffers that contain only
                // digital silence — producing a recording with a valid
                // AAC track that has no sound.
                let wasRunning = existing.isRunning
                if wasRunning {
                    existing.stopRunning()
                }
                let configured = configureAudioSessionForRecording()
                if !configured {
                    return false
                }
                // After a successful reconfigure, restart the dedicated
                // audio capture session whenever it is not running — not
                // just when it happened to be running before stopRunning().
                // An interruption / category drift can leave the session
                // already stopped on entry, in which case `wasRunning`
                // is false but we still need to bring it back up so the
                // next recording actually captures audio.
                if !existing.isRunning {
                    existing.startRunning()
                }
            } else {
                // Recover from interruption: setActive(true) is a no-op when
                // the session is already active, but reactivates it after
                // an interruption (Spotify, phone call, Siri, etc.).
                do {
                    try session.setActive(true)
                } catch {
                    DivineCameraLog.shared.error(
                        "setActive(true) on existing audio session failed: "
                            + "\(error.localizedDescription)",
                        name: "DivineCamera.AudioSession"
                    )
                    return false
                }
                if !existing.isRunning {
                    existing.startRunning()
                }
            }
            return true
        }

        // Make sure the AVAudioSession category is set.
        // DivineCameraPlugin.preWarmFrameworks() runs at plugin registration
        // and should already have done this; calling it again is cheap when warm.
        //
        // Propagate failure: if setCategory / setActive fails on the cold
        // path, the dedicated audio capture session would still be built
        // and started below, but with no working AVAudioSession the
        // captured buffers would be silent. Returning false here keeps
        // the new `audioReady` contract honest — the recording proceeds
        // without an audio track instead of producing a silent AAC track.
        let entrySession = AVAudioSession.sharedInstance()
        let entryRunning = self.audioCaptureSession?.isRunning ?? false
        self.lastAudioEntryRoute = "category=\(entrySession.category.rawValue)"
            + ",mode=\(entrySession.mode.rawValue),running=\(entryRunning)"
        self.lastAudioAttachPath = "build"
        if !configureAudioSessionForRecording() {
            return false
        }

        let session = self.audioCaptureSession ?? AVCaptureSession()
        session.automaticallyConfiguresApplicationAudioSession = false
        session.beginConfiguration()
        
        // Audio input
        if self.audioInput == nil {
            let device = self.audioDevice ?? AVCaptureDevice.default(for: .audio)
            guard let audioDevice = device else {
                DivineCameraLog.shared.warning(
                    "No audio device available — recording without audio",
                    name: "DivineCamera.Audio"
                )
                session.commitConfiguration()
                return false
            }
            self.audioDevice = audioDevice
            do {
                let input = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(input) {
                    session.addInput(input)
                    self.audioInput = input
                } else {
                    DivineCameraLog.shared.error(
                        "Cannot add audio input to audio session",
                        name: "DivineCamera.Audio"
                    )
                    session.commitConfiguration()
                    return false
                }
            } catch {
                DivineCameraLog.shared.error(
                    "Failed to create audio input: \(error.localizedDescription)",
                    name: "DivineCamera.Audio"
                )
                session.commitConfiguration()
                return false
            }
        }
        
        // Audio output
        if self.audioOutput == nil {
            let output = AVCaptureAudioDataOutput()
            output.setSampleBufferDelegate(self, queue: videoOutputQueue)
            if session.canAddOutput(output) {
                session.addOutput(output)
                self.audioOutput = output
            } else {
                DivineCameraLog.shared.error(
                    "Cannot add audio output to audio session",
                    name: "DivineCamera.Audio"
                )
                session.commitConfiguration()
                return false
            }
        }
        
        session.commitConfiguration()
        self.audioCaptureSession = session
        
        // Start the audio session. This does NOT touch the video session and
        // therefore does NOT cause a preview reconfiguration / black frame.
        if !session.isRunning {
            session.startRunning()
        }
        
        return true
    }
    
    /// Completes initialization when first frame is received or timeout occurs.
    /// This ensures Flutter is notified only when the camera is truly delivering frames.
    private func completeInitializationIfNeeded(timedOut: Bool = false) {
        // Cancel timeout timer
        initializationTimeoutTimer?.invalidate()
        initializationTimeoutTimer = nil
        
        // Only complete once
        guard let completion = initializationCompletion else { return }
        initializationCompletion = nil
        
        if timedOut {
            DivineCameraLog.shared.debug("DivineCamera: ⚠️ Initialization completed via timeout (frames may not be flowing)")
        } else {
            DivineCameraLog.shared.debug("DivineCamera: ✅ Initialization completed - first frame received")
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            var state = self.getCameraState()
            state["textureId"] = self.textureId
            DivineCameraLog.shared.debug("DivineCamera: Returning state with textureId: \(self.textureId)")
            completion(state, nil)
        }
        
        // Pre-build the dedicated audio capture session 1s after the first
        // frame. attachAudioToSessionIfNeeded() takes ~1.4s on older A9/A10
        // iPads (AVAudioSession.setCategory + AudioToolbox dlopen + the
        // synchronous startRunning() call); doing it lazily on the first
        // record tap is what was causing the recording-start lag.
        //
        // Why DEFERRED 1s after first frame and not in setupCamera() or
        // immediately on first frame: AudioToolbox dlopen + lazy symbol
        // binds on a background queue while Main is wiring up the camera
        // page reproduces the freeze fixed in PR #3219. By 1s after the
        // first frame, Main has finished page setup, the page-transition
        // animation is done, and the dyld notifications can no longer
        // block visible UI.
        //
        // Side effect: iOS shows the orange microphone indicator dot in
        // the status bar shortly after the camera page opens (TikTok,
        // Instagram, and Snapchat all behave the same way).
        sessionQueue.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            // Skip when the preview was paused before the pre-build fired
            // (locked / backgrounded within 1s of the first frame) —
            // attaching would grab the mic while the app isn't visible.
            // resumePreview() / startRecording() attach on demand instead.
            guard let self = self, !self.isPaused else { return }
            _ = self.attachAudioToSessionIfNeeded()
        }
    }
    
    /// Updates camera properties from the device.
    private func updateCameraProperties(device: AVCaptureDevice) {
        if autoLensSwitchRequested {
            // Determine scale factor for virtual multi-camera devices.
            // builtInTripleCamera and builtInDualWideCamera include ultra-wide
            // where native videoZoomFactor 1.0 = ultra-wide (0.5x in iOS Camera app)
            // and native 2.0 = wide angle (1.0x).
            if #available(iOS 13.0, *) {
                if device.deviceType == .builtInTripleCamera ||
                   device.deviceType == .builtInDualWideCamera {
                    nativeToUserZoomScale = 0.5
                } else {
                    nativeToUserZoomScale = 1.0
                }
            } else {
                nativeToUserZoomScale = 1.0
            }
            // Use full zoom range including ultra-wide on virtual
            // multi-camera devices (e.g. builtInTripleCamera).
            // Convert native zoom values to user-facing values.
            minZoom = device.minAvailableVideoZoomFactor * nativeToUserZoomScale
            // Use the full hardware zoom range (mirrors the stock camera).
            // Beyond the optical max this is digital zoom and gets soft.
            maxZoom = device.maxAvailableVideoZoomFactor * nativeToUserZoomScale
        } else {
            // No auto lens switch - clamp to 1.0 to prevent native
            // lens switching on virtual multi-camera devices.
            nativeToUserZoomScale = 1.0
            minZoom = 1.0
            // Use the live available max (mirrors the auto-lens branch and
            // setZoomLevel) rather than the static format max, so a runtime
            // restriction that lowers the ceiling isn't briefly over-advertised.
            maxZoom = device.maxAvailableVideoZoomFactor
        }
        currentZoom = device.videoZoomFactor * nativeToUserZoomScale
        // Front camera has "flash" via screen brightness when feature is enabled
        hasFlash = device.hasFlash || (screenFlashFeatureEnabled && currentLens == .front)
        isFocusPointSupported = device.isFocusPointOfInterestSupported
        isExposurePointSupported = device.isExposurePointOfInterestSupported
        
        // Calculate aspect ratio from the active format dimensions
        // This is the actual camera sensor output size
        let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        // dimensions.width is the longer side (landscape), height is shorter
        // For portrait mode, we swap to get 9:16 ratio
        aspectRatio = CGFloat(dimensions.height) / CGFloat(dimensions.width)
        DivineCameraLog.shared.debug("Camera aspect ratio (portrait): \(aspectRatio) from dimensions: \(dimensions.height)x\(dimensions.width)")
    }
    
    /// Switches to a different camera lens.
    func switchCamera(lens: String, completion: @escaping ([String: Any]?, String?) -> Void) {
        // Disable screen flash and auto-flash when switching cameras
        disableScreenFlash()
        disableAutoFlashTorch()
        isAutoFlashMode = false
        
        sessionQueue.async { [weak self] in
            guard let self = self, let session = self.captureSession else {
                completion(nil, "Session not available")
                return
            }
            
            // Update lens type and position
            self.currentLensType = lens
            self.currentLens = self.getPositionForLensType(lens)
            
            guard let newDevice = self.getDeviceForLensType(lens) else {
                completion(nil, "Lens \(lens) is not available on this device")
                return
            }
            
            session.beginConfiguration()
            
            // Remove old input
            if let oldInput = self.videoInput {
                session.removeInput(oldInput)
            }
            
            // Add new input
            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                
                // First try to add input with current preset
                if session.canAddInput(newInput) {
                    session.addInput(newInput)
                    self.videoInput = newInput
                    self.videoDevice = newDevice
                    self.updateCameraProperties(device: newDevice)
                } else {
                    // Current preset may not be supported by new camera (e.g., UHD on front camera)
                    // Try fallback presets
                    let fallbackPresets: [AVCaptureSession.Preset] = [
                        .hd4K3840x2160,
                        .hd1920x1080,
                        .hd1280x720,
                        .high,
                        .medium,
                        .low
                    ]
                    
                    var success = false
                    for preset in fallbackPresets {
                        if session.canSetSessionPreset(preset) {
                            session.sessionPreset = preset
                            if session.canAddInput(newInput) {
                                session.addInput(newInput)
                                self.videoInput = newInput
                                self.videoDevice = newDevice
                                self.updateCameraProperties(device: newDevice)
                                DivineCameraLog.shared.debug("[DivineCameraController] Camera switch: preset fallback to \(preset.rawValue)")
                                success = true
                                break
                            }
                        }
                    }
                    
                    if !success {
                        // Re-add old input if all fallbacks failed
                        if let oldInput = self.videoInput {
                            session.addInput(oldInput)
                        }
                        session.commitConfiguration()
                        completion(nil, "Cannot add video input for new camera")
                        return
                    }
                }
                
                // Update orientation and mirroring based on settings
                if let videoConnection = self.videoOutput?.connection(with: .video) {
                    if videoConnection.isVideoOrientationSupported {
                        videoConnection.videoOrientation = .portrait
                    }
                    // Mirror pixels for front camera when mirrorFrontCameraOutput is enabled
                    let isFront = newDevice.position == .front
                    if videoConnection.isVideoMirroringSupported {
                        videoConnection.isVideoMirrored = isFront && self.mirrorFrontCameraOutput
                    }
                }
                if let photoConnection = self.photoOutput?.connection(with: .video) {
                    if photoConnection.isVideoOrientationSupported {
                        photoConnection.videoOrientation = .portrait
                    }
                    let isFront = newDevice.position == .front
                    if photoConnection.isVideoMirroringSupported {
                        photoConnection.isVideoMirrored = isFront && self.mirrorFrontCameraOutput
                    }
                }
                if self.previewOptimizedActive,
                    let previewConnection = self.previewOutput?.connection(with: .video) {
                    if previewConnection.isVideoOrientationSupported {
                        previewConnection.videoOrientation = .portrait
                    }
                    let isFront = newDevice.position == .front
                    if previewConnection.isVideoMirroringSupported {
                        previewConnection.isVideoMirrored = isFront && self.mirrorFrontCameraOutput
                    }
                }
            } catch {
                // Re-add old input if failed
                if let oldInput = self.videoInput {
                    session.addInput(oldInput)
                }
                session.commitConfiguration()
                completion(nil, "Failed to switch camera: \(error.localizedDescription)")
                return
            }
            
            session.commitConfiguration()

            // The new device/format may support a different set of
            // stabilization modes, so re-apply the requested mode.
            self.applyVideoStabilization()

            // Set zoom to 1.0x (wide angle) for virtual multi-camera devices
            // after switching cameras, so it matches the Dart side expectation.
            if self.nativeToUserZoomScale < 1.0 {
                let nativeWideZoom = 1.0 / self.nativeToUserZoomScale
                do {
                    try newDevice.lockForConfiguration()
                    newDevice.videoZoomFactor = nativeWideZoom
                    newDevice.unlockForConfiguration()
                    self.currentZoom = 1.0
                } catch {
                    DivineCameraLog.shared.warning("DivineCamera: Failed to set zoom after camera switch: \(error.localizedDescription)", name: "DivineCamera.Setup")
                }
            }
            
            // Store completion to be called when first frame arrives from new camera.
            // This ensures Flutter gets the new lens state only after the texture
            // already shows a frame from the new camera, preventing mirror glitches.
            self.switchCameraCompletion = { [weak self] state, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    completion(self.getCameraState(), nil)
                }
            }
        }
    }
    
    /// Sets the flash mode.
    /// For front camera with torch mode, maximizes screen brightness instead.
    /// For "auto" mode, brightness will be checked once when recording starts.
    func setFlashMode(mode: String) -> Bool {
        guard let device = videoDevice else { return false }
        
        DivineCameraLog.shared.debug("DivineCamera: Setting flash mode: \(mode) (currentLens: \(currentLens == .front ? "front" : "back"))")
        
        // Handle screen brightness for front camera "torch" mode
        if currentLens == .front {
            if mode == "torch" {
                enableScreenFlash()
                currentTorchMode = .on
                isAutoFlashMode = false
                currentFlashMode = .off
                return true
            } else if mode == "auto" {
                // Auto mode for front camera - will check brightness when recording starts
                disableScreenFlash()
                currentTorchMode = .off
                isAutoFlashMode = true
                currentFlashMode = .auto
                DivineCameraLog.shared.debug("DivineCamera: Auto flash mode enabled for front camera")
                return true
            } else {
                disableScreenFlash()
                isAutoFlashMode = false
            }
        }
        
        do {
            try device.lockForConfiguration()
            
            switch mode {
            case "off":
                if device.isTorchModeSupported(.off) {
                    device.torchMode = .off
                }
                currentFlashMode = .off
                currentTorchMode = .off
                isAutoFlashMode = false
                autoFlashTorchEnabled = false
                
            case "auto":
                // Auto mode - will check brightness when recording starts
                if device.isTorchModeSupported(.off) {
                    device.torchMode = .off
                }
                currentTorchMode = .off
                isAutoFlashMode = true
                autoFlashTorchEnabled = false
                currentFlashMode = .auto
                DivineCameraLog.shared.debug("DivineCamera: Auto flash mode enabled - will check brightness when recording starts")
                
            case "on":
                if device.isTorchModeSupported(.off) {
                    device.torchMode = .off
                }
                currentFlashMode = .on
                currentTorchMode = .off
                isAutoFlashMode = false
                
            case "torch":
                if device.isTorchModeSupported(.on) {
                    device.torchMode = .on
                }
                currentTorchMode = .on
                currentFlashMode = .off
                isAutoFlashMode = false
                
            default:
                break
            }
            
            device.unlockForConfiguration()
            return true
        } catch {
            DivineCameraLog.shared.warning("DivineCamera: Failed to set flash mode: \(error.localizedDescription)", name: "DivineCamera.Flash")
            return false
        }
    }
    
    /// Enables screen flash by setting brightness to maximum (for front camera).
    private func enableScreenFlash() {
        guard screenFlashFeatureEnabled else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Save original brightness if not already saved
            if self.originalBrightness == nil {
                self.originalBrightness = UIScreen.main.brightness
            }
            // Set brightness to maximum (1.0 = 100%)
            UIScreen.main.brightness = 1.0
        }
    }
    
    /// Disables screen flash by restoring original brightness.
    private func disableScreenFlash() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let brightness = self.originalBrightness {
                UIScreen.main.brightness = brightness
                self.originalBrightness = nil
                DivineCameraLog.shared.debug("DivineCamera: Screen flash disabled (brightness restored)")
            }
        }
    }
    
    /// Checks if the current environment is dark based on camera exposure values.
    /// Uses ISO and exposure duration as indicators (same logic as Android).
    /// Front camera has lower thresholds since screen flash is less intrusive.
    private func isEnvironmentDark() -> Bool {
        guard let device = videoDevice else { return false }
        
        let isoThreshold = currentLens == .front ? frontCameraIsoThreshold : backCameraIsoThreshold
        let exposureThreshold = currentLens == .front ? frontCameraExposureThreshold : backCameraExposureThreshold
        
        let currentISO = device.iso
        let currentExposure = Float(CMTimeGetSeconds(device.exposureDuration))
        
        // If ISO is high OR exposure time is long, it's dark (same as Android)
        let isDark = currentISO >= isoThreshold || currentExposure >= exposureThreshold
        
        DivineCameraLog.shared.debug("DivineCamera: Auto flash: ISO=\(currentISO) (threshold=\(isoThreshold)), " +
              "ExposureTime=\(currentExposure * 1000)ms (threshold=\(exposureThreshold * 1000)ms) -> isDark=\(isDark)")
        return isDark
    }
    
    /// Checks the current exposure values and enables auto-flash if needed.
    /// Called when recording starts.
    private func checkAndEnableAutoFlash() {
        guard isAutoFlashMode else { return }
        
        if isEnvironmentDark() {
            DivineCameraLog.shared.debug("DivineCamera: Auto flash: Dark environment detected - enabling flash")
            enableAutoFlashTorch()
        } else {
            DivineCameraLog.shared.debug("DivineCamera: Auto flash: Bright environment - flash not needed")
        }
    }
    
    /// Enables torch/screen flash for auto flash mode.
    private func enableAutoFlashTorch() {
        if currentLens == .front {
            autoFlashTorchEnabled = true
            enableScreenFlash()
            DivineCameraLog.shared.debug("DivineCamera: Auto flash: Screen flash enabled for front camera")
        } else {
            guard let device = videoDevice else {
                DivineCameraLog.shared.debug("DivineCamera: Auto flash: No video device")
                return
            }
            guard device.hasTorch else {
                DivineCameraLog.shared.debug("DivineCamera: Auto flash: Device has no torch")
                return
            }
            do {
                try device.lockForConfiguration()
                if device.isTorchModeSupported(.on) {
                    device.torchMode = .on
                    autoFlashTorchEnabled = true
                    DivineCameraLog.shared.debug("DivineCamera: Auto flash: Torch enabled for back camera")
                } else {
                    DivineCameraLog.shared.debug("DivineCamera: Auto flash: Torch mode .on not supported")
                }
                device.unlockForConfiguration()
            } catch {
                DivineCameraLog.shared.warning("DivineCamera: Auto flash failed to enable torch: \(error.localizedDescription)", name: "DivineCamera.Flash")
            }
        }
    }
    
    /// Disables torch/screen flash if it was enabled by auto flash mode.
    /// Called when recording stops.
    private func disableAutoFlashTorch() {
        // Always try to turn off torch for back camera, regardless of autoFlashTorchEnabled state
        // This ensures torch doesn't stay on if state got out of sync
        if currentLens == .back {
            if let device = videoDevice, device.hasTorch {
                do {
                    try device.lockForConfiguration()
                    if device.torchMode != .off && device.isTorchModeSupported(.off) {
                        device.torchMode = .off
                        DivineCameraLog.shared.debug("DivineCamera: Auto flash: Torch disabled for back camera")
                    }
                    device.unlockForConfiguration()
                } catch {
                    DivineCameraLog.shared.warning("DivineCamera: Auto flash failed to disable torch: \(error.localizedDescription)", name: "DivineCamera.Flash")
                }
            }
        } else if autoFlashTorchEnabled {
            disableScreenFlash()
        }
        
        autoFlashTorchEnabled = false
    }
    
    /// Work item for auto-cancel focus timer
    private var focusAutoCancelWorkItem: DispatchWorkItem?
    
    /// Duration in seconds before focus returns to continuous auto-focus (like TikTok)
    private let focusLockDuration: TimeInterval = 3.0
    
    /// Sets the focus point in normalized coordinates (0.0-1.0).
    /// Uses combined focus + exposure + white balance for best results.
    /// Focus is locked for 3 seconds, then returns to continuous auto-focus.
    ///
    /// Note: Input coordinates are in display space (portrait mode).
    /// iOS focusPointOfInterest uses sensor coordinates (landscape),
    /// so we transform: display (x, y) → sensor (y, 1-x) for portrait mode.
    func setFocusPoint(x: CGFloat, y: CGFloat) -> Bool {
        guard let device = videoDevice, device.isFocusPointOfInterestSupported else {
            return false
        }
        
        // Cancel any pending auto-cancel timer from previous tap
        focusAutoCancelWorkItem?.cancel()
        
        // Transform display coordinates to sensor coordinates
        // iOS sensor coordinate system is always landscape-oriented:
        // - (0,0) is top-left of sensor (in landscape)
        // - For portrait mode, we need to rotate the coordinates
        // Display (x, y) → Sensor (y, 1-x) for portrait orientation
        let sensorPoint = CGPoint(x: y, y: 1 - x)
        
        do {
            try device.lockForConfiguration()
            
            // Set focus point and trigger one-shot auto-focus
            device.focusPointOfInterest = sensorPoint
            if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
            }
            
            // Also set exposure at the same point for consistent results
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = sensorPoint
                if device.isExposureModeSupported(.autoExpose) {
                    device.exposureMode = .autoExpose
                }
            }
            
            // Also trigger white balance adjustment (iOS doesn't have point of interest for WB,
            // but setting to auto mode will let it recalculate based on scene)
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            
            device.unlockForConfiguration()
            
            // Schedule return to continuous auto-focus after focusLockDuration
            let workItem = DispatchWorkItem { [weak self] in
                self?.returnToContinuousAutoFocus()
            }
            focusAutoCancelWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + focusLockDuration, execute: workItem)
            
            return true
        } catch {
            return false
        }
    }
    
    /// Returns focus, exposure, and white balance to continuous auto mode.
    private func returnToContinuousAutoFocus() {
        guard let device = videoDevice else { return }
        
        do {
            try device.lockForConfiguration()
            
            // Return to continuous auto-focus
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            
            // Return to continuous auto-exposure
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            // Ensure continuous auto white balance (should already be set, but ensure it)
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            
            device.unlockForConfiguration()
        } catch {
            // Silently fail
        }
    }
    
    /// Sets the exposure point in normalized coordinates (0.0-1.0).
    /// For exposure-only adjustment without changing focus.
    ///
    /// Note: Input coordinates are in display space (portrait mode).
    /// iOS exposurePointOfInterest uses sensor coordinates (landscape),
    /// so we transform: display (x, y) → sensor (y, 1-x) for portrait mode.
    func setExposurePoint(x: CGFloat, y: CGFloat) -> Bool {
        guard let device = videoDevice, device.isExposurePointOfInterestSupported else {
            return false
        }
        
        // Transform display coordinates to sensor coordinates
        let sensorPoint = CGPoint(x: y, y: 1 - x)
        
        do {
            try device.lockForConfiguration()
            device.exposurePointOfInterest = sensorPoint
            if device.isExposureModeSupported(.autoExpose) {
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
            return true
        } catch {
            return false
        }
    }
    
    /// Cancels any active focus/metering lock and returns to continuous auto-focus.
    /// Call this when you want to reset focus behavior after a tap-to-focus.
    func cancelFocusAndMetering() -> Bool {
        // Cancel any pending auto-cancel timer
        focusAutoCancelWorkItem?.cancel()
        focusAutoCancelWorkItem = nil
        
        guard let device = videoDevice else { return false }
        
        do {
            try device.lockForConfiguration()
            
            // Return to continuous auto-focus
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            
            // Return to continuous auto-exposure
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            device.unlockForConfiguration()
            return true
        } catch {
            return false
        }
    }
    
    /// Sets the zoom level (user-facing value, e.g. 0.5x, 1.0x, 2.0x).
    /// Internally converts to native videoZoomFactor using nativeToUserZoomScale.
    ///
    /// Clamps against the device's *current* min/maxAvailableVideoZoomFactor
    /// instead of the configure-time snapshot: on virtual devices iOS
    /// restricts these at runtime (e.g. while recording or with video
    /// stabilization active) and silently clamps out-of-range assignments
    /// rather than throwing. The factor is read back after the assignment so
    /// the returned zoom is what the camera actually applied, never the
    /// requested value.
    ///
    /// Returns the applied zoom plus the live available range as a map for
    /// the platform channel, or nil when the device rejected the change.
    func setZoomLevel(level: CGFloat) -> [String: Double]? {
        guard let device = videoDevice else { return nil }

        // Without auto lens switch the lower bound stays at 1.0 so the
        // native HAL never switches a virtual device to the ultra-wide,
        // mirroring updateCameraProperties.
        var liveMin = device.minAvailableVideoZoomFactor * nativeToUserZoomScale
        if !autoLensSwitchRequested {
            liveMin = max(liveMin, 1.0)
        }
        let liveMax = device.maxAvailableVideoZoomFactor * nativeToUserZoomScale

        let clampedLevel = max(liveMin, min(level, liveMax))
        // Convert user-facing zoom to native videoZoomFactor
        let nativeZoom = clampedLevel / nativeToUserZoomScale

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = nativeZoom
            device.unlockForConfiguration()
        } catch {
            return nil
        }

        currentZoom = device.videoZoomFactor * nativeToUserZoomScale
        // Keep the stored bounds in sync so getCameraState reports the same
        // range; refreshed on every set, so it heals when a restriction lifts.
        minZoom = liveMin
        maxZoom = liveMax
        return [
            "zoomLevel": Double(currentZoom),
            "minZoomLevel": Double(liveMin),
            "maxZoomLevel": Double(liveMax),
        ]
    }

    // MARK: - Video Stabilization

    /// Maps a cross-platform stabilization mode string to its
    /// `AVCaptureVideoStabilizationMode`. Returns nil for unknown strings.
    static func stabilizationMode(
        from string: String
    ) -> AVCaptureVideoStabilizationMode? {
        switch string {
        case "off":
            return .off
        case "standard":
            return .standard
        case "cinematic":
            return .cinematic
        case "cinematicExtended":
            if #available(iOS 13.0, *) {
                return .cinematicExtended
            }
            return .cinematic
        case "previewOptimized":
            if #available(iOS 17.0, *) {
                return .previewOptimized
            }
            return nil
        case "lowLatency":
            if #available(iOS 26.0, *) {
                return .lowLatency
            }
            return nil
        case "auto":
            return .auto
        default:
            return nil
        }
    }

    /// Maps an `AVCaptureVideoStabilizationMode` back to its cross-platform
    /// string. Used for reporting the active mode in the camera state.
    static func stabilizationString(
        from mode: AVCaptureVideoStabilizationMode
    ) -> String {
        switch mode {
        case .off:
            return "off"
        case .standard:
            return "standard"
        case .cinematic:
            return "cinematic"
        case .auto:
            return "auto"
        default:
            if #available(iOS 26.0, *), mode == .lowLatency {
                return "lowLatency"
            }
            if #available(iOS 17.0, *), mode == .previewOptimized {
                return "previewOptimized"
            }
            if #available(iOS 13.0, *), mode == .cinematicExtended {
                return "cinematicExtended"
            }
            return "off"
        }
    }

    private static func isPreviewOptimized(
        _ mode: AVCaptureVideoStabilizationMode
    ) -> Bool {
        if #available(iOS 17.0, *) {
            return mode == .previewOptimized
        }
        return false
    }

    /// Sets the requested video stabilization mode and applies it to the
    /// active video connection. Returns true if the mode was applied.
    func setVideoStabilizationMode(_ mode: String) -> Bool {
        guard let parsed = Self.stabilizationMode(from: mode) else {
            DivineCameraLog.shared.warning(
                "Unknown video stabilization mode: \(mode)",
                name: "DivineCamera.Stabilization"
            )
            return false
        }
        let previous = requestedStabilizationMode
        requestedStabilizationMode = parsed
        let applied = applyVideoStabilization()
        if !applied {
            requestedStabilizationMode = previous
            // Re-apply the restored mode to both connections so the preview
            // handoff matches the recording connection's actual state.
            applyVideoStabilization()
        }
        return applied
    }

    /// Builds the optional preview-optimized output and adds it to `session`.
    /// On success `previewOutput` is set and `previewOptimizedActive` becomes
    /// true; on any failure the controller silently keeps the single-output
    /// preview path (texture from `videoOutput`). Must run inside the session's
    /// begin/commit configuration block.
    private func setupPreviewOptimizedOutputIfPossible(
        session: AVCaptureSession
    ) {
        guard #available(iOS 17.0, *) else { return }

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        // Preview can drop late frames — they never reach the asset writer.
        output.alwaysDiscardsLateVideoFrames = true
        // Shares videoOutputQueue on purpose: one serial queue serializes both
        // outputs so the texture handoff (previewDrivesTexture) and the
        // switch-completion / pixel-buffer state stay race-free. A separate
        // queue would reintroduce those races for marginal throughput.
        output.setSampleBufferDelegate(self, queue: videoOutputQueue)

        guard session.canAddOutput(output) else {
            DivineCameraLog.shared.debug(
                "DivineCamera: Session rejected a second video data output; "
                    + "using single-output preview",
                name: "DivineCamera.Stabilization"
            )
            return
        }
        session.addOutput(output)

        // Preview-sized buffers are the eligibility requirement for
        // `.previewOptimized` on a data output, and are lighter for the
        // texture. These can only be set once the output joins the session.
        output.automaticallyConfiguresOutputBufferDimensions = false
        output.deliversPreviewSizedOutputBuffers = true

        guard let connection = output.connection(with: .video),
            connection.isVideoStabilizationSupported
        else {
            session.removeOutput(output)
            DivineCameraLog.shared.debug(
                "DivineCamera: Preview output has no stabilizable connection; "
                    + "using single-output preview",
                name: "DivineCamera.Stabilization"
            )
            return
        }
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        if connection.isVideoMirroringSupported {
            connection.isVideoMirrored =
                (currentLens == .front) && mirrorFrontCameraOutput
        }
        // Idle until the user turns stabilization on (see applyPreviewStabilization).
        connection.isEnabled = false

        self.previewOutput = output
        self.previewOptimizedActive = true
        DivineCameraLog.shared.debug(
            "DivineCamera: Preview-optimized output added",
            name: "DivineCamera.Stabilization"
        )
    }

    /// Applies the requested mode to the recording connection and keeps the
    /// preview-optimized output in sync. Returns true when the requested
    /// (recording) mode could be applied.
    @discardableResult
    private func applyVideoStabilization() -> Bool {
        let applied = applyRecordingStabilization()
        // Only hand the preview to the preview-optimized output when the
        // recording connection actually carries a non-off mode. A requested
        // mode that could not be applied (e.g. unsupported after a lens/format
        // switch) leaves the recording unstabilized, so the preview must stay
        // on the full-resolution output to keep preview and file in sync.
        applyPreviewStabilization(
            recordingStabilized: applied && requestedStabilizationMode != .off
        )
        return applied
    }

    /// Keeps `previewOutput`'s connection in sync with the recording
    /// connection: `.previewOptimized` while the recording is actually
    /// stabilized (a smooth live preview that doesn't zoom/jerk at record
    /// start), `.off` otherwise so the preview matches the unstabilized
    /// recording. `recordingStabilized` is true only when the requested mode
    /// was successfully applied to the recording connection — a rejected mode
    /// (e.g. unsupported after a lens/format switch) keeps the preview on the
    /// full-resolution output. Flips `previewDrivesTexture` so `captureOutput`
    /// routes the texture from the right output, and disables the connection
    /// while unused so no frames are spent on it.
    private func applyPreviewStabilization(recordingStabilized: Bool) {
        let previewConnection = previewOutput?.connection(with: .video)
        guard previewOptimizedActive,
            let connection = previewConnection,
            connection.isVideoStabilizationSupported
        else {
            // A camera that lost stabilization support (e.g. after a lens
            // switch) would otherwise keep this output delivering frames the
            // texture path immediately discards — disable it so no frames are
            // spent on it.
            previewConnection?.isEnabled = false
            previewDrivesTexture = false
            return
        }
        connection.isEnabled = recordingStabilized
        if #available(iOS 17.0, *) {
            connection.preferredVideoStabilizationMode =
                recordingStabilized ? .previewOptimized : .off
        }
        previewDrivesTexture = recordingStabilized
    }

    /// Applies `requestedStabilizationMode` to `videoOutput`'s connection — the
    /// frames written to the asset writer. Returns true when the requested mode
    /// could be applied (off is always considered applied).
    @discardableResult
    private func applyRecordingStabilization() -> Bool {
        guard let connection = videoOutput?.connection(with: .video) else {
            return requestedStabilizationMode == .off
        }
        guard connection.isVideoStabilizationSupported else {
            if requestedStabilizationMode != .off {
                DivineCameraLog.shared.warning(
                    "Video stabilization not supported on this connection",
                    name: "DivineCamera.Stabilization"
                )
            }
            return requestedStabilizationMode == .off
        }
        if Self.isPreviewOptimized(requestedStabilizationMode) {
            DivineCameraLog.shared.warning(
                "Preview optimized stabilization requires a preview layer or "
                    + "preview-sized AVCaptureVideoDataOutput; the recorder "
                    + "uses a full-resolution data output",
                name: "DivineCamera.Stabilization"
            )
            return false
        }
        // .auto lets AVFoundation pick a supported mode; for explicit modes
        // verify the active format actually supports the request.
        if requestedStabilizationMode != .off,
            requestedStabilizationMode != .auto,
            let device = videoDevice,
            !device.activeFormat.isVideoStabilizationModeSupported(
                requestedStabilizationMode
            )
        {
            DivineCameraLog.shared.warning(
                "Stabilization mode "
                    + "\(Self.stabilizationString(from: requestedStabilizationMode)) "
                    + "not supported by the active format",
                name: "DivineCamera.Stabilization"
            )
            return false
        }
        connection.preferredVideoStabilizationMode = requestedStabilizationMode
        DivineCameraLog.shared.debug(
            "Applied video stabilization mode: "
                + Self.stabilizationString(from: requestedStabilizationMode)
        )
        return true
    }

    /// Returns the stabilization modes the active device/format supports.
    private func getAvailableStabilizationModes() -> [String] {
        var modes: [String] = ["off"]
        guard
            let connection = videoOutput?.connection(with: .video),
            connection.isVideoStabilizationSupported,
            let device = videoDevice
        else {
            return modes
        }
        let format = device.activeFormat
        var candidates: [(AVCaptureVideoStabilizationMode, String)] = [
            (.standard, "standard"),
            (.cinematic, "cinematic"),
        ]
        if #available(iOS 13.0, *) {
            candidates.append((.cinematicExtended, "cinematicExtended"))
        }
        // previewOptimized is intentionally omitted for this recorder's
        // selectable modes: it stabilizes the live preview, not the recorded
        // file. It is applied internally to a dedicated preview-sized output
        // (see setupPreviewOptimizedOutputIfPossible) so the preview stays
        // smooth, while the recorded file uses the user-selected overscan mode
        // on the full-resolution output.
        if #available(iOS 26.0, *) {
            candidates.append((.lowLatency, "lowLatency"))
        }
        var probed: [String] = []
        for (mode, name) in candidates {
            let supported = format.isVideoStabilizationModeSupported(mode)
            probed.append("\(name)=\(supported)")
            if supported { modes.append(name) }
        }
        if modes.count > 1 {
            modes.append("auto")
        }
        DivineCameraLog.shared.debug(
            "Available stabilization modes: [\(modes.joined(separator: ", "))] "
                + "(probed \(probed.joined(separator: ", ")))",
            name: "DivineCamera.Stabilization"
        )
        return modes
    }

    /// The stabilization mode to surface in the camera state.
    ///
    /// For explicit modes we report the connection's actual
    /// `activeVideoStabilizationMode`, not the requested one, so a silent
    /// system fallback is reflected honestly — e.g. `previewOptimized`
    /// requested on the recorder's full-resolution data output resolves to a
    /// nearby mode. `auto` is reported verbatim because it expresses intent
    /// ("let the system pick") rather than a concrete target, and an idle
    /// session falls back to the requested value to avoid surfacing a
    /// transient `.off` before the connection has configured.
    private func reportedStabilizationString() -> String {
        guard requestedStabilizationMode != .auto,
            captureSession?.isRunning == true,
            let connection = videoOutput?.connection(with: .video),
            connection.isVideoStabilizationSupported
        else {
            return Self.stabilizationString(from: requestedStabilizationMode)
        }
        return Self.stabilizationString(
            from: connection.activeVideoStabilizationMode
        )
    }

    /// Starts video recording using AVAssetWriter.
    /// - Parameters:
    ///   - maxDurationMs: Optional maximum duration in milliseconds. Recording stops automatically when reached.
    ///   - useCache: If true, saves video to temporary directory. If false, saves to documents directory (permanent).
    ///   - outputDirectory: If provided, saves video to this directory (overrides useCache when false).
    ///   - completion: Callback with error message if failed, nil if successful.
    func startRecording(maxDurationMs: Int?, useCache: Bool = true, outputDirectory: String? = nil, completion: @escaping (String?) -> Void) {
        if isRecording {
            completion("Already recording")
            return
        }
        
        self.maxDurationMs = maxDurationMs
        let recordRequestedAt = Date()

        // Build and start the dedicated audio capture session on first record.
        // The audio session was pre-built in the background ~1s after the
        // first preview frame (see completeInitializationIfNeeded), so this
        // is normally a no-op. If the user taps record before the pre-build
        // completes, the work happens here on sessionQueue and the call
        // blocks for ~1.4s on older A9/A10 iPads — accepted as edge case.
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            // Note: there is a brief window between this recovery and the
            // first audioInput.append() call on videoOutputQueue. An
            // interruption arriving in that window produces a silent track
            // rather than no audio track. The captureOutput guard
            // (!audioInterrupted) limits the damage; full protection would
            // require a writer-level lock that is not worth the added
            // complexity here.
            self.recordRequestTime = recordRequestedAt
            let attachStart = Date()
            let audioAttached = self.attachAudioToSessionIfNeeded()
            self.lastAudioAttachMs = Date().timeIntervalSince(attachStart) * 1000
            self.recordingAudioAttachPath = self.lastAudioAttachPath
            self.recordingAudioEntryRoute = self.lastAudioEntryRoute
            if audioAttached && self.audioInterrupted {
                self.audioInterrupted = false
                DivineCameraLog.shared.info(
                    "Recovered audio session before recording; cleared stale interruption",
                    name: "DivineCamera.AudioSession"
                )
            }
            let audioReady = audioAttached && !self.audioInterrupted
            if !audioReady {
                DivineCameraLog.shared.warning(
                    "Audio not ready (attach failed or interrupted) — recording "
                        + "WITHOUT audio track",
                    name: "DivineCamera.Recording"
                )
            }

            // One state line per recording so a silent clip can be traced
            // to its cause: no input in the route, a system-level input
            // mute, or a category another player stole.
            let session = AVAudioSession.sharedInstance()
            let inputs = session.currentRoute.inputs
                .map(\.portType.rawValue).joined(separator: "+")
            let outputs = session.currentRoute.outputs
                .map(\.portType.rawValue).joined(separator: "+")
            var inputMuted = "n/a"
            if #available(iOS 17.0, *) {
                inputMuted = AVAudioApplication.shared.isInputMuted
                    ? "true" : "false"
            }
            DivineCameraLog.shared.info(
                "Recording audio state: ready=\(audioReady), "
                    + "category=\(session.category.rawValue), "
                    + "mode=\(session.mode.rawValue), "
                    + "inputs=[\(inputs)], outputs=[\(outputs)], "
                    + "inputMuted=\(inputMuted)",
                name: "DivineCamera.Recording"
            )

            self.videoOutputQueue.async { [weak self] in
                guard let self = self else { return }
                self.startRecordingAfterAudioReady(
                    audioReady: audioReady,
                    useCache: useCache,
                    outputDirectory: outputDirectory,
                    completion: completion
                )
            }
        }
    }
    
    /// Continues startRecording on the videoOutputQueue after audio has been
    /// attached to the session. Split out for readability.
    ///
    /// `audioReady` is the result of `attachAudioToSessionIfNeeded()`. When
    /// false (mic permission denied, AVAudioSession activation failed, or an
    /// active interruption is in progress) we skip adding the audio writer
    /// input entirely so the resulting MP4 has no audio track at all rather
    /// than a valid AAC track containing only digital silence.
    private func startRecordingAfterAudioReady(
        audioReady: Bool,
        useCache: Bool,
        outputDirectory: String?,
        completion: @escaping (String?) -> Void
    ) {
        // Create output file - use cache, provided directory, or default to documents directory
        let outputDir: URL
        if let customDir = outputDirectory {
            outputDir = URL(fileURLWithPath: customDir)
        } else if useCache {
            outputDir = FileManager.default.temporaryDirectory
        } else {
            let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            outputDir = paths[0]
        }
        // Use milliseconds timestamp for shorter, sortable, and unique filenames
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let outputURL = outputDir.appendingPathComponent("VID_\(timestamp).mp4")
        self.currentRecordingURL = outputURL

        // Remove existing file if any
        try? FileManager.default.removeItem(at: outputURL)

        // Setup AVAssetWriter
        do {
            let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

            // Get video dimensions from the current format
            guard let device = self.videoDevice else {
                DispatchQueue.main.async { completion("Video device not available") }
                return
            }

            let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
            // The video connection is set to .portrait orientation, so frames come in portrait
            // dimensions.width is the longer side (1920), dimensions.height is shorter (1080)
            // After portrait orientation, the frame is 1080 wide x 1920 tall
            let videoWidth = Int(dimensions.height)  // 1080 (portrait width)
            let videoHeight = Int(dimensions.width)  // 1920 (portrait height)

            // Video input settings
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: videoWidth,
                AVVideoHeightKey: videoHeight,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: self.videoEncodingBitRate,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                ],
            ]

            let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput.expectsMediaDataInRealTime = true

            // Create pixel buffer adaptor - use the actual frame dimensions (before portrait rotation)
            let sourcePixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: dimensions.height,  // Portrait width
                kCVPixelBufferHeightKey as String: dimensions.width,  // Portrait height
            ]
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoInput,
                sourcePixelBufferAttributes: sourcePixelBufferAttributes
            )

            if writer.canAdd(videoInput) {
                writer.add(videoInput)
            }

            // Only add an audio writer input when we know the audio capture
            // path is alive. Otherwise the writer would emit a valid AAC
            // track containing only digital silence — the exact bug we're
            // trying to prevent.
            var addedAudioInput: AVAssetWriterInput?
            if audioReady {
                let audioSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44100.0,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderBitRateKey: 64000,
                ]
                let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                audioInput.expectsMediaDataInRealTime = true
                if writer.canAdd(audioInput) {
                    writer.add(audioInput)
                    addedAudioInput = audioInput
                } else {
                    DivineCameraLog.shared.warning(
                        "writer.canAdd(audioInput)=false — recording without audio",
                        name: "DivineCamera.Recording"
                    )
                }
            }

            self.assetWriter = writer
            self.videoWriterInput = videoInput
            self.audioWriterInput = addedAudioInput
            self.pixelBufferAdaptor = adaptor

            // Start writing
            writer.startWriting()

            self.isRecording = true
            self.isWriterSessionStarted = false  // Will be set to true when first frame is received
            self.lastVideoFrameEndPTS = nil
            self.writerAnchorPTS = nil
            self.writerSessionStartedAt = nil
            self.firstAppendedAudioPTS = nil
            self.firstSeenAudioPTS = nil
            self.audioClockOffset = nil
            self.recordingStartTime = Date()
            self.appendedAudioBufferCount = 0
            self.maxAudioPeakDb = -160

            // Check and enable auto-flash if needed
            self.checkAndEnableAutoFlash()

            DivineCameraLog.shared.info(
                "Recording started (audioTrack=\(addedAudioInput != nil))",
                name: "DivineCamera.Recording"
            )

            // Schedule max duration timer if specified
            if let maxMs = self.maxDurationMs, maxMs > 0 {
                DispatchQueue.main.async { [weak self] in
                    self?.maxDurationTimer = Timer.scheduledTimer(withTimeInterval: Double(maxMs) / 1000.0, repeats: false) { [weak self] _ in
                        self?.autoStopRecording()
                    }
                }
            }

            DispatchQueue.main.async {
                completion(nil)
            }

        } catch {
            DispatchQueue.main.async {
                completion("Failed to create asset writer: \(error.localizedDescription)")
            }
        }
    }
    
    /// Automatically stops recording when max duration is reached.
    private func autoStopRecording() {
        guard isRecording else { return }

        // Native-only entry (max-duration timer, no method call): reclaim the
        // UI engine's diagnostics sink so the downstream recording-finalization
        // breadcrumbs — including the #4779 "WITHOUT audio track" warning — are
        // forwarded to the UI isolate. The sink is a process-wide singleton, so
        // reclaiming here holds through the async finishWriting completion.
        reclaimLogSink?()

        maxDurationTimer?.invalidate()
        maxDurationTimer = nil
        
        stopRecording { [weak self] result, error in
            // Send auto-stop event through method channel
            if let result = result {
                self?.sendAutoStopEvent(result: result)
            }
        }
    }
    
    /// Sends auto-stop event to Flutter.
    private func sendAutoStopEvent(result: [String: Any]) {
        // This will be handled by the plugin via a callback or event channel
        NotificationCenter.default.post(
            name: NSNotification.Name("DivineCameraAutoStop"),
            object: nil,
            userInfo: result
        )
    }
    
    /// Stops video recording and returns the result.
    func stopRecording(completion: @escaping ([String: Any]?, String?) -> Void) {
        guard isRecording, let writer = assetWriter else {
            completion(nil, "Not recording")
            return
        }
        
        // Cancel max duration timer if running
        maxDurationTimer?.invalidate()
        maxDurationTimer = nil
        
        // Disable auto-flash torch if it was enabled
        disableAutoFlashTorch()
        
        isRecording = false
        
        videoOutputQueue.async { [weak self] in
            guard let self = self else { return }

            // Bound the session to the last video frame. With a look-ahead
            // stabilization mode the trailing ~0.5–1s of video never reaches
            // the writer, so audio would otherwise outlast video and the clip
            // would end on a held (frozen) frame. Ending here trims that
            // surplus audio so both tracks stop together.
            if writer.status == .writing,
                self.isWriterSessionStarted,
                let endPTS = self.lastVideoFrameEndPTS {
                writer.endSession(atSourceTime: endPTS)
            }

            self.videoWriterInput?.markAsFinished()
            self.audioWriterInput?.markAsFinished()

            writer.finishWriting { [weak self] in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if writer.status == .completed {
                        // Get video dimensions
                        guard let outputURL = self.currentRecordingURL else {
                            completion(nil, "Output URL not available")
                            return
                        }

                        var width: Int = 1920
                        var height: Int = 1080

                        let asset = AVAsset(url: outputURL)
                        if let track = asset.tracks(withMediaType: .video).first {
                            let size = track.naturalSize.applying(track.preferredTransform)
                            width = Int(abs(size.width))
                            height = Int(abs(size.height))
                        }

                        // Report the finished file's real duration. The
                        // wall-clock span over-reports for look-ahead
                        // stabilization (the trailing video never reaches the
                        // writer), which would make a player hold the last
                        // frame. Fall back to wall clock only if the asset
                        // duration is unavailable.
                        let assetSeconds = CMTimeGetSeconds(asset.duration)
                        let duration: Int
                        if assetSeconds.isFinite, assetSeconds > 0 {
                            duration = Int(assetSeconds * 1000)
                        } else if let startTime = self.recordingStartTime {
                            duration = Int(Date().timeIntervalSince(startTime) * 1000)
                        } else {
                            duration = 0
                        }

                        // Definitive signal for the "clip saved without sound"
                        // reports (#4779): inspect the finished file rather than
                        // trusting the in-flight audioReady flag.
                        let hasAudioTrack = !asset.tracks(withMediaType: .audio).isEmpty
                        let audioStats = "audioBuffers=\(self.appendedAudioBufferCount), "
                            + "maxPeakDb=\(String(format: "%.1f", self.maxAudioPeakDb))"

                        self.logAudioAlignmentDiagnostics(asset: asset)
                        if hasAudioTrack {
                            DivineCameraLog.shared.info(
                                "Recording completed with audio track (durationMs=\(duration), \(audioStats))",
                                name: "DivineCamera.Recording"
                            )
                        } else {
                            DivineCameraLog.shared.warning(
                                "Recording completed WITHOUT audio track (durationMs=\(duration), \(audioStats))",
                                name: "DivineCamera.Recording"
                            )
                        }

                        let result: [String: Any] = [
                            "filePath": outputURL.path,
                            "durationMs": duration,
                            "width": width,
                            "height": height
                        ]

                        completion(result, nil)
                    } else {
                        DivineCameraLog.shared.error(
                            "Recording failed: "
                                + "\(writer.error?.localizedDescription ?? "Unknown error")",
                            name: "DivineCamera.Recording"
                        )
                        completion(nil, "Recording failed: \(writer.error?.localizedDescription ?? "Unknown error")")
                    }
                    
                    // Cleanup
                    self.assetWriter = nil
                    self.videoWriterInput = nil
                    self.audioWriterInput = nil
                    self.pixelBufferAdaptor = nil
                    self.currentRecordingURL = nil
                    self.recordingStartTime = nil
                    self.isWriterSessionStarted = false
                    self.lastVideoFrameEndPTS = nil

                    // pausePreview() keeps the mic attached while a
                    // recording is draining. If the preview is still
                    // paused now (app locked mid-recording), release the
                    // mic so the lock screen stops showing the recording
                    // indicator.
                    if self.isPaused {
                        self.sessionQueue.async { [weak self] in
                            guard let self = self,
                                  self.isPaused,
                                  !self.isRecording else { return }
                            self.releaseAudioForPause()
                        }
                    }
                }
            }
        }
    }

    /// Releases the microphone while the preview is paused.
    ///
    /// The dedicated audio capture session normally keeps running between
    /// recordings so record-start stays instant, but holding it across an
    /// app pause leaves the app owning the mic — iOS surfaces that as a
    /// recording indicator on the lock screen. Stop the capture session
    /// BEFORE deactivating the shared AVAudioSession; the reverse order
    /// leaves a stale route delivering digital-silence buffers (see
    /// attachAudioToSessionIfNeeded()).
    ///
    /// Must run on `sessionQueue`.
    private func releaseAudioForPause() {
        audioCaptureSession?.stopRunning()
        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        } catch {
            // A failing deactivation (session busy / insufficient priority) is
            // exactly the "mic not released" symptom this path guards against,
            // so surface it instead of swallowing. stopRunning() above is the
            // primary indicator-clearer, so this stays a warning.
            DivineCameraLog.shared.warning(
                "Failed to deactivate audio session on pause — mic may stay "
                    + "held (error=\(error.localizedDescription))",
                name: "DivineCamera.AudioSession"
            )
        }
        DivineCameraLog.shared.info(
            "Released mic for pause (audio capture stopped, session inactive)",
            name: "DivineCamera.AudioSession"
        )
    }

    /// Pauses the camera preview.
    ///
    /// Pass `releaseAudio: false` for transient foreground interruptions
    /// (iOS `.inactive` from a Control Center / app-switcher pull) to stop
    /// only the video session and leave the shared audio session running —
    /// releasing it there would signal other apps to resume and then re-cut
    /// their playback on every pull. `releaseAudio: true` (genuine
    /// background) additionally frees the mic so the lock screen stops
    /// showing the recording indicator.
    func pausePreview(releaseAudio: Bool = true) {
        disableScreenFlash()
        isPaused = true
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession?.stopRunning()
            // Keep the mic during an active recording — the writer is
            // still draining; stopRecording() releases it if the preview
            // is still paused once the file is finalized.
            if releaseAudio, !self.isRecording {
                self.releaseAudioForPause()
            }
        }
    }
    
    /// Resumes the camera preview.
    func resumePreview(completion: @escaping ([String: Any]?, String?) -> Void) {
        isPaused = false
        
        // Re-enable screen flash if front camera torch mode was active
        if currentLens == .front && currentTorchMode == .on {
            enableScreenFlash()
        }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession?.startRunning()

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                completion(self.getCameraState(), nil)
            }

            // Restore the audio path released by releaseAudioForPause().
            // A successful attach proves the path is live again, so also
            // clear a stale interruption flag — iOS delivers no `.ended`
            // for lock-screen interruptions, and a stuck flag would drop
            // the audio track from every later recording in this session.
            // Skip the never-built case (paused before the pre-build
            // fired); startRecording() builds on demand.
            if self.audioCaptureSession != nil, self.attachAudioToSessionIfNeeded() {
                self.audioInterrupted = false
            }
        }
    }
    
    /// Gets the current camera state as a dictionary.
    func getCameraState() -> [String: Any] {
        let availableStabilizationModes = getAvailableStabilizationModes()
        return [
            "isInitialized": captureSession != nil,
            "isRecording": isRecording,
            "flashMode": getFlashModeString(),
            "lens": currentLensType,
            "zoomLevel": Double(currentZoom),
            "minZoomLevel": Double(minZoom),
            "maxZoomLevel": Double(maxZoom),
            "aspectRatio": Double(aspectRatio),
            "hasFlash": hasFlash,
            "hasFrontCamera": hasFrontCamera,
            "hasBackCamera": hasBackCamera,
            "isFocusPointSupported": isFocusPointSupported,
            "isExposurePointSupported": isExposurePointSupported,
            "textureId": textureId,
            "availableLenses": getAvailableLenses(),
            "currentLensMetadata": getCurrentLensMetadata() as Any,
            "videoStabilizationMode": reportedStabilizationString(),
            "availableVideoStabilizationModes": availableStabilizationModes,
            // Mirror Android: "supported" means the active format offers at
            // least one mode beyond "off", so the UI affordance matches the
            // modes the menu can actually present (a connection can report
            // support while the active format exposes no concrete mode).
            "isVideoStabilizationSupported": availableStabilizationModes.count > 1,
        ]
    }

    /// Gets the current flash mode as a string.
    private func getFlashModeString() -> String {
        if currentTorchMode == .on {
            return "torch"
        }
        switch currentFlashMode {
        case .off:
            return "off"
        case .auto:
            return "auto"
        case .on:
            return "on"
        @unknown default:
            return "off"
        }
    }

    /// Emits the #7888 audio-alignment breadcrumb for a finished recording:
    /// how far the first encoded audio sample sits behind the writer anchor,
    /// how much of that gap predates any mic buffer at all, how far the audio
    /// session's clock sat from the video session's, and which audio attach
    /// path this recording took.
    private func logAudioAlignmentDiagnostics(asset: AVAsset) {
        func ms(_ later: CMTime?, _ earlier: CMTime?) -> String {
            guard let later, let earlier,
                  later.isNumeric, earlier.isNumeric else { return "n/a" }
            return String(format: "%.0f", (later - earlier).seconds * 1000)
        }
        let clockOffsetMs = ms(self.audioClockOffset, .zero)

        var startDelayMs = "n/a"
        if let requested = self.recordRequestTime, let anchored = self.writerSessionStartedAt {
            startDelayMs = String(format: "%.0f", anchored.timeIntervalSince(requested) * 1000)
        }

        var trackStartMs = "n/a"
        if let audioTrack = asset.tracks(withMediaType: .audio).first {
            let start = audioTrack.timeRange.start
            if start.isNumeric {
                trackStartMs = String(format: "%.0f", start.seconds * 1000)
            }
        }

        DivineCameraLog.shared.info(
            "Audio alignment: appendLeadInMs=\(ms(self.firstAppendedAudioPTS, self.writerAnchorPTS)), "
                + "micLeadInMs=\(ms(self.firstSeenAudioPTS, self.writerAnchorPTS)), "
                + "clockOffsetMs=\(clockOffsetMs), "
                + "audioTrackStartMs=\(trackStartMs), "
                + "tapToCaptureMs=\(startDelayMs), "
                + "attachMs=\(String(format: "%.0f", self.lastAudioAttachMs)), "
                + "attachPath=\(self.recordingAudioAttachPath), "
                + "entry=[\(self.recordingAudioEntryRoute)], "
                + "stabilization=\(self.reportedStabilizationString())",
            name: "DivineCamera.Recording"
        )
    }

    private func photoFlashMode(for output: AVCapturePhotoOutput) -> AVCaptureDevice.FlashMode {
        let requestedMode = currentFlashMode
        let supportedModes = output.supportedFlashModes
        if supportedModes.contains(requestedMode) {
            return requestedMode
        }
        return .off
    }

    /// Releases all camera resources.
    ///
    /// `completion` fires on the main queue once the teardown has actually
    /// run on `sessionQueue`. The recorder -> editor handoff needs that
    /// signal: it switches the shared AVAudioSession to `.playback` right
    /// after disposing the camera, and iOS rejects that `setCategory` with
    /// `InsufficientPriority` (OSStatus 561017449) while an audio capture
    /// session is still running. The editor then plays the clip back through
    /// the recorder's `.playAndRecord` capture configuration.
    func release(completion: (() -> Void)? = nil) {
        // Restore screen brightness if screen flash was enabled
        disableScreenFlash()
        // Disable auto-flash if it was enabled
        disableAutoFlashTorch()
        
        // Cancel any pending initialization
        initializationTimeoutTimer?.invalidate()
        initializationTimeoutTimer = nil
        initializationCompletion = nil
        
        // Strong capture on purpose: a `guard let self else { return }` here
        // would drop `completion` and hang the caller awaiting the teardown.
        sessionQueue.async {
            // Stop recording if in progress
            if self.isRecording {
                self.isRecording = false
                self.videoWriterInput?.markAsFinished()
                self.audioWriterInput?.markAsFinished()
                self.assetWriter?.cancelWriting()
            }
            
            self.captureSession?.stopRunning()
            self.captureSession = nil
            self.audioCaptureSession?.stopRunning()
            self.audioCaptureSession = nil
            self.videoDevice = nil
            self.audioDevice = nil
            self.videoInput = nil
            self.audioInput = nil
            self.videoOutput = nil
            self.audioOutput = nil
            self.previewOutput = nil
            self.previewOptimizedActive = false
            self.previewDrivesTexture = false

            // Cleanup asset writer if recording
            self.assetWriter = nil
            self.videoWriterInput = nil
            self.audioWriterInput = nil
            self.pixelBufferAdaptor = nil
            self.lastVideoFrameEndPTS = nil

            if self.textureId >= 0 {
                self.textureRegistry.unregisterTexture(self.textureId)
                self.textureId = -1
            }
            
            // Thread-safe release of the sample buffer (which also releases the pixel buffer)
            self.pixelBufferLock.lock()
            self.latestSampleBuffer = nil
            self.pixelBufferRef = nil
            self.pixelBufferLock.unlock()

            if let completion {
                DispatchQueue.main.async(execute: completion)
            }
        }
    }
}

// MARK: - FlutterTexture

extension CameraController: FlutterTexture {
    /// Captures a single still photo and writes it to disk as JPEG.
    ///
    /// Completion is invoked with a result map (`filePath`, `width`, `height`)
    /// on success, or nil plus an error message on failure. Rejected while a
    /// video recording is in progress.
    func capturePhoto(
        outputDirectory: String?,
        useCache: Bool,
        completion: @escaping ([String: Any]?, String?) -> Void
    ) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard let photoOutput = self.photoOutput else {
                completion(nil, "Photo output not available")
                return
            }
            guard !self.isRecording else {
                completion(nil, "Cannot capture photo while recording")
                return
            }

            let settings = AVCapturePhotoSettings(
                format: [AVVideoCodecKey: AVVideoCodecType.jpeg]
            )
            settings.flashMode = self.photoFlashMode(for: photoOutput)

            let delegate = PhotoCaptureDelegate(
                outputDirectory: outputDirectory,
                useCache: useCache
            )
            delegate.onFinished = { [weak self, weak delegate] map, error in
                completion(map, error)
                guard let self = self, let delegate = delegate else { return }
                self.sessionQueue.async {
                    self.activePhotoDelegates.removeAll { $0 === delegate }
                }
            }
            self.activePhotoDelegates.append(delegate)
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        pixelBufferLock.lock()
        defer { pixelBufferLock.unlock() }
        
        guard let pixelBuffer = pixelBufferRef else {
            // Per-frame on cold start; console only to avoid flooding the log buffer.
            print("DivineCamera: copyPixelBuffer called but pixelBufferRef is nil")
            return nil
        }
        return Unmanaged.passRetained(pixelBuffer)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !isPaused else { return }

        // Handle video output
        if output == videoOutput {
            // Get pixel buffer from sample buffer
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                // Per-frame on failure; console only to avoid flooding the log buffer.
                print("DivineCamera: Could not get pixel buffer from sample buffer")
                return
            }

            // The preview texture is driven by previewOutput while the
            // preview-optimized path is engaged; otherwise videoOutput drives it.
            if !previewDrivesTexture {
                updatePreviewTexture(pixelBuffer: pixelBuffer, sampleBuffer: sampleBuffer)
            }

            // Write video frame to asset writer if recording
            if isRecording, let writer = assetWriter, let videoInput = videoWriterInput, let adaptor = pixelBufferAdaptor {
                let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

                // Start session on first frame
                if !isWriterSessionStarted && writer.status == .writing {
                    writer.startSession(atSourceTime: timestamp)
                    isWriterSessionStarted = true
                    writerAnchorPTS = timestamp
                    writerSessionStartedAt = Date()
                    // Native-only event (sample-buffer delegate, no method
                    // call): reclaim the UI engine's diagnostics sink first.
                    reclaimLogSink?()
                    DivineCameraLog.shared.debug("DivineCamera: Writer session started at \(timestamp.seconds)")
                }

                if writer.status == .writing && videoInput.isReadyForMoreMediaData {
                    adaptor.append(pixelBuffer, withPresentationTime: timestamp)
                    // Track the frame's END, not its start, so endSession keeps
                    // the last frame's full duration. Capture buffers usually
                    // carry a valid duration; fall back to ~30fps if not.
                    let frameDuration = CMSampleBufferGetDuration(sampleBuffer)
                    let endDuration =
                        frameDuration.isNumeric && frameDuration.seconds > 0
                            ? frameDuration
                            : CMTime(value: 1, timescale: 30)
                    lastVideoFrameEndPTS = timestamp + endDuration
                }
            }
        }
        // Preview-optimized output drives the texture only while engaged.
        else if output == previewOutput {
            guard previewDrivesTexture,
                let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            else { return }
            updatePreviewTexture(pixelBuffer: pixelBuffer, sampleBuffer: sampleBuffer)
        }
        // Handle audio output
        else if output == audioOutput {
            // The audio session stamps its buffers on its own clock, not on
            // the one the writer was anchored with. Move them over first so
            // every comparison and append below shares the video timeline.
            let sampleBuffer = retimedToVideoClock(sampleBuffer)
            // Note the mic's first buffer ahead of every gate below. Inside
            // them a recording that never got an audio writer input, one
            // dropped by an interruption, and one whose mic delivered nothing
            // all log micLeadInMs=n/a — and telling those apart is the whole
            // point of the field.
            if isRecording, firstSeenAudioPTS == nil {
                firstSeenAudioPTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            }
            // Skip appending while interrupted — iOS keeps delivering
            // (silent) buffers after the session is deactivated, which
            // would produce a valid AAC track with no sound.
            if isRecording, !audioInterrupted, let writer = assetWriter, let audioInput = audioWriterInput {
                // Only append audio after session has started
                if isWriterSessionStarted && writer.status == .writing && audioInput.isReadyForMoreMediaData {
                    audioInput.append(sampleBuffer)
                    if firstAppendedAudioPTS == nil {
                        firstAppendedAudioPTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    }
                    appendedAudioBufferCount += 1
                    for channel in connection.audioChannels {
                        maxAudioPeakDb = max(maxAudioPeakDb, channel.peakHoldLevel)
                    }
                }
            }
        }
    }

    /// The clock a capture session stamps its output buffers on.
    private func synchronizationClock(of session: AVCaptureSession?) -> CMClock? {
        guard let session else { return nil }
        if #available(iOS 15.4, *) {
            return session.synchronizationClock
        }
        return session.masterClock
    }

    /// Re-stamps an audio buffer from the audio capture session's clock onto
    /// the video capture session's clock.
    ///
    /// "All capture output sample buffer timestamps are on the
    /// synchronizationClock timebase" (AVCaptureSession.h) — per session. A
    /// video-only session runs on the host clock; an audio-only session runs
    /// on an audio clock, which "may drift from CMClockGetHostTimeClock()"
    /// (CMAudioClock.h). The writer session is opened with a video PTS, so an
    /// audio PTS handed over unconverted lands wherever the audio clock
    /// happens to sit: on an M4 iPad within ~60ms, on a field iPhone 0.9–1.8s
    /// early, which the writer edits out at the head and repays as silence at
    /// the tail (#7888). `CMSyncConvertTime` is the conversion AVFoundation
    /// itself documents for exactly this.
    ///
    /// Returns the buffer unchanged while not recording (nothing downstream
    /// reads it then, and the audio session runs between recordings), when
    /// both sessions share a clock, or when the copy fails; the data buffer
    /// is shared, only the timing is replaced. Runs on `videoOutputQueue`.
    private func retimedToVideoClock(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer {
        guard isRecording,
              let audioClock = synchronizationClock(of: audioCaptureSession),
              let videoClock = synchronizationClock(of: captureSession) else {
            return sampleBuffer
        }
        if audioClock == videoClock {
            if audioClockOffset == nil {
                audioClockOffset = .zero
            }
            return sampleBuffer
        }

        var timing = CMSampleTimingInfo()
        guard CMSampleBufferGetSampleTimingInfo(
            sampleBuffer, at: 0, timingInfoOut: &timing) == noErr,
            timing.presentationTimeStamp.isNumeric else {
            return sampleBuffer
        }

        let rawPTS = timing.presentationTimeStamp
        let convertedPTS = CMSyncConvertTime(rawPTS, from: audioClock, to: videoClock)
        if audioClockOffset == nil {
            audioClockOffset = convertedPTS - rawPTS
        }
        timing.presentationTimeStamp = convertedPTS
        if timing.decodeTimeStamp.isNumeric {
            timing.decodeTimeStamp = CMSyncConvertTime(
                timing.decodeTimeStamp, from: audioClock, to: videoClock)
        }

        // One timing entry covers the whole buffer: `duration` is the
        // per-sample duration and the PTS names the first sample.
        var retimed: CMSampleBuffer?
        let status = CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: sampleBuffer,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleBufferOut: &retimed
        )
        guard status == noErr, let retimed else {
            return sampleBuffer
        }
        return retimed
    }

    /// Publishes a freshly captured frame to the Flutter texture and handles
    /// first-frame initialization and pending camera-switch completion. Called
    /// from whichever output currently drives the preview — `previewOutput`
    /// while the preview-optimized path is engaged, otherwise `videoOutput`.
    private func updatePreviewTexture(
        pixelBuffer: CVPixelBuffer,
        sampleBuffer: CMSampleBuffer
    ) {
        // Thread-safe update of the pixel buffer for preview
        pixelBufferLock.lock()
        let isFirstFrame = latestSampleBuffer == nil
        latestSampleBuffer = sampleBuffer
        pixelBufferRef = pixelBuffer
        pixelBufferLock.unlock()

        if isFirstFrame {
            // Native-only event (sample-buffer delegate, no method call):
            // reclaim the UI engine's diagnostics sink first.
            reclaimLogSink?()
            DivineCameraLog.shared.debug("DivineCamera: First frame received! Pixel buffer dimensions: \(CVPixelBufferGetWidth(pixelBuffer))x\(CVPixelBufferGetHeight(pixelBuffer))")

            // Complete initialization now that we know frames are flowing
            DispatchQueue.main.async { [weak self] in
                self?.completeInitializationIfNeeded(timedOut: false)
            }
        }

        // Notify Flutter on main thread that a new frame is available
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.textureId >= 0 else { return }
            self.textureRegistry.textureFrameAvailable(self.textureId)
        }

        // Complete camera switch if waiting for first frame from new camera.
        // This is done AFTER textureFrameAvailable so Flutter shows the new frame
        // before receiving the state update with the new lens.
        if let switchCompletion = switchCameraCompletion {
            switchCameraCompletion = nil
            let state = getCameraState()
            switchCompletion(state, nil)
        }
    }
}

// MARK: - AVCaptureAudioDataOutputSampleBufferDelegate

extension CameraController: AVCaptureAudioDataOutputSampleBufferDelegate {
    // Audio samples are handled in the captureOutput method above
}
