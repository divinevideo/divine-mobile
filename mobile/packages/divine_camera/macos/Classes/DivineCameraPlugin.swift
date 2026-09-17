// ABOUTME: Main Flutter plugin entry point for macOS camera operations
// ABOUTME: Handles method channel communication and delegates to CameraController

import FlutterMacOS
import AppKit
import AVFoundation

public class DivineCameraPlugin: NSObject, FlutterPlugin {
    private var cameraController: CameraController?
    private var textureRegistry: FlutterTextureRegistry?
    private var messenger: FlutterBinaryMessenger?
    private var methodChannel: FlutterMethodChannel?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "divine_camera",
            binaryMessenger: registrar.messenger
        )
        let instance = DivineCameraPlugin()
        instance.textureRegistry = registrar.textures
        instance.messenger = registrar.messenger
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
    }

    @objc private func handleAutoStop(_ notification: Notification) {
        guard let userInfo = notification.userInfo as? [String: Any] else { return }

        DispatchQueue.main.async { [weak self] in
            self?.methodChannel?.invokeMethod(
                "onRecordingAutoStopped",
                arguments: userInfo
            )
        }
    }

    /// Session-lifecycle operations worth leaving a breadcrumb for. High-
    /// frequency calls (zoom / focus / exposure / getCameraState) are excluded
    /// on purpose so they don't flood the captured log buffer.
    private static let lifecycleMethods: Set<String> = [
        "initializeCamera", "disposeCamera", "switchCamera",
        "startRecording", "stopRecording", "pausePreview", "resumePreview",
        "setFlashMode",
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
    /// channel. `DivineCameraLog.shared.sink` is a process-wide singleton. We
    /// re-assert it in `handle` — camera calls only ever reach the UI engine.
    ///
    /// macOS does emit some diagnostics from native-only timer callbacks (the
    /// init-timeout and max-duration auto-stop timers fire without a method
    /// call), so it is not structurally exempt the way "every diagnostic is
    /// method-driven" would imply. The reason no native-only reclaim is needed
    /// here is that desktop has no background `FlutterEngine` (no FCM isolate)
    /// that could register the plugin and steal the sink — effectively one
    /// engine owns it from `register()`, so re-asserting on each method call is
    /// sufficient. (Android binds ownership to the Activity lifecycle; iOS
    /// reclaims in its native callbacks because the background-engine steal
    /// scenario does apply on mobile.) See #5128.
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

    public func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        installLogSink()
        DivineCameraPlugin.logLifecycleCall(call)
        switch call.method {
        case "getPlatformVersion":
            result(
                "macOS " + ProcessInfo.processInfo.operatingSystemVersionString
            )

        case "initializeCamera":
            let args = call.arguments as? [String: Any] ?? [:]
            let lens = args["lens"] as? String ?? "front"
            let videoQuality = args["videoQuality"] as? String ?? "fhd"
            let enableAutoLensSwitch =
                args["enableAutoLensSwitch"] as? Bool ?? false
            initializeCamera(
                lens: lens,
                videoQuality: videoQuality,
                enableAutoLensSwitch: enableAutoLensSwitch,
                result: result
            )

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
            // AVCaptureConnection.preferredVideoStabilizationMode is an
            // iOS-only API; macOS has no video stabilization support.
            result(false)

        case "switchCamera":
            let args = call.arguments as? [String: Any] ?? [:]
            let lens = args["lens"] as? String ?? "front"
            switchCamera(lens: lens, result: result)

        case "startRecording":
            let args = call.arguments as? [String: Any] ?? [:]
            let maxDurationMs = args["maxDurationMs"] as? Int
            let useCache = args["useCache"] as? Bool ?? true
            let outputDirectory = args["outputDirectory"] as? String
            let audioDeviceId = args["audioDeviceId"] as? String
            startRecording(
                maxDurationMs: maxDurationMs,
                useCache: useCache,
                outputDirectory: outputDirectory,
                audioDeviceId: audioDeviceId,
                result: result
            )

        case "stopRecording":
            stopRecording(result: result)

        case "capturePhoto":
            let args = call.arguments as? [String: Any] ?? [:]
            let useCache = args["useCache"] as? Bool ?? true
            let outputDirectory = args["outputDirectory"] as? String
            capturePhoto(
                useCache: useCache,
                outputDirectory: outputDirectory,
                result: result
            )

        case "pausePreview":
            pausePreview(result: result)

        case "resumePreview":
            resumePreview(result: result)

        case "suspendAudioCapture", "resumeAudioCapture":
            // macOS keeps the audio input inside the single video+audio
            // capture session, so releasing it would restart the preview,
            // and the speaker-into-mic gain recovery these calls work
            // around is an iPhone behaviour; see the iOS CameraController.
            result(nil)

        case "getCameraState":
            getCameraState(result: result)

        case "setRemoteRecordControlEnabled":
            // Remote record control (volume keys / Bluetooth) not supported
            // on macOS
            result(false)

        case "setVolumeKeysEnabled":
            // Volume keys not supported on macOS
            result(false)

        case "listAudioDevices":
            listAudioDevices(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Camera Operations

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

    private func initializeCamera(
        lens: String,
        videoQuality: String,
        enableAutoLensSwitch: Bool,
        result: @escaping FlutterResult
    ) {
        guard let registry = textureRegistry else {
            result(Self.cameraError("NO_REGISTRY", "Texture registry not available"))
            return
        }

        cameraController?.release()
        cameraController = CameraController(textureRegistry: registry)

        cameraController?.initialize(
            lens: lens,
            videoQuality: videoQuality,
            enableAutoLensSwitch: enableAutoLensSwitch
        ) { state, error in
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
        cameraController?.release()
        cameraController = nil
        result(nil)
    }

    private func setFlashMode(
        mode: String,
        result: @escaping FlutterResult
    ) {
        guard let controller = cameraController else {
            result(Self.cameraError("NOT_INITIALIZED", "Camera not initialized"))
            return
        }
        let success = controller.setFlashMode(mode: mode)
        result(success)
    }

    private func setFocusPoint(
        x: Double,
        y: Double,
        result: @escaping FlutterResult
    ) {
        guard let controller = cameraController else {
            result(Self.cameraError("NOT_INITIALIZED", "Camera not initialized"))
            return
        }
        let success = controller.setFocusPoint(x: CGFloat(x), y: CGFloat(y))
        result(success)
    }

    private func setExposurePoint(
        x: Double,
        y: Double,
        result: @escaping FlutterResult
    ) {
        guard let controller = cameraController else {
            result(Self.cameraError("NOT_INITIALIZED", "Camera not initialized"))
            return
        }
        let success = controller.setExposurePoint(
            x: CGFloat(x),
            y: CGFloat(y)
        )
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
        guard cameraController != nil else {
            result(Self.cameraError("NOT_INITIALIZED", "Camera not initialized"))
            return
        }
        // Programmatic zoom is unsupported on macOS cameras; nil signals
        // failure in the shared channel contract (applied-zoom map or nil).
        result(nil)
    }

    private func switchCamera(lens: String, result: @escaping FlutterResult) {
        guard let controller = cameraController else {
            result(Self.cameraError("NOT_INITIALIZED", "Camera not initialized"))
            return
        }

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

    private func startRecording(
        maxDurationMs: Int?,
        useCache: Bool,
        outputDirectory: String?,
        audioDeviceId: String?,
        result: @escaping FlutterResult
    ) {
        guard let controller = cameraController else {
            result(Self.cameraError("NOT_INITIALIZED", "Camera not initialized"))
            return
        }

        controller.startRecording(
            maxDurationMs: maxDurationMs,
            useCache: useCache,
            outputDirectory: outputDirectory,
            audioDeviceId: audioDeviceId
        ) { error in
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

    private func capturePhoto(
        useCache: Bool,
        outputDirectory: String?,
        result: @escaping FlutterResult
    ) {
        guard let controller = cameraController else {
            result(Self.cameraError("NOT_INITIALIZED", "Camera not initialized"))
            return
        }

        controller.capturePhoto(
            outputDirectory: outputDirectory,
            useCache: useCache
        ) { photoResult, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(Self.cameraError("PHOTO_CAPTURE_ERROR", error))
                } else {
                    result(photoResult)
                }
            }
        }
    }

    private func pausePreview(result: @escaping FlutterResult) {
        cameraController?.pausePreview()
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

    private func getCameraState(result: @escaping FlutterResult) {
        guard let controller = cameraController else {
            result(Self.cameraError("NOT_INITIALIZED", "Camera not initialized"))
            return
        }
        result(controller.getCameraState())
    }

    private func listAudioDevices(result: @escaping FlutterResult) {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        )
        let devices: [[String: String]] = discoverySession.devices.map {
            device in
            [
                "id": device.uniqueID,
                "name": device.localizedName,
            ]
        }
        result(devices)
    }
}
