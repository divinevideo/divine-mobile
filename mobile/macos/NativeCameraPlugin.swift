// ABOUTME: Native macOS camera/microphone permission handling using AVFoundation
// ABOUTME: Exposes explicit camera and microphone request/status methods to Dart

import AVFoundation
import FlutterMacOS
import Foundation
import os

/// Bridges macOS media permissions to Dart.
///
/// `permission_handler` does not drive the AVFoundation authorization dialog
/// reliably on macOS, so the recorder permission flow routes camera and
/// microphone checks/requests through this plugin instead. Each method returns
/// a lowercase status string (`authorized`, `denied`, `restricted`,
/// `notDetermined`, `unknown`) that the Dart side maps to its domain status.
public class NativeCameraPlugin: NSObject, FlutterPlugin {
    private static let logger = Logger(
        subsystem: "com.nostrvine.nostrvineApp",
        category: "NativeCamera"
    )

    private var methodChannel: FlutterMethodChannel?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "openvine/native_camera",
            binaryMessenger: registrar.messenger
        )
        let instance = NativeCameraPlugin()
        instance.methodChannel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        Self.logger.debug("Method called: \(call.method, privacy: .public)")

        switch call.method {
        case "requestCameraPermission":
            requestPermission(for: .video, result: result)
        case "requestMicrophonePermission":
            requestPermission(for: .audio, result: result)
        case "cameraPermissionStatus":
            permissionStatus(for: .video, result: result)
        case "microphonePermissionStatus":
            permissionStatus(for: .audio, result: result)
        case "openSystemSettings":
            openSystemSettings(result: result)
        default:
            Self.logger.error(
                "Unknown method: \(call.method, privacy: .public)"
            )
            result(FlutterMethodNotImplemented)
        }
    }

    private func requestPermission(
        for mediaType: AVMediaType,
        result: @escaping FlutterResult
    ) {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: mediaType)

        switch currentStatus {
        case .authorized, .denied, .restricted:
            // Already resolved — report the current status so the gate can
            // re-prompt or send the user to System Settings as appropriate.
            DispatchQueue.main.async {
                result(Self.statusString(currentStatus))
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: mediaType) { _ in
                let newStatus = AVCaptureDevice.authorizationStatus(
                    for: mediaType
                )
                DispatchQueue.main.async {
                    result(Self.statusString(newStatus))
                }
            }
        @unknown default:
            DispatchQueue.main.async {
                result(Self.statusString(currentStatus))
            }
        }
    }

    private func permissionStatus(
        for mediaType: AVMediaType,
        result: @escaping FlutterResult
    ) {
        let status = AVCaptureDevice.authorizationStatus(for: mediaType)
        result(Self.statusString(status))
    }

    private static func statusString(
        _ status: AVAuthorizationStatus
    ) -> String {
        switch status {
        case .authorized:
            return "authorized"
        case .denied:
            return "denied"
        case .restricted:
            return "restricted"
        case .notDetermined:
            return "notDetermined"
        @unknown default:
            return "unknown"
        }
    }

    private func openSystemSettings(result: @escaping FlutterResult) {
        // The app only appears in the Privacy pane after it has requested
        // media access at least once.
        let privacyPane = Self.settingsPrivacyPane()
        if let url = URL(
            string:
                "x-apple.systempreferences:com.apple.preference.security?\(privacyPane)"
        ) {
            NSWorkspace.shared.open(url)
            result(true)
            return
        }

        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [
            "-b", "com.apple.systempreferences",
            "/System/Library/PreferencePanes/Security.prefPane",
        ]

        do {
            try task.run()
            result(true)
        } catch {
            let message = error.localizedDescription
            Self.logger.error(
                "Failed to open System Settings: \(message, privacy: .public)"
            )
            result(false)
        }
    }

    private static func settingsPrivacyPane() -> String {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if cameraStatus == .denied || cameraStatus == .restricted {
            return "Privacy_Camera"
        }

        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if microphoneStatus == .denied || microphoneStatus == .restricted {
            return "Privacy_Microphone"
        }

        return "Privacy_Camera"
    }
}
