// ABOUTME: AVCapturePhotoCaptureDelegate that writes a captured still to JPEG
// ABOUTME: Used by CameraController for single-frame (stop-motion) capture

import AVFoundation

/// Receives a single captured photo, writes it to disk as JPEG, and reports
/// the resulting file path and pixel dimensions via [onFinished].
final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    init(outputDirectory: String?, useCache: Bool) {
        self.outputDirectory = outputDirectory
        self.useCache = useCache
        super.init()
    }

    private let outputDirectory: String?
    private let useCache: Bool

    /// Invoked once when processing finishes. First argument is the result map
    /// (`filePath`, `width`, `height`) on success, or nil on failure with a
    /// message in the second argument.
    var onFinished: (([String: Any]?, String?) -> Void)?

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            onFinished?(nil, error.localizedDescription)
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            onFinished?(nil, "Photo data unavailable")
            return
        }

        // Mirror startRecording's path resolution: explicit dir, cache, or docs.
        let outputDir: URL
        if let customDir = outputDirectory {
            outputDir = URL(fileURLWithPath: customDir)
        } else if useCache {
            outputDir = FileManager.default.temporaryDirectory
        } else {
            let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            outputDir = paths[0]
        }

        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let outputURL = outputDir.appendingPathComponent("IMG_\(timestamp).jpg")

        do {
            try FileManager.default.createDirectory(
                at: outputDir,
                withIntermediateDirectories: true
            )
            try data.write(to: outputURL)
            let dimensions = photo.resolvedSettings.photoDimensions
            onFinished?(
                [
                    "filePath": outputURL.path,
                    "width": Int(dimensions.width),
                    "height": Int(dimensions.height),
                ],
                nil
            )
        } catch {
            onFinished?(nil, error.localizedDescription)
        }
    }
}
