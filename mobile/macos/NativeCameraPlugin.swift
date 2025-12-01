// ABOUTME: Native macOS camera implementation using AVFoundation
// ABOUTME: Provides real camera access through platform channels for Flutter

import FlutterMacOS
import AVFoundation
import Foundation
import CoreMedia

public class NativeCameraPlugin: NSObject, FlutterPlugin {
    private var methodChannel: FlutterMethodChannel?
    private var captureSession: AVCaptureSession?
    private var videoDevice: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    private var isRecording = false
    private var outputURL: URL?
    private var stopRecordingResult: FlutterResult?
    
    // Frame processing
    private let videoQueue = DispatchQueue(label: "VideoQueue", qos: .userInteractive)
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "openvine/native_camera",
            binaryMessenger: registrar.messenger
        )
        let instance = NativeCameraPlugin()
        instance.methodChannel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("🔵 [NativeCamera] Method called: \(call.method)")
        print("🔵 [NativeCamera] Current thread: \(Thread.current)")
        print("🔵 [NativeCamera] Is main thread: \(Thread.isMainThread)")
        
        switch call.method {
        case "initialize":
            print("🔵 [NativeCamera] Handling initialize request")
            initializeCamera(result: result)
        case "startPreview":
            print("🔵 [NativeCamera] Handling startPreview request")
            startPreview(result: result)
        case "stopPreview":
            print("🔵 [NativeCamera] Handling stopPreview request")
            stopPreview(result: result)
        case "startRecording":
            print("🔵 [NativeCamera] Handling startRecording request")
            startRecording(result: result)
        case "stopRecording":
            print("🟡 [NativeCamera] *** STOP RECORDING REQUEST RECEIVED ***")
            print("🔵 [NativeCamera] Handling stopRecording request")
            stopRecording(result: result)
        case "requestPermission":
            print("🔵 [NativeCamera] Handling requestPermission request")
            requestPermission(result: result)
        case "hasPermission":
            print("🔵 [NativeCamera] Handling hasPermission request")
            hasPermission(result: result)
        case "getAvailableCameras":
            print("🔵 [NativeCamera] Handling getAvailableCameras request")
            getAvailableCameras(result: result)
        case "switchCamera":
            print("🔵 [NativeCamera] Handling switchCamera request")
            if let args = call.arguments as? [String: Any],
               let cameraIndex = args["cameraIndex"] as? Int {
                print("🔵 [NativeCamera] Switch to camera index: \(cameraIndex)")
                switchCamera(cameraIndex: cameraIndex, result: result)
            } else {
                print("❌ [NativeCamera] Invalid camera index argument")
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid camera index", details: nil))
            }
        case "dispose":
            print("🔵 [NativeCamera] Handling dispose request")
            dispose(result: result)
        default:
            print("❌ [NativeCamera] Unknown method: \(call.method)")
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func initializeCamera(result: @escaping FlutterResult) {
        print("🔵 [NativeCamera] Starting camera initialization")
        
        // Check camera permission first
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        print("🔵 [NativeCamera] Camera authorization status: \(authStatus.rawValue)")
        
        switch authStatus {
        case .authorized:
            print("✅ [NativeCamera] Camera permission already granted, setting up session")
            setupCaptureSession(result: result)
        case .notDetermined:
            print("⚠️ [NativeCamera] Camera permission not determined, requesting...")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                print("🔵 [NativeCamera] Permission request result: \(granted)")
                if granted {
                    print("✅ [NativeCamera] Permission granted, setting up session")
                    self?.setupCaptureSession(result: result)
                } else {
                    print("❌ [NativeCamera] Permission denied by user")
                    result(FlutterError(code: "PERMISSION_DENIED", message: "Camera permission denied", details: nil))
                }
            }
        case .denied, .restricted:
            print("❌ [NativeCamera] Camera permission denied/restricted")
            result(FlutterError(code: "PERMISSION_DENIED", message: "Camera permission denied", details: nil))
        @unknown default:
            print("❌ [NativeCamera] Unknown permission status")
            result(FlutterError(code: "PERMISSION_UNKNOWN", message: "Unknown permission status", details: nil))
        }
    }
    
    private func setupCaptureSession(result: @escaping FlutterResult) {
        print("🔵 [NativeCamera] Setting up capture session")
        
        // Clean up any existing session first
        if let existingSession = captureSession {
            print("🧹 [NativeCamera] Cleaning up existing capture session")
            if existingSession.isRunning {
                existingSession.stopRunning()
            }
            existingSession.inputs.forEach { existingSession.removeInput($0) }
            existingSession.outputs.forEach { existingSession.removeOutput($0) }
            videoInput = nil
            audioInput = nil
        }
        
        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else {
            print("❌ [NativeCamera] Failed to create capture session")
            result(FlutterError(code: "SESSION_FAILED", message: "Failed to create capture session", details: nil))
            return
        }
        
        print("✅ [NativeCamera] Capture session created successfully")
        
        captureSession.beginConfiguration()
        
        // Set session preset
        if captureSession.canSetSessionPreset(.medium) {
            captureSession.sessionPreset = .medium
        }
        
        // Get default video device - simple approach that was working
        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            print("❌ [NativeCamera] No camera available")

            // Check if any cameras exist but are in use
            let allDevices = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
                mediaType: .video,
                position: .unspecified
            ).devices

            let errorMessage: String
            if allDevices.isEmpty {
                errorMessage = "No camera found. Please connect a camera or enable your built-in camera in System Settings."
            } else {
                let cameraNames = allDevices.map { $0.localizedName }.joined(separator: ", ")
                errorMessage = "Camera unavailable. Found cameras (\(cameraNames)) but they may be in use by another app (like iPhone Mirroring, FaceTime, or Continuity Camera). Please close other camera apps and try again."
            }

            print("❌ [NativeCamera] \(errorMessage)")
            result(FlutterError(code: "NO_CAMERA", message: errorMessage, details: nil))
            return
        }
        
        print("✅ [NativeCamera] Selected camera: \(videoDevice.localizedName)")
        
        self.videoDevice = videoDevice
        
        do {
            // Add video input
            videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if let videoInput = videoInput, captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
                print("✅ [NativeCamera] Video input added successfully")
            } else {
                result(FlutterError(code: "INPUT_FAILED", message: "Failed to add video input", details: nil))
                return
            }

            // Add audio input for recording with sound
            if let audioDevice = AVCaptureDevice.default(for: .audio) {
                audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if let audioInput = audioInput, captureSession.canAddInput(audioInput) {
                    captureSession.addInput(audioInput)
                    print("✅ [NativeCamera] Audio input added successfully: \(audioDevice.localizedName)")
                } else {
                    print("⚠️ [NativeCamera] Could not add audio input - recording will be video-only")
                }
            } else {
                print("⚠️ [NativeCamera] No microphone available - recording will be video-only")
            }

            // Add video output for frames
            videoOutput = AVCaptureVideoDataOutput()
            if let videoOutput = videoOutput, captureSession.canAddOutput(videoOutput) {
                videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
                videoOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                captureSession.addOutput(videoOutput)
            }
            
            // Add movie output for recording
            movieOutput = AVCaptureMovieFileOutput()
            if let movieOutput = movieOutput, captureSession.canAddOutput(movieOutput) {
                // Configure movie output for vine recording
                // No wall-clock duration limit - users may take hours setting up shots between segments.
                // The actual 6-second recorded content limit is enforced by Flutter virtual segments.
                movieOutput.maxRecordedDuration = CMTime.invalid // No limit
                movieOutput.maxRecordedFileSize = Int64(500 * 1024 * 1024) // 500MB max file size

                // Set up video settings for good quality/size balance
                // macOS will use the default system codec (typically H.264)
                print("🎥 [NativeCamera] Using system default codec for macOS recording")

                captureSession.addOutput(movieOutput)
                print("✅ [NativeCamera] Movie output added to capture session")
                print("🎥 [NativeCamera] No wall-clock limit (6s content limit enforced by Flutter)")
            } else {
                print("❌ [NativeCamera] Failed to add movie output to capture session")
            }
            
            captureSession.commitConfiguration()
            result(true)
            
        } catch {
            result(FlutterError(code: "SETUP_FAILED", message: "Failed to setup camera: \(error.localizedDescription)", details: nil))
        }
    }
    
    private func startPreview(result: @escaping FlutterResult) {
        guard let captureSession = captureSession else {
            result(FlutterError(code: "SESSION_NOT_INITIALIZED", message: "Capture session not initialized", details: nil))
            return
        }
        
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
                DispatchQueue.main.async {
                    result(true)
                }
            }
        } else {
            result(true)
        }
    }
    
    private func stopPreview(result: @escaping FlutterResult) {
        guard let captureSession = captureSession else {
            result(false)
            return
        }
        
        if captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.stopRunning()
                DispatchQueue.main.async {
                    result(true)
                }
            }
        } else {
            result(true)
        }
    }
    
    private func startRecording(result: @escaping FlutterResult) {
        NSLog("🔵 [NativeCamera] Starting recording...")
        
        guard let captureSession = captureSession, captureSession.isRunning else {
            NSLog("❌ [NativeCamera] Capture session not running")
            result(FlutterError(code: "SESSION_NOT_RUNNING", message: "Capture session not running", details: nil))
            return
        }
        
        guard let movieOutput = movieOutput else {
            NSLog("❌ [NativeCamera] Movie output not available")
            result(FlutterError(code: "OUTPUT_NOT_AVAILABLE", message: "Movie output not available", details: nil))
            return
        }
        
        guard let videoInput = videoInput, captureSession.inputs.contains(videoInput) else {
            NSLog("❌ [NativeCamera] Video input not properly configured")
            result(FlutterError(code: "INPUT_NOT_CONFIGURED", message: "Video input not properly configured", details: nil))
            return
        }
        
        if isRecording {
            NSLog("⚠️ [NativeCamera] Already recording, ignoring start request")
            result(false)
            return
        }
        
        // Create output file URL in app's temporary directory (not user Documents)
        let tempDir = FileManager.default.temporaryDirectory
        let timestamp = Int(Date().timeIntervalSince1970)
        outputURL = tempDir.appendingPathComponent("openvine_\(timestamp).mov")
        
        // Clean up old temporary files (older than 1 hour)
        cleanupOldTempFiles(in: tempDir)
        
        print("🔵 [NativeCamera] Temp directory: \(tempDir)")
        print("🔵 [NativeCamera] Output file: openvine_\(timestamp).mov")
        
        guard let outputURL = outputURL else {
            print("❌ [NativeCamera] Failed to create output URL")
            result(FlutterError(code: "FILE_URL_FAILED", message: "Failed to create output URL", details: nil))
            return
        }
        
        print("✅ [NativeCamera] Starting recording to: \(outputURL.path)")
        print("🔵 [NativeCamera] Movie output delegate set to: \(self)")
        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
        isRecording = true
        print("✅ [NativeCamera] Recording started, isRecording=\(isRecording)")
        print("🔵 [NativeCamera] Movie output recording state: \(movieOutput.isRecording)")
        result(true)
    }
    
    private func stopRecording(result: @escaping FlutterResult) {
        print("🔵 [NativeCamera] Stopping recording...")
        
        guard let movieOutput = movieOutput else {
            print("❌ [NativeCamera] Movie output not available for stopping")
            result(nil)
            return
        }
        
        if !isRecording {
            print("⚠️ [NativeCamera] Not currently recording, cannot stop")
            result(nil)
            return
        }
        
        print("🔵 [NativeCamera] Current movie output recording state: \(movieOutput.isRecording)")
        
        // Store the result callback to be called from the delegate
        stopRecordingResult = result
        
        if movieOutput.isRecording {
            print("🔵 [NativeCamera] Calling movieOutput.stopRecording()")
            movieOutput.stopRecording()
            print("🔵 [NativeCamera] Stop recording called - waiting for delegate callback")
            // The delegate method will handle calling the result callback
        } else {
            // Recording might have already stopped (e.g., max duration reached)
            print("⚠️ [NativeCamera] Movie output not recording, checking for existing file")
            isRecording = false
            
            if let path = outputURL?.path, FileManager.default.fileExists(atPath: path) {
                let fileSize = try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64
                print("✅ [NativeCamera] Found existing file: \(path)")
                print("📊 [NativeCamera] File size: \(fileSize ?? 0) bytes")
                result(path)
            } else {
                print("❌ [NativeCamera] No recording file found")
                result(nil)
            }
            stopRecordingResult = nil
        }
    }
    
    private func requestPermission(result: @escaping FlutterResult) {
        print("🔵 [NativeCamera] Requesting camera permission explicitly")
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .video)
        print("🔵 [NativeCamera] Current status before request: \(currentStatus.rawValue)")
        
        AVCaptureDevice.requestAccess(for: .video) { granted in
            print("🔵 [NativeCamera] Permission request completed with result: \(granted)")
            let newStatus = AVCaptureDevice.authorizationStatus(for: .video)
            print("🔵 [NativeCamera] New status after request: \(newStatus.rawValue)")
            
            DispatchQueue.main.async {
                result(granted)
            }
        }
    }
    
    private func hasPermission(result: @escaping FlutterResult) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("🔵 [NativeCamera] Checking permission status: \(status.rawValue)")
        print("🔵 [NativeCamera] Status meanings: 0=notDetermined, 1=restricted, 2=denied, 3=authorized")
        result(status == .authorized)
    }
    
    private func getAvailableCameras(result: @escaping FlutterResult) {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        ).devices
        
        let cameras = devices.enumerated().map { index, device in
            return [
                "index": index,
                "name": device.localizedName,
                "position": positionString(device.position)
            ]
        }
        
        result(cameras)
    }
    
    private func positionString(_ position: AVCaptureDevice.Position) -> String {
        switch position {
        case .front: return "front"
        case .back: return "back"
        case .unspecified: return "unknown"
        @unknown default: return "unknown"
        }
    }
    
    private func switchCamera(cameraIndex: Int, result: @escaping FlutterResult) {
        guard let captureSession = captureSession else {
            result(false)
            return
        }
        
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        ).devices
        
        guard cameraIndex < devices.count else {
            result(FlutterError(code: "INVALID_INDEX", message: "Camera index out of range", details: nil))
            return
        }
        
        let newDevice = devices[cameraIndex]
        
        do {
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            
            captureSession.beginConfiguration()
            
            if let currentInput = videoInput {
                captureSession.removeInput(currentInput)
            }
            
            if captureSession.canAddInput(newInput) {
                captureSession.addInput(newInput)
                videoInput = newInput
                videoDevice = newDevice
                captureSession.commitConfiguration()
                result(true)
            } else {
                captureSession.commitConfiguration()
                result(false)
            }
        } catch {
            result(FlutterError(code: "SWITCH_FAILED", message: "Failed to switch camera: \(error.localizedDescription)", details: nil))
        }
    }
    
    private func dispose(result: @escaping FlutterResult) {
        if isRecording {
            movieOutput?.stopRecording()
        }

        captureSession?.stopRunning()
        captureSession = nil
        videoDevice = nil
        videoInput = nil
        audioInput = nil
        videoOutput = nil
        movieOutput = nil
        previewLayer = nil
        outputURL = nil
        isRecording = false

        result(nil)
    }
    
    /// Clean up old temporary video files to prevent storage buildup
    private func cleanupOldTempFiles(in directory: URL) {
        do {
            let fileManager = FileManager.default
            let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey], options: [])
            
            let oneHourAgo = Date().addingTimeInterval(-3600) // 1 hour ago
            var cleanedCount = 0
            
            for fileURL in files {
                // Only clean up openvine video files
                if fileURL.lastPathComponent.starts(with: "openvine_") && fileURL.pathExtension == "mov" {
                    if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                       let creationDate = attributes[.creationDate] as? Date,
                       creationDate < oneHourAgo {
                        
                        try fileManager.removeItem(at: fileURL)
                        cleanedCount += 1
                    }
                }
            }
            
            if cleanedCount > 0 {
                print("🧹 [NativeCamera] Cleaned up \(cleanedCount) old temporary video files")
            }
        } catch {
            print("⚠️ [NativeCamera] Failed to clean up temporary files: \(error)")
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension NativeCameraPlugin: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Convert pixel buffer to data for Flutter
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapRep.representation(using: .jpeg, properties: [:]) else { return }
        
        // Send frame to Flutter
        DispatchQueue.main.async { [weak self] in
            self?.methodChannel?.invokeMethod("onFrameAvailable", arguments: FlutterStandardTypedData(bytes: jpegData))
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension NativeCameraPlugin: AVCaptureFileOutputRecordingDelegate {
    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        print("🎬 [NativeCamera] === RECORDING DELEGATE CALLED ===")
        print("🔵 [NativeCamera] Output file URL: \(outputFileURL.path)")
        print("🔵 [NativeCamera] Has stopRecordingResult callback: \(stopRecordingResult != nil)")
        
        isRecording = false
        
        if let error = error {
            print("❌ [NativeCamera] Recording finished with error: \(error.localizedDescription)")
            print("❌ [NativeCamera] Error code: \((error as NSError).code)")
            print("❌ [NativeCamera] Error domain: \((error as NSError).domain)")
            
            if let stopResult = stopRecordingResult {
                stopResult(FlutterError(code: "RECORDING_ERROR", message: error.localizedDescription, details: nil))
            } else {
                print("⚠️ [NativeCamera] No result callback to call for error")
            }
        } else {
            print("✅ [NativeCamera] Recording finished successfully")
            print("📁 [NativeCamera] Final video path: \(outputFileURL.path)")
            
            // Check if file actually exists
            if FileManager.default.fileExists(atPath: outputFileURL.path) {
                let fileSize = try? FileManager.default.attributesOfItem(atPath: outputFileURL.path)[.size] as? Int64
                print("📊 [NativeCamera] File exists, size: \(fileSize ?? 0) bytes")
                
                if let stopResult = stopRecordingResult {
                    stopResult(outputFileURL.path)
                } else {
                    print("⚠️ [NativeCamera] No result callback to call for success")
                }
            } else {
                print("⚠️ [NativeCamera] Warning: File doesn't exist at path")
                if let stopResult = stopRecordingResult {
                    stopResult(nil) // Return nil if file doesn't exist
                }
            }
        }
        
        stopRecordingResult = nil
        print("🔵 [NativeCamera] Recording delegate completed, callback cleared")
    }
}