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
    heldFramesAreDrawnAtTheClocksTime()
    heldFramesAreRedrawnOnlyOnceHeldAndDue()
    redrawsOverAHeldFrameKeepASteadyThirtyFramesASecond()
    print("VideoFrameEffectsTests passed")
  }

  /// Display ticks arrive a little early or late. A spacing equal to a whole
  /// number of display periods lets that decide whether a redraw lands on a
  /// tick or the one after, which measured 23 to 26 redraws a second rather
  /// than 30.
  private static func redrawsOverAHeldFrameKeepASteadyThirtyFramesASecond() {
    for displayHz in [60.0, 90.0, 120.0] {
      let perSecond = redrawsPerSecond(displayHz: displayHz, jitterUs: 1_000)
      precondition(
        abs(perSecond - 30) <= 1, "\(perSecond) redraws a second at \(displayHz) Hz")
    }
  }

  /// Redraws a second over a frame held for ten seconds, with every display
  /// tick off by up to `jitterUs` either way.
  private static func redrawsPerSecond(displayHz: Double, jitterUs: Int64) -> Double {
    let seconds: Int64 = 10
    var seed: UInt64 = 42
    func jitter() -> Int64 {
      seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      return Int64(seed >> 33) % (2 * jitterUs + 1) - jitterUs
    }
    var drawnUs: Int64 = 0
    var redraws = 0
    var tick = 1.0
    while true {
      let nowUs = Int64((tick * 1_000_000 / displayHz).rounded()) + jitter()
      if nowUs > seconds * 1_000_000 { break }
      if let redrawUs = HeldFrameEffects.redrawTimeUs(heldUs: 0, drawnUs: drawnUs, nowUs: nowUs) {
        drawnUs = redrawUs
        redraws += 1
      }
      tick += 1
    }
    return Double(redraws) / Double(seconds)
  }

  /// With nothing new from the output, effects are drawn again over the frame
  /// on screen, but not before it counts as held and not on every tick.
  private static func heldFramesAreRedrawnOnlyOnceHeldAndDue() {
    let heldUs: Int64 = 1_000_000
    let after = HeldFrameEffects.afterUs
    let interval = HeldFrameEffects.intervalUs

    // A frame still inside the time any ordinary frame stands is not held.
    precondition(
      HeldFrameEffects.redrawTimeUs(
        heldUs: heldUs, drawnUs: heldUs, nowUs: heldUs + after - 1) == nil)
    // The moment it is, effects are drawn at the clock's time.
    precondition(
      HeldFrameEffects.redrawTimeUs(
        heldUs: heldUs, drawnUs: heldUs, nowUs: heldUs + after) == heldUs + after)

    // Drawn a moment ago over a held frame: wait out the spacing.
    let drawnUs = heldUs + 3 * after
    precondition(
      HeldFrameEffects.redrawTimeUs(
        heldUs: heldUs, drawnUs: drawnUs, nowUs: drawnUs + interval - 1) == nil)
    precondition(
      HeldFrameEffects.redrawTimeUs(
        heldUs: heldUs, drawnUs: drawnUs, nowUs: drawnUs + interval) == drawnUs + interval)
  }

  /// A still is one sample lasting its whole length. Drawn at its own time,
  /// effects over it stood still for that length, while the export kept
  /// them moving.
  private static func heldFramesAreDrawnAtTheClocksTime() {
    // A 30 fps frame shown a display tick late keeps its own time.
    precondition(
      HeldFrameEffects.timeUs(frameUs: 1_000_000, itemUs: 1_016_000, drawnUs: 966_667)
        == 1_000_000)
    // Half a second into a still, as after a paused seek into it.
    precondition(
      HeldFrameEffects.timeUs(frameUs: 2_000_000, itemUs: 2_500_000, drawnUs: nil)
        == 2_500_000)
    // The frame after a hold, decoded late: behind the last redraw over the
    // still, so its own time would make the effects start over.
    precondition(
      HeldFrameEffects.timeUs(frameUs: 3_000_000, itemUs: 3_040_000, drawnUs: 3_020_000)
        == 3_040_000)
    // After a flush nothing was drawn yet, and an earlier frame is a real
    // jump back.
    precondition(
      HeldFrameEffects.timeUs(frameUs: 1_000_000, itemUs: 1_010_000, drawnUs: nil)
        == 1_000_000)
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
