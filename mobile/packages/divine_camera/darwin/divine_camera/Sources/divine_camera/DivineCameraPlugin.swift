// ABOUTME: Main Flutter plugin entry point for iOS and macOS camera operations
// ABOUTME: Handles method channel communication and delegates to CameraController

import AVFoundation
#if os(iOS)
import Flutter
import UIKit
#elseif os(macOS)
import FlutterMacOS
#endif

public class DivineCameraPlugin: NSObject, FlutterPlugin {
    private var cameraController: CameraController?
    private var textureRegistry: FlutterTextureRegistry?
    private var messenger: FlutterBinaryMessenger?
    private var methodChannel: FlutterMethodChannel?
    #if os(iOS)
    private var volumeKeyHandler: VolumeKeyHandler?
    #endif

    public static func register(with registrar: FlutterPluginRegistrar) {
        #if os(iOS)
        let messenger = registrar.messenger()
        let textures = registrar.textures()
        #else
        let messenger = registrar.messenger
        let textures = registrar.textures
        #endif
        let channel = FlutterMethodChannel(name: "divine_camera", binaryMessenger: messenger)
        let instance = DivineCameraPlugin()
        instance.textureRegistry = textures
        instance.messenger = messenger
        instance.methodChannel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)

        // Forward curated native diagnostics to Dart's UnifiedLogger so
        // recording issues (e.g. missing audio) land in user bug reports.
        instance.installLogSink()

        // Listen for auto-stop events from CameraController
        NotificationCenter.default.addObserver(
            instance,
            selector: #selector(instance.handleAutoStop(_:)),
            name: NSNotification.Name("DivineCameraAutoStop"),
            object: nil
        )

