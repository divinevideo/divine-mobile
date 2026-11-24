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

/// Darkens the frame and asks for no earlier frames, so every frame it is
/// active on is drawn through the processor's context.
private final class DimEffect: VideoFrameEffect {
  let historyOffsetsUs: [Int64] = []
  let historyScale = 1.0

  func render(_ image: CIImage, history: [CIImage?], timeUs: Int64, effectTimeUs: Int64)
    -> CIImage
  { image.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: -1]) }
}

/// Asks for the frame 100 ms back at `scale` and records what it got, so a
/// test can check how sharp each effect's earlier frames are.
private final class RecordingEffect: VideoFrameEffect {
  let historyOffsetsUs: [Int64] = [100_000]
  let historyScale: Double
  var received: [CIImage?] = []

  init(scale: Double) { historyScale = scale }

  func render(_ image: CIImage, history: [CIImage?], timeUs: Int64, effectTimeUs: Int64)
    -> CIImage
  {
    received = history
    return image
  }
}

@main
enum VideoFrameEffectsTests {
  static func main() {
    precondition(CMTime.invalid.microseconds == nil)
    precondition(CMTime.indefinite.microseconds == nil)
    precondition(CMTime.positiveInfinity.microseconds == nil)
    precondition(CMTime(value: 3, timescale: 2).microseconds == 1_500_000)

    decodingFromAnAssetThatFailsCompletesTheFill()
    aPlayerWithoutEffectsNeverCreatesARenderContext()
    theRenderContextIsCreatedOnceWhenAnEffectIsFirstDrawn()
    heldFramesAreDrawnAtTheClocksTime()
    heldFramesAreRedrawnOnlyOnceHeldAndDue()
    redrawsOverAHeldFrameKeepASteadyThirtyFramesASecond()
    eachEffectGetsEarlierFramesAtTheSizeItAsksFor()
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
    // So is one behind what was drawn while the clock is behind it too, a
    // seek back: the effects have to start over, not carry on from the clock.
    precondition(
      HeldFrameEffects.timeUs(frameUs: 1_000_000, itemUs: 1_010_000, drawnUs: 5_000_000)
        == 1_000_000)

    // A frame is held from the moment it is `afterUs` late, not a microsecond
    // before.
    let after = HeldFrameEffects.afterUs
    precondition(
      HeldFrameEffects.timeUs(frameUs: 1_000_000, itemUs: 1_000_000 + after - 1, drawnUs: nil)
        == 1_000_000)
    precondition(
      HeldFrameEffects.timeUs(frameUs: 1_000_000, itemUs: 1_000_000 + after, drawnUs: nil)
        == 1_000_000 + after)

    // Behind the last draw, the clock takes over once it has caught up with
    // that draw, not before.
    precondition(
      HeldFrameEffects.timeUs(frameUs: 3_000_000, itemUs: 3_020_000, drawnUs: 3_020_000)
        == 3_020_000)
    precondition(
      HeldFrameEffects.timeUs(frameUs: 3_000_000, itemUs: 3_019_999, drawnUs: 3_020_000)
        == 3_000_000)
    // A frame at exactly the last draw is not behind it.
    precondition(
      HeldFrameEffects.timeUs(frameUs: 3_000_000, itemUs: 3_030_000, drawnUs: 3_000_000)
        == 3_000_000)
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

  /// Creating the context sets up Metal on the main thread, so a player that
  /// never draws an effect, like every feed player, must not make one.
  private static func aPlayerWithoutEffectsNeverCreatesARenderContext() {
    var made = 0
    let processor = VideoFrameEffectProcessor(makeContext: {
      made += 1
      return VideoFrameEffectProcessor.makeRenderContext()
    })
    let frame = makeFrame()
    _ = processor.process(frame, timeUs: 0)
    processor.setEffects([])
    for timeUs in stride(from: Int64(33_333), to: 200_000, by: 33_333) {
      precondition(processor.process(frame, timeUs: timeUs) === frame)
    }
    processor.reset()
    processor.dispose()
    precondition(made == 0, "a player without effects created \(made) render contexts")
  }

  /// The first frame an effect is drawn on makes the context, and the frames
  /// after it reuse that one.
  private static func theRenderContextIsCreatedOnceWhenAnEffectIsFirstDrawn() {
    VideoFrameEffects.register("test.dim") { _ in DimEffect() }
    var made = 0
    let processor = VideoFrameEffectProcessor(makeContext: {
      made += 1
      return VideoFrameEffectProcessor.makeRenderContext()
    })
    processor.setEffects([["id": "test.dim", "params": [String: Any]()]])
    precondition(made == 0, "setting an effect created a render context before any frame")

    let frame = makeFrame()
    for timeUs in stride(from: Int64(0), to: 200_000, by: 33_333) {
      precondition(processor.process(frame, timeUs: timeUs) !== frame, "the effect was not drawn")
    }
    precondition(made == 1, "drawing six frames created \(made) render contexts")
    processor.dispose()
  }

  /// An effect that compares the frame with an earlier one needs that frame
  /// whole: a smaller copy has lost the fine detail, which then counts as
  /// change. The export keeps each effect's earlier frames at its own size,
  /// so the preview does too, even while an effect that asks for smaller
  /// ones is set for a later part of the video.
  private static func eachEffectGetsEarlierFramesAtTheSizeItAsksFor() {
    let whole = RecordingEffect(scale: 1)
    let half = RecordingEffect(scale: 0.5)
    VideoFrameEffects.register("test.whole") { _ in whole }
    VideoFrameEffects.register("test.half") { _ in half }
    let processor = VideoFrameEffectProcessor()
    processor.setEffects([
      ["id": "test.whole", "params": [String: Any](), "startUs": 0, "endUs": 1_000_000],
      ["id": "test.half", "params": [String: Any](), "startUs": 0],
    ])

    // A still picture with detail one pixel fine: black and white columns.
    let still = makeFrame { x, _ in x % 2 == 0 ? 0 : 255 }
    for timeUs in stride(from: Int64(0), through: 100_000, by: 33_333) {
      _ = processor.process(still, timeUs: timeUs)
    }

    let context = CIContext(options: [.workingColorSpace: NSNull()])
    func columns(_ image: CIImage?) -> [UInt8] {
      guard let image else { preconditionFailure("no earlier frame") }
      var pixels = [UInt8](repeating: 0, count: 64 * 64 * 4)
      context.render(
        image, toBitmap: &pixels, rowBytes: 64 * 4,
        bounds: CGRect(x: 0, y: 0, width: 64, height: 64), format: .BGRA8, colorSpace: nil)
      return (0..<64).map { pixels[(32 * 64 + $0) * 4] }
    }
    let sharp = columns(whole.received.first ?? nil)
    for x in 0..<64 {
      precondition(
        abs(Int(sharp[x]) - (x % 2 == 0 ? 0 : 255)) <= 2,
        "the whole-size effect got a blurred earlier frame: column \(x) is \(sharp[x])")
    }
    let soft = columns(half.received.first ?? nil)
    precondition(
      soft[10...50].allSatisfy { abs(Int($0) - 128) <= 40 },
      "the half-size effect did not get its smaller copy: \(soft[10...50])")
    processor.dispose()
  }

  /// A 64×64 frame whose blue, green and red are `shade(x, y)`, first row at
  /// the top.
  private static func makeFrame(_ shade: (Int, Int) -> UInt8) -> CVPixelBuffer {
    let buffer = makeFrame()
    CVPixelBufferLockBaseAddress(buffer, [])
    let base = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
    let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
    for y in 0..<64 {
      for x in 0..<64 {
        let value = shade(x, y)
        let pixel = base + y * rowBytes + x * 4
        pixel[0] = value
        pixel[1] = value
        pixel[2] = value
        pixel[3] = 255
      }
    }
    CVPixelBufferUnlockBaseAddress(buffer, [])
    return buffer
  }

  private static func makeFrame() -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    CVPixelBufferCreate(nil, 64, 64, kCVPixelFormatType_32BGRA, nil, &buffer)
    return buffer!
  }
}
