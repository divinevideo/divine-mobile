// ABOUTME: Recording extension for CameraController
// ABOUTME: Handles AVAssetWriter-based video recording, start/stop, and auto-stop

import AVFoundation
import Foundation

extension CameraController {

    /// Starts video recording using AVAssetWriter.
    func startRecording(
        maxDurationMs: Int?,
        useCache: Bool = true,
        outputDirectory: String? = nil,
        audioDeviceId: String? = nil,
        completion: @escaping (String?) -> Void
    ) {
        if isRecording {
            completion("Already recording")
            return
        }

        // Check and enable auto-flash if needed
        checkAndEnableAutoFlash()

        self.maxDurationMs = maxDurationMs

        videoOutputQueue.async { [weak self] in
            guard let self = self else { return }

            // Guard against the first-sample-buffer race (#4112): refuse to
            // start the writer until the capture delegate has delivered a
            // preview frame. Dimensions below come from the device's active
            // format (always available), not the latest buffer, so this guard
            // is the only thing gating record-start on the first frame.
            guard self.hasReceivedPreviewFrame() else {
                self.disableAutoFlash()
                DispatchQueue.main.async {
                    completion(
                        "Camera preview has not produced a video frame yet"
                    )
                }
                return
            }

            let outputDir: URL
            if let customDir = outputDirectory {
                outputDir = URL(fileURLWithPath: customDir)
            } else if useCache {
                outputDir = FileManager.default.temporaryDirectory
            } else {
                let paths = FileManager.default.urls(
                    for: .documentDirectory,
                    in: .userDomainMask
                )
                outputDir = paths[0]
            }

            let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
            let outputURL = outputDir.appendingPathComponent(
                "VID_\(timestamp).mp4"
            )
            self.currentRecordingURL = outputURL

            try? FileManager.default.removeItem(at: outputURL)

            do {
                let writer = try AVAssetWriter(
                    outputURL: outputURL,
                    fileType: .mp4
                )

                guard let device = self.videoDevice else {
                    DispatchQueue.main.async {
                        completion("Video device not available")
                    }
                    return
                }

                let dimensions = CMVideoFormatDescriptionGetDimensions(
                    device.activeFormat.formatDescription
                )
                // macOS cameras are landscape—width is the longer side
                let videoWidth = Int(dimensions.width)
                let videoHeight = Int(dimensions.height)

                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: videoWidth,
                    AVVideoHeightKey: videoHeight,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: self.videoEncodingBitRate,
                        AVVideoProfileLevelKey:
                            AVVideoProfileLevelH264HighAutoLevel,
                    ],
                ]

                let videoInput = AVAssetWriterInput(
                    mediaType: .video,
                    outputSettings: videoSettings
                )
                videoInput.expectsMediaDataInRealTime = true

                let sourcePixelBufferAttributes: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String:
                        kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: videoWidth,
                    kCVPixelBufferHeightKey as String: videoHeight,
                ]
                let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                    assetWriterInput: videoInput,
                    sourcePixelBufferAttributes: sourcePixelBufferAttributes
                )

                let audioSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44100.0,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderBitRateKey: 64000,
                ]
                let audioInput = AVAssetWriterInput(
                    mediaType: .audio,
                    outputSettings: audioSettings
                )
                audioInput.expectsMediaDataInRealTime = true

                guard writer.canAdd(videoInput) else {
                    self.cleanupRecordingState(deleteOutputFile: true)
                    DispatchQueue.main.async {
                        completion("Cannot add video input to asset writer")
                    }
                    return
                }
                writer.add(videoInput)

                let addedAudioInput: AVAssetWriterInput?
                if writer.canAdd(audioInput) {
                    writer.add(audioInput)
                    addedAudioInput = audioInput
                } else {
                    addedAudioInput = nil
                    DivineCameraLog.shared.warning(
                        "Cannot add audio input to asset writer — "
                            + "recording without audio",
                        name: "DivineCamera.Recording"
                    )
                }

                self.assetWriter = writer
                self.videoWriterInput = videoInput
                self.audioWriterInput = addedAudioInput
                self.pixelBufferAdaptor = adaptor

                guard writer.startWriting() else {
                    let message =
                        writer.error?.localizedDescription ?? "Unknown error"
                    writer.cancelWriting()
                    self.cleanupRecordingState(deleteOutputFile: true)
                    DivineCameraLog.shared.error(
                        "Failed to start asset writer: \(message)",
                        name: "DivineCamera.Recording"
                    )
                    DispatchQueue.main.async {
                        completion(
                            "Failed to start asset writer: \(message)"
                        )
                    }
                    return
                }

                // Switch to the preferred audio device if specified.
                // The audio input/output stay in the session for its
                // entire lifetime (added during setupCamera).
                if let deviceId = audioDeviceId {
                    self.switchAudioDevice(to: deviceId)
                }

                self.isRecording = true
                self.isWriterSessionStarted = false
                self.recordingStartTime = Date()

                DivineCameraLog.shared.info(
                    "Recording started (audioTrack=\(addedAudioInput != nil))",
                    name: "DivineCamera.Recording"
                )

                // Schedule max duration timer if specified
                if let maxMs = maxDurationMs, maxMs > 0 {
                    DispatchQueue.main.async { [weak self] in
                        self?.maxDurationTimer = Timer.scheduledTimer(
                            withTimeInterval: Double(maxMs) / 1000.0,
                            repeats: false
                        ) { [weak self] _ in
                            self?.autoStopRecording()
                        }
                    }
                }

                DispatchQueue.main.async {
                    completion(nil)
                }

            } catch {
                DispatchQueue.main.async {
                    completion(
                        "Failed to create asset writer: "
                            + "\(error.localizedDescription)"
                    )
                }
            }
        }
    }

    /// Automatically stops recording when max duration is reached.
    func autoStopRecording() {
        guard isRecording else { return }

        maxDurationTimer?.invalidate()
        maxDurationTimer = nil

        stopRecording { result, error in
            if result == nil {
                DivineCameraLog.shared.error(
                    "Auto-stop finished with nothing to save: "
                        + "\(error ?? "unknown error")",
                    name: "DivineCamera.Recording"
                )
            }
            // Sent even when nothing was saved: an empty payload has no
            // filePath, which tells Dart the recording is over (#9261). The
            // plugin drops a nil userInfo, not an empty one.
            NotificationCenter.default.post(
                name: NSNotification.Name("DivineCameraAutoStop"),
                object: nil,
                userInfo: result ?? [:]
            )
        }
    }

    /// Stops video recording and returns the result.
    func stopRecording(
        completion: @escaping ([String: Any]?, String?) -> Void
    ) {
        guard isRecording, let writer = assetWriter else {
            completion(nil, "Not recording")
            return
        }

        maxDurationTimer?.invalidate()
        maxDurationTimer = nil
        isRecording = false

        // Disable auto-flash when recording stops
        disableAutoFlash()

        videoOutputQueue.async { [weak self] in
            guard let self = self else { return }

            if !self.isWriterSessionStarted {
                writer.cancelWriting()
                self.cleanupRecordingState(deleteOutputFile: true)
                DispatchQueue.main.async {
                    completion(
                        nil,
                        "Recording stopped before first video frame"
                    )
                }
                return
            }

            self.videoWriterInput?.markAsFinished()
            self.audioWriterInput?.markAsFinished()

            writer.finishWriting { [weak self] in
                guard let self = self else { return }

                // Whether an audio track was written, captured before the
                // cleanup below nils out the input. The macOS path avoids
                // loading the finished AVAsset, so this writer-input proxy
                // stands in for the iOS file-level check.
                let hadAudioTrack = self.audioWriterInput != nil

                DispatchQueue.main.async {
                    if writer.status == .completed {
                        let duration: Int
                        if let startTime = self.recordingStartTime {
                            duration = Int(
                                Date().timeIntervalSince(startTime) * 1000
                            )
                        } else {
                            duration = 0
                        }

                        guard let outputURL = self.currentRecordingURL else {
                            completion(nil, "Output URL not available")
                            return
                        }

                        var width: Int = 1920
                        var height: Int = 1080

                        // Use the known recording dimensions from the
                        // active format rather than loading from the asset
                        // (the async AVAsset API cannot be used here).
                        if let device = self.videoDevice {
                            let dims = CMVideoFormatDescriptionGetDimensions(
                                device.activeFormat.formatDescription
                            )
                            width = Int(dims.width)
                            height = Int(dims.height)
                        }

                        let result: [String: Any] = [
                            "filePath": outputURL.path,
                            "durationMs": duration,
                            "width": width,
                            "height": height,
                        ]

                        if hadAudioTrack {
                            DivineCameraLog.shared.info(
                                "Recording completed with audio track "
                                    + "(durationMs=\(duration))",
                                name: "DivineCamera.Recording"
                            )
                        } else {
                            DivineCameraLog.shared.warning(
                                "Recording completed WITHOUT audio track "
                                    + "(durationMs=\(duration))",
                                name: "DivineCamera.Recording"
                            )
                        }
                        completion(result, nil)
                    } else {
                        DivineCameraLog.shared.error(
                            "Recording failed: "
                                + "\(writer.error?.localizedDescription ?? "Unknown error")",
                            name: "DivineCamera.Recording"
                        )
                        completion(
                            nil,
                            "Recording failed: "
                                + "\(writer.error?.localizedDescription ?? "Unknown error")"
                        )
                    }

                    // Audio is intentionally kept in the session
                    // after recording stops. Removing it triggers
                    // macOS "Call Ended" notification. It will be
                    // cleaned up when the camera is disposed.

                    // Cleanup
                    self.assetWriter = nil
                    self.videoWriterInput = nil
                    self.audioWriterInput = nil
                    self.pixelBufferAdaptor = nil
                    self.currentRecordingURL = nil
                    self.recordingStartTime = nil
                    self.isWriterSessionStarted = false
                }
            }
        }
    }

    /// Clears recording-only state after completion, cancellation, or failure.
    func cleanupRecordingState(deleteOutputFile: Bool) {
        disableAutoFlash()

        if deleteOutputFile, let outputURL = currentRecordingURL {
            try? FileManager.default.removeItem(at: outputURL)
        }

        assetWriter = nil
        videoWriterInput = nil
        audioWriterInput = nil
        pixelBufferAdaptor = nil
        currentRecordingURL = nil
        recordingStartTime = nil
        isWriterSessionStarted = false
        isRecording = false
    }
}
