import UIKit

/// Writes a post's thumbnail into the shared app group, where the Live
/// Activity can read it (it cannot fetch from the network).
enum PostActivityThumbnailWriter {
    /// Longest side in pixels; a Live Activity shows it very small.
    static let maxSide: CGFloat = 144
    static let jpegQuality: CGFloat = 0.7

    struct WriteError: Error {
        let reason: String
    }

    /// Writes `data` as a JPEG under a name chosen here, never by the caller,
    /// and returns that file name. Every other file in the directory is
    /// deleted, but only after the new one is safely written, so a bad image
    /// leaves the existing files alone.
    static func write(_ data: Data, containerURL: URL) throws -> String {
        guard let source = UIImage(data: data), source.size.width > 0, source.size.height > 0 else {
            throw WriteError(reason: "not an image")
        }
        let pixelWidth = source.size.width * source.scale
        let pixelHeight = source.size.height * source.scale
        let ratio = min(1, maxSide / max(pixelWidth, pixelHeight))
        let target = CGSize(
            width: max(1, (pixelWidth * ratio).rounded()),
            height: max(1, (pixelHeight * ratio).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let scaled = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            source.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let jpeg = scaled.jpegData(compressionQuality: jpegQuality) else {
            throw WriteError(reason: "jpeg encoding failed")
        }

        let fileManager = FileManager.default
        let directory = containerURL.appendingPathComponent(
            PostActivityThumbnail.directory,
            isDirectory: true
        )
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = UUID().uuidString + ".jpg"
        try jpeg.write(to: directory.appendingPathComponent(name), options: .atomic)
        for existing in try fileManager.contentsOfDirectory(atPath: directory.path)
        where existing != name {
            try? fileManager.removeItem(at: directory.appendingPathComponent(existing))
        }
        return name
    }
}
