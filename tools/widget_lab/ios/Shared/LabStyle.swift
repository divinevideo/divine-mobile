import SwiftUI

enum LabStyle {
    static let green = Color(red: 0.15, green: 0.77, blue: 0.55)
    static let frameCount = 16
    static let previewDuration = 2.0
    static let frameDuration = previewDuration / Double(frameCount)
    static let titles = ["A little weirdness", "Six seconds of joy", "Look what people make"]

    static func frame(_ clip: Int, _ frame: Int) -> String {
        String(format: "clip_%d_frame_%02d", clip, frame)
    }
}
