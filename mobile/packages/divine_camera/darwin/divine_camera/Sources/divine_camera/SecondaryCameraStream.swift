// ABOUTME: Preview texture and silent recorder for the second camera of a
// ABOUTME: dual-camera (front + back) capture session

import AVFoundation
#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif

/// The second camera of a dual-camera session: its preview texture and the
/// silent video file it records next to every take.
///
/// `CameraController` owns the session and hands every frame of the second
/// camera's video data output to `updatePreview(_:)` and, while a take
/// records, to `append(_:at:anchor:stop:)`. The recording opens on
/// the main camera's writer anchor, so both files of a take start at the
/// same capture time, and it ends on the main file's last frame.
///
/// Every method except `register()` / `unregister()` and `copyPixelBuffer()`
/// runs on the controller's `videoOutputQueue`.
final class SecondaryCameraStream: NSObject, FlutterTexture {
    private let textureRegistry: FlutterTextureRegistry
    private(set) var textureId: Int64 = -1

    /// The lens string this stream reports to Dart ("front" or "back").
    var lensType: String

    /// Portrait width / height of the frames the camera delivers.
    var aspectRatio: Double = 9.0 / 16.0

    private let pixelBufferLock = NSLock()
    private var pixelBuffer: CVPixelBuffer?

    private var writer: AVAssetWriter?
    private var writerInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var outputURL: URL?
    private var recordingLensType: String?
    private var isSessionStarted = false
    private var lastAppendedPTS: CMTime?
    /// The newest frame captured before the main camera opened its writer
    /// session. It opens this file at the main file's anchor, so the second
    /// camera never starts a frame late.
    private var pendingFrame: CVPixelBuffer?

    init(textureRegistry: FlutterTextureRegistry, lensType: String) {
        self.textureRegistry = textureRegistry
        self.lensType = lensType
        super.init()
    }

    /// Whether a recording is open on this stream.
    var isRecording: Bool { writer != nil }

    func register() {
        guard textureId < 0 else { return }
        textureId = textureRegistry.register(self)
    }

