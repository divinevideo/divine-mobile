import AVFoundation
import CoreImage

/// Asks for one earlier frame and draws nothing, so a test can drive the
/// decode of earlier frames without depending on how an effect looks.
private final class HistoryEffect: VideoFrameEffect {
  let historyOffsetsUs: [Int64] = [100_000]
  let historyScale = 1.0

  func render(_ image: CIImage, history: [CIImage?], timeUs: Int64, effectTimeUs: Int64)
    -> CIImage
  { image }
}

@main
enum VideoFrameEffectsTests {
  static func main() {
    precondition(CMTime.invalid.microseconds == nil)
    precondition(CMTime.indefinite.microseconds == nil)
    precondition(CMTime.positiveInfinity.microseconds == nil)
    precondition(CMTime(value: 3, timescale: 2).microseconds == 1_500_000)

    decodingFromAnAssetThatFailsCompletesTheFill()
    print("VideoFrameEffectsTests passed")
  }

  /// A decode that fails reports an invalid time for the frame it could not
  /// make. Converting its NaN seconds to an integer used to end the process.
  private static func decodingFromAnAssetThatFailsCompletesTheFill() {
    VideoFrameEffects.register("test.history") { _ in HistoryEffect() }
    let processor = VideoFrameEffectProcessor()
    // The processor holds the item weakly, so the test keeps it alive.
    let item = AVPlayerItem(
      url: URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("missing_\(UUID().uuidString).mp4"))
    processor.playerItem = item
    var filled = false
    processor.onHistoryFilled = { filled = true }
    processor.setEffects([["id": "test.history", "params": [String: Any]()]])

    var buffer: CVPixelBuffer?
    CVPixelBufferCreate(nil, 64, 64, kCVPixelFormatType_32BGRA, nil, &buffer)
    _ = processor.process(buffer!, timeUs: 1_000_000)

    let deadline = Date().addingTimeInterval(10)
    while !filled, Date() < deadline {
      RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
    precondition(filled, "the failed decode never completed its fill")
    processor.dispose()
    withExtendedLifetime(item) {}
  }
}