        // Pre-warm the AV media stack on a background queue at plugin
        // registration (very early in app launch, before the user can reach
        // the camera page).
        //
        // Why here and not in CameraController.setupCamera(): doing dlopen()
        // on a background queue WHILE Main is wiring up the camera page
        // causes dyld to post process-wide image-load notifications that
        // block Main on its next lazy symbol bind. That was the source of
        // the ~1s freeze on first camera open.
        //
        // Doing the pre-warm here, far away from camera open, gives dyld
        // and mediaserverd time to settle. By the time the user reaches
        // the camera, AudioToolbox + VideoToolbox are loaded and Main is
        // not blocked.
        preWarmFrameworks()
    }

    /// Loads AudioToolbox + VideoToolbox + the AVAudioSession machinery off
    /// the main thread at plugin registration. Idempotent — safe to call
    /// once per process.
    private static func preWarmFrameworks() {
        DispatchQueue.global(qos: .utility).async {
            #if os(iOS)
            // 1. AudioToolbox + AVAudioSession + mediaserverd XPC roundtrip.
            let audioSession = AVAudioSession.sharedInstance()
            do {
                // Warm the mode the real recording path defaults to
                // (CameraController.configureAudioSessionForRecording).
                // Pre-warming a mode we don't record in leaves the warmed
                // route mismatched, so the first recording still pays the
                // mode-switch cost and the warmed behaviour drifts from the
                // real one. This runs at plugin registration, long before
                // Dart can report the user's unprocessed-audio preference
                // (#7796), so it can only warm the default. Music mode then
                // switches the session once, from the deferred audio
                // pre-build a second after the first preview frame — not
                // from the record tap, which is what that pre-build exists
                // to keep clear.
                try audioSession.setCategory(
                    .playAndRecord,
                    mode: .videoRecording,
                    options: [.defaultToSpeaker, .allowBluetoothA2DP]
                )
                // Do NOT call setActive(true) — that would steal audio focus
                // from anything currently playing. setCategory alone triggers
                // the dlopen.
                DivineCameraLog.shared.debug("AVAudioSession category configured (pre-warm)", name: "DivineCamera.Prewarm")
            } catch {
                DivineCameraLog.shared.warning("AVAudioSession pre-warm config failed: \(error.localizedDescription)", name: "DivineCamera.Prewarm")
            }
            #endif
            _ = AVCaptureDevice.default(for: .audio)

            // 2. VideoToolbox via a throwaway AVAssetWriter.
            // startWriting() loads the H.264 encoder; cancelWriting()
            // releases it immediately so we don't hold any encoder resources.
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("divine_av_prewarm.mp4")
            try? FileManager.default.removeItem(at: tempURL)
            do {
                let writer = try AVAssetWriter(outputURL: tempURL, fileType: .mp4)
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: 1080,
                    AVVideoHeightKey: 1920,
                ]
                let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                videoInput.expectsMediaDataInRealTime = true
                if writer.canAdd(videoInput) {
                    writer.add(videoInput)
                }
                writer.startWriting()
                writer.cancelWriting()
                try? FileManager.default.removeItem(at: tempURL)
                DivineCameraLog.shared.debug("VideoToolbox pre-warmed via AVAssetWriter", name: "DivineCamera.Prewarm")
            } catch {
                DivineCameraLog.shared.warning("VideoToolbox pre-warm failed: \(error.localizedDescription)", name: "DivineCamera.Prewarm")
            }
        }
    }
    
    @objc private func handleAutoStop(_ notification: Notification) {
        guard let userInfo = notification.userInfo as? [String: Any] else { return }
        
        // Invoke method channel to notify Flutter of auto-stop
        DispatchQueue.main.async { [weak self] in
            self?.methodChannel?.invokeMethod("onRecordingAutoStopped", arguments: userInfo)
        }
    }
    
    /// Session-lifecycle operations worth leaving a breadcrumb for. High-
    /// frequency calls (zoom / focus / exposure / getCameraState) are excluded
    /// on purpose so they don't flood the captured log buffer.
    private static let lifecycleMethods: Set<String> = [
        "initializeCamera", "disposeCamera", "switchCamera",
        "startRecording", "stopRecording", "pausePreview", "resumePreview",
        "setFlashMode", "setRemoteRecordControlEnabled",
        "setVideoStabilizationMode",
    ]

    private static func logLifecycleCall(_ call: FlutterMethodCall) {
        guard lifecycleMethods.contains(call.method) else { return }
        let args = call.arguments as? [String: Any]
        DivineCameraLog.shared.debug(
            "→ \(call.method)\(args.map { " \($0)" } ?? "")",
            name: "DivineCamera.Lifecycle"
        )
    }

    /// Per-instance forwarder pushing native diagnostics over THIS engine's
    /// channel. `DivineCameraLog.shared.sink` is a process-wide singleton, so a
    /// second FlutterEngine that registers the plugin would otherwise overwrite
    /// it and route camera logs to the wrong isolate.
    ///
    /// Unlike Android, iOS `FlutterPlugin` has no Activity-attachment lifecycle
    /// to bind sink ownership to, so we cannot scope ownership to the UI engine
    /// at registration time. Instead the sink is re-asserted at every UI-bound
    /// entry point: each method call (`handle`), and — for events that fire
    /// without a method call — the native volume/Bluetooth and suppression-timer
    /// callbacks (`VolumeKeyHandler`) and, in `CameraController`, the audio-
    /// session interruption observer, the sample-buffer delegate's first-frame /
    /// writer-start breadcrumbs, the frame watchdog and init-timeout timers, and
    /// the max-duration auto-stop's recording-finalization breadcrumbs (the
    /// #4779 "WITHOUT audio track" warning). Those native sources only ever
    /// exist on the UI engine, so a background engine can't own these UI-only
    /// events. See #5128.
    private lazy var logSink: (String, String, String, Double) -> Void = {
        [weak self] level, message, name, timestampMs in
        DispatchQueue.main.async {
            self?.methodChannel?.invokeMethod(
                "onNativeLog",
                arguments: [
                    "level": level,
                    "message": message,
                    "name": name,
                    "timestampMs": timestampMs,
                ]
            )
        }
    }

    private func installLogSink() {
        DivineCameraLog.shared.sink = logSink
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        installLogSink()
        DivineCameraPlugin.logLifecycleCall(call)
        switch call.method {
        case "getPlatformVersion":
            #if os(iOS)
            result("iOS " + UIDevice.current.systemVersion)
            #else
            result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
            #endif
            
        case "initializeCamera":
            let args = call.arguments as? [String: Any] ?? [:]
            let lens = args["lens"] as? String ?? "back"
            let videoQuality = args["videoQuality"] as? String ?? "fhd"
            let enableScreenFlash = args["enableScreenFlash"] as? Bool ?? true
            let mirrorFrontCameraOutput = args["mirrorFrontCameraOutput"] as? Bool ?? true
            let enableAutoLensSwitch = args["enableAutoLensSwitch"] as? Bool ?? true
            let preferUnprocessedAudio = args["preferUnprocessedAudio"] as? Bool ?? false
            let videoStabilizationMode = args["videoStabilizationMode"] as? String ?? "off"
            initializeCamera(lens: lens, videoQuality: videoQuality, enableScreenFlash: enableScreenFlash, mirrorFrontCameraOutput: mirrorFrontCameraOutput, enableAutoLensSwitch: enableAutoLensSwitch, preferUnprocessedAudio: preferUnprocessedAudio, videoStabilizationMode: videoStabilizationMode, result: result)
            
        case "disposeCamera":
            disposeCamera(result: result)
            
        case "setFlashMode":
            let args = call.arguments as? [String: Any] ?? [:]
            let mode = args["mode"] as? String ?? "off"
            setFlashMode(mode: mode, result: result)
            
        case "setFocusPoint":
            let args = call.arguments as? [String: Any] ?? [:]
            let x = args["x"] as? Double ?? 0.5
            let y = args["y"] as? Double ?? 0.5
            setFocusPoint(x: x, y: y, result: result)
            
        case "setExposurePoint":
            let args = call.arguments as? [String: Any] ?? [:]
            let x = args["x"] as? Double ?? 0.5
            let y = args["y"] as? Double ?? 0.5
            setExposurePoint(x: x, y: y, result: result)
            
        case "cancelFocusAndMetering":
            cancelFocusAndMetering(result: result)
            
        case "setZoomLevel":
            let args = call.arguments as? [String: Any] ?? [:]
            let level = args["level"] as? Double ?? 1.0
            setZoomLevel(level: level, result: result)

        case "setVideoStabilizationMode":
            let args = call.arguments as? [String: Any] ?? [:]
            let mode = args["mode"] as? String ?? "off"
            setVideoStabilizationMode(mode: mode, result: result)

        case "switchCamera":
            let args = call.arguments as? [String: Any] ?? [:]
            let lens = args["lens"] as? String ?? "back"
            switchCamera(lens: lens, result: result)
            
        case "startRecording":
            let args = call.arguments as? [String: Any] ?? [:]
            let maxDurationMs = args["maxDurationMs"] as? Int
            let useCache = args["useCache"] as? Bool ?? true
            let outputDirectory = args["outputDirectory"] as? String
            startRecording(maxDurationMs: maxDurationMs, useCache: useCache, outputDirectory: outputDirectory, result: result)
            
        case "stopRecording":
            stopRecording(result: result)

        case "capturePhoto":
            let args = call.arguments as? [String: Any] ?? [:]
            let useCache = args["useCache"] as? Bool ?? true
            let outputDirectory = args["outputDirectory"] as? String
            capturePhoto(useCache: useCache, outputDirectory: outputDirectory, result: result)

        case "pausePreview":
            pausePreview(call: call, result: result)
            
        case "resumePreview":
            resumePreview(result: result)

        case "suspendAudioCapture":
            suspendAudioCapture(result: result)

        case "resumeAudioCapture":
            resumeAudioCapture(result: result)
            
        case "getCameraState":
            getCameraState(result: result)
            
        case "setRemoteRecordControlEnabled":
            let args = call.arguments as? [String: Any] ?? [:]
            let enabled = args["enabled"] as? Bool ?? false
            setRemoteRecordControlEnabled(enabled: enabled, result: result)
            
        case "setVolumeKeysEnabled":
            let args = call.arguments as? [String: Any] ?? [:]
            let enabled = args["enabled"] as? Bool ?? true
            setVolumeKeysEnabled(enabled: enabled, result: result)
            
        case "listAudioDevices":
            listAudioDevices(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Builds a `FlutterError` and forwards it to Dart's UnifiedLogger so the
    /// failure shows up in user bug reports. Fatal native crashes are captured
    /// separately by Crashlytics. Static so it can be called from `@escaping`
    /// completion closures without capturing `self`.
    private static func cameraError(_ code: String, _ message: String?) -> FlutterError {
        DivineCameraLog.shared.error(
            "\(code): \(message ?? "")",
            name: "DivineCamera.Plugin"
        )
        return FlutterError(code: code, message: message, details: nil)
    }

    private func initializeCamera(lens: String, videoQuality: String, enableScreenFlash: Bool, mirrorFrontCameraOutput: Bool, enableAutoLensSwitch: Bool, preferUnprocessedAudio: Bool, videoStabilizationMode: String, result: @escaping FlutterResult) {
        guard let registry = textureRegistry else {
            result(Self.cameraError("NO_REGISTRY", "Texture registry not available"))
            return
        }
        
        cameraController?.release()
        cameraController = CameraController(
            textureRegistry: registry,
            reclaimLogSink: { [weak self] in self?.installLogSink() }
        )

        cameraController?.initialize(lens: lens, videoQuality: videoQuality, enableScreenFlash: enableScreenFlash, mirrorFrontCameraOutput: mirrorFrontCameraOutput, enableAutoLensSwitch: enableAutoLensSwitch, preferUnprocessedAudio: preferUnprocessedAudio, videoStabilizationMode: videoStabilizationMode) { [weak self] state, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(Self.cameraError("INIT_ERROR", error))
                } else {
                    if let dict = state as? [String: Any] {
                        DivineCameraLog.shared.info(
                            "Camera initialized (lens=\(dict["lens"] ?? "?"), "
                                + "aspectRatio=\(dict["aspectRatio"] ?? "?"), "
                                + "hasFlash=\(dict["hasFlash"] ?? "?"), "
                                + "lenses=\(dict["availableLenses"] ?? "?"))",
                            name: "DivineCamera.Lifecycle"
                        )
                    }
                    result(state)
                }
            }
        }
    }
    
    private func disposeCamera(result: @escaping FlutterResult) {
        #if os(iOS)
        volumeKeyHandler?.release()
        volumeKeyHandler = nil
        #endif

        guard let controller = cameraController else {
            result(nil)
            return
        }
        cameraController = nil
        // Return only once the capture sessions are actually stopped. The
        // caller switches the shared AVAudioSession to playback immediately
        // after this future resolves, and iOS refuses that category change
        // with InsufficientPriority while the audio capture session is still
        // running -- which left the editor playing back through the
        // recorder's session configuration.
        controller.release {
            result(nil)
        }
    }
    
    private func setRemoteRecordControlEnabled(enabled: Bool, result: @escaping FlutterResult) {
        #if os(macOS)
        // Volume keys and Bluetooth remote triggers are iPhone features.
        result(false)
        #else
        if enabled {
            if volumeKeyHandler == nil {
                volumeKeyHandler = VolumeKeyHandler(
                    reclaimLogSink: { [weak self] in self?.installLogSink() }
                ) { [weak self] triggerType in
                    // Send trigger event to Flutter on main thread
                    DispatchQueue.main.async {
                        self?.methodChannel?.invokeMethod("onRemoteRecordTrigger", arguments: triggerType)
                    }
                }
            }
            let success = volumeKeyHandler?.enable() ?? false
            result(success)
        } else {
            volumeKeyHandler?.disable()
            result(true)
        }
        #endif
    }

    private func setVolumeKeysEnabled(enabled: Bool, result: @escaping FlutterResult) {
        #if os(macOS)
        result(false)
        #else
        volumeKeyHandler?.setVolumeKeysEnabled(enabled)
        result(true)
        #endif
    }
    
    private func setFlashMode(mode: String, result: @escaping FlutterResult) {
        guard let controller = cameraController else {
            result(Self.cameraError("NOT_INITIALIZED", "Camera not initialized"))
            return
        }
        let success = controller.setFlashMode(mode: mode)
        result(success)
    }
    
    private func setFocusPoint(x: Double, y: Double, result: @escaping FlutterResult) {
        guard let controller = cameraController else {
            result(Self.cameraError("NOT_INITIALIZED", "Camera not initialized"))
            return
        }
        let success = controller.setFocusPoint(x: CGFloat(x), y: CGFloat(y))
        result(success)
    }
    
    private func setExposurePoint(x: Double, y: Double, result: @escaping FlutterResult) {
        guard let controller = cameraController else {
            result(Self.cameraError("NOT_INITIALIZED", "Camera not initialized"))
            return
        }
        let success = controller.setExposurePoint(x: CGFloat(x), y: CGFloat(y))
        result(success)
    }
    
    private func cancelFocusAndMetering(result: @escaping FlutterResult) {
        guard let controller = cameraController else {
            result(Self.cameraError("NOT_INITIALIZED", "Camera not initialized"))
            return
        }
        let success = controller.cancelFocusAndMetering()
        result(success)
    }
    
    private func setZoomLevel(level: Double, result: @escaping FlutterResult) {
        guard let controller = cameraController else {
            result(Self.cameraError("NOT_INITIALIZED", "Camera not initialized"))
            return
        }
        // Map with the applied zoom + live available range, nil on failure.
        result(controller.setZoomLevel(level: CGFloat(level)))
    }

    private func setVideoStabilizationMode(mode: String, result: @escaping FlutterResult) {
        guard let controller = cameraController else {
            result(Self.cameraError("NOT_INITIALIZED", "Camera not initialized"))
            return
        }
        let success = controller.setVideoStabilizationMode(mode)
        result(success)
    }

    private func switchCamera(lens: String, result: @escaping FlutterResult) {
        guard let controller = cameraController else {
            result(Self.cameraError("NOT_INITIALIZED", "Camera not initialized"))
            return
        }
        
        #if os(iOS)
        // Suppress Bluetooth triggers during camera switch.
        // iOS re-evaluates audio routing on AVCaptureSession reconfiguration,
        // which can cause connected Bluetooth devices (Apple Watch, AirPods)
        // to send spurious play/pause events that would restart recording.
        volumeKeyHandler?.suppressTemporarily(forSeconds: 3.0)
        #endif

        controller.switchCamera(lens: lens) { state, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(Self.cameraError("SWITCH_ERROR", error))
                } else {
                    if let dict = state as? [String: Any] {
                        DivineCameraLog.shared.info(
                            "Camera switched (lens=\(dict["lens"] ?? "?"))",
                            name: "DivineCamera.Lifecycle"
                        )
                    }
                    result(state)
                }
            }
        }
    }
    
    private func startRecording(maxDurationMs: Int?, useCache: Bool, outputDirectory: String?, result: @escaping FlutterResult) {
        guard let controller = cameraController else {
            result(Self.cameraError("NOT_INITIALIZED", "Camera not initialized"))
            return
        }
        
        controller.startRecording(maxDurationMs: maxDurationMs, useCache: useCache, outputDirectory: outputDirectory) { error in
            DispatchQueue.main.async {
                if let error = error {
                    result(Self.cameraError("RECORD_START_ERROR", error))
                } else {
                    result(nil)
                }
            }
        }
    }
    
    private func stopRecording(result: @escaping FlutterResult) {
        guard let controller = cameraController else {
            result(Self.cameraError("NOT_INITIALIZED", "Camera not initialized"))
            return
        }

        controller.stopRecording { recordingResult, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(Self.cameraError("RECORD_STOP_ERROR", error))
                } else {
                    result(recordingResult)
                }
            }
        }
    }

    private func capturePhoto(useCache: Bool, outputDirectory: String?, result: @escaping FlutterResult) {
        guard let controller = cameraController else {
            result(Self.cameraError("NOT_INITIALIZED", "Camera not initialized"))
            return
        }

        controller.capturePhoto(outputDirectory: outputDirectory, useCache: useCache) { photoResult, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(Self.cameraError("PHOTO_CAPTURE_ERROR", error))
                } else {
                    result(photoResult)
                }
            }
        }
    }
    
    private func pausePreview(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let releaseAudio = (call.arguments as? [String: Any])?["releaseAudio"] as? Bool ?? true
        cameraController?.pausePreview(releaseAudio: releaseAudio)
        result(nil)
    }
    
    private func resumePreview(result: @escaping FlutterResult) {
        cameraController?.resumePreview { state, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(Self.cameraError("RESUME_ERROR", error))
                } else {
                    result(state)
                }
            }
        }
    }
    
    private func suspendAudioCapture(result: @escaping FlutterResult) {
        guard let controller = cameraController else {
            result(nil)
            return
        }
        controller.suspendAudioCapture {
            result(nil)
        }
    }

    private func resumeAudioCapture(result: @escaping FlutterResult) {
        guard let controller = cameraController else {
            result(nil)
            return
        }
        controller.resumeAudioCapture {
            result(nil)
        }
    }

    private func getCameraState(result: @escaping FlutterResult) {
        guard let controller = cameraController else {
            result(Self.cameraError("NOT_INITIALIZED", "Camera not initialized"))
            return
        }
        result(controller.getCameraState())
    }
    
    private func listAudioDevices(result: @escaping FlutterResult) {
        #if os(macOS)
        // Macs commonly record through USB or other external microphones.
        let deviceTypes: [AVCaptureDevice.DeviceType]
        if #available(macOS 14.0, *) {
            deviceTypes = [.microphone, .external]
        } else {
            deviceTypes = [.builtInMicrophone, .externalUnknown]
        }
        #else
        let deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInMicrophone]
        #endif
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .audio,
            position: .unspecified
        )
        let devices: [[String: String]] = discoverySession.devices.map { device in
            [
                "id": device.uniqueID,
                "name": device.localizedName,
            ]
        }
        result(devices)
    }
}