    func unregister() {
        guard textureId >= 0 else { return }
        textureRegistry.unregisterTexture(textureId)
        textureId = -1
        pixelBufferLock.lock()
        pixelBuffer = nil
        pixelBufferLock.unlock()
    }

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        pixelBufferLock.lock()
        defer { pixelBufferLock.unlock() }
        guard let pixelBuffer else { return nil }
        return Unmanaged.passRetained(pixelBuffer)
    }

    /// Shows a frame of the second camera in its preview texture.
    func updatePreview(_ buffer: CVPixelBuffer) {
        pixelBufferLock.lock()
        pixelBuffer = buffer
        pixelBufferLock.unlock()
        let id = textureId
        guard id >= 0 else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.textureId == id else { return }
            self.textureRegistry.textureFrameAvailable(id)
        }
    }

    /// Opens the silent file for the next take. The writer session opens
    /// later, on the main camera's anchor (see `append`).
    func prepareRecording(url: URL, width: Int, height: Int, bitRate: Int) {
        cancelRecording()
        try? FileManager.default.removeItem(at: url)
        do {
            let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
            let input = AVAssetWriterInput(
                mediaType: .video,
                outputSettings: [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: width,
                    AVVideoHeightKey: height,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: bitRate,
                        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                    ],
                ]
            )
            input.expectsMediaDataInRealTime = true
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: width,
                    kCVPixelBufferHeightKey as String: height,
                ]
            )
            guard writer.canAdd(input) else {
                DivineCameraLog.shared.warning(
                    "Second camera writer rejected its video input — "
                        + "the take records the main camera only",
                    name: "DivineCamera.DualCamera"
                )
                return
            }
            writer.add(input)
            guard writer.startWriting() else {
                DivineCameraLog.shared.warning(
                    "Second camera writer failed to start: "
                        + "\(writer.error?.localizedDescription ?? "unknown")",
                    name: "DivineCamera.DualCamera"
                )
                return
            }
            self.writer = writer
            self.writerInput = input
            self.adaptor = adaptor
            self.outputURL = url
            self.recordingLensType = lensType
            self.isSessionStarted = false
            self.lastAppendedPTS = nil
            self.pendingFrame = nil
        } catch {
            DivineCameraLog.shared.warning(
                "Second camera writer could not be created: \(error.localizedDescription)",
                name: "DivineCamera.DualCamera"
            )
        }
    }

    /// Appends a frame captured at `timestamp` while a take records.
    ///
    /// `anchor` is the capture time the main camera opened its file on, nil
    /// until its first frame arrives. `stop` is the capture time the take
    /// was asked to end, nil while it runs.
    func append(
        _ buffer: CVPixelBuffer,
        at timestamp: CMTime,
        anchor: CMTime?,
        stop: CMTime?
    ) {
        guard let writer, writer.status == .writing,
              let writerInput, let adaptor else { return }
        if let stop, timestamp >= stop { return }
        guard let anchor else {
            pendingFrame = buffer
            return
        }
        if !isSessionStarted {
            writer.startSession(atSourceTime: anchor)
            isSessionStarted = true
            // The first sample sits on the anchor itself, so the file has no
            // empty lead-in. A frame captured just before the main camera's
            // first one shows at the anchor; otherwise this frame moves up by
            // less than one frame interval.
            let opening = (timestamp > anchor ? pendingFrame : nil) ?? buffer
            pendingFrame = nil
            guard writerInput.isReadyForMoreMediaData else { return }
            adaptor.append(opening, withPresentationTime: anchor)
            lastAppendedPTS = anchor
            if timestamp <= anchor { return }
        }
        if let last = lastAppendedPTS, timestamp <= last { return }
        guard writerInput.isReadyForMoreMediaData else { return }
        adaptor.append(buffer, withPresentationTime: timestamp)
        lastAppendedPTS = timestamp
    }

    /// Finishes the take's file at `endPTS`, the main file's end. Reports the
    /// file, or nil when the second camera captured nothing (its file is
    /// deleted then). `completion` runs on an arbitrary queue.
    func finishRecording(
        endPTS: CMTime?,
        completion: @escaping ([String: Any]?) -> Void
    ) {
        guard let writer, let writerInput, let url = outputURL else {
            completion(nil)
            return
        }
        let lens = recordingLensType ?? lensType
        let started = isSessionStarted && writer.status == .writing
        resetRecordingState()

        guard started, let endPTS else {
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: url)
            completion(nil)
            return
        }
        writer.endSession(atSourceTime: endPTS)
        writerInput.markAsFinished()
        writer.finishWriting {
            guard writer.status == .completed else {
                DivineCameraLog.shared.warning(
                    "Second camera file failed: "
                        + "\(writer.error?.localizedDescription ?? "unknown")",
                    name: "DivineCamera.DualCamera"
                )
                try? FileManager.default.removeItem(at: url)
                completion(nil)
                return
            }
            let asset = AVAsset(url: url)
            var width = 0
            var height = 0
            if let track = asset.tracks(withMediaType: .video).first {
                let size = track.naturalSize.applying(track.preferredTransform)
                width = Int(abs(size.width))
                height = Int(abs(size.height))
            }
            let seconds = CMTimeGetSeconds(asset.duration)
            completion([
                "filePath": url.path,
                "durationMs": seconds.isFinite ? Int(seconds * 1000) : 0,
                "width": width,
                "height": height,
                "lens": lens,
            ])
        }
    }

    /// Drops an open take and its file.
    func cancelRecording() {
        guard let writer else { return }
        let url = outputURL
        resetRecordingState()
        writer.cancelWriting()
        if let url { try? FileManager.default.removeItem(at: url) }
    }

    private func resetRecordingState() {
        writer = nil
        writerInput = nil
        adaptor = nil
        outputURL = nil
        recordingLensType = nil
        isSessionStarted = false
        lastAppendedPTS = nil
        pendingFrame = nil
    }
}
