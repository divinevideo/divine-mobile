import AVFoundation
import CoreImage
import Foundation

/// An effect the app draws on the player's frames, registered by id with
/// ``VideoFrameEffects`` and switched on from Dart with `setFrameEffects`.
///
/// It receives earlier frames of the same clip, as many as
/// ``historyOffsetsUs`` asks for, so an effect such as an echo trail can be
/// previewed. While playing they come from what the player showed; after a
/// seek the missing ones are decoded from the player's asset, so a paused
/// frame shows the same trail as playback would.
public protocol VideoFrameEffect: AnyObject {
  /// The earlier frames ``render(_:history:timeUs:effectTimeUs:)`` receives,
  /// as how far each lies before the current frame, in microseconds.
  var historyOffsetsUs: [Int64] { get }

  /// The size earlier frames are kept at, relative to the video, 0.05...1.
  var historyScale: Double { get }

  /// Returns `image` with the effect applied. `history` has one entry per
  /// offset, with the same extent as `image`, or `nil` when the player has
  /// not shown that far back in this clip.
  func render(_ image: CIImage, history: [CIImage?], timeUs: Int64, effectTimeUs: Int64)
    -> CIImage
}

/// The frame effects an app registered, by id.
public enum VideoFrameEffects {
  /// Creates an effect from the params Dart sends with it.
  public typealias Factory = (_ params: [String: Any]) -> VideoFrameEffect

  private static let lock = NSLock()
  private static var factories: [String: Factory] = [:]

  /// Registers `factory` under `id`, replacing whatever was registered there.
  public static func register(_ id: String, factory: @escaping Factory) {
    lock.lock()
    defer { lock.unlock() }
    factories[id] = factory
  }

  static func factory(for id: String) -> Factory? {
    lock.lock()
    defer { lock.unlock() }
    return factories[id]
  }
}

/// Draws the active frame effects on each frame on its way to the texture,
/// and keeps the earlier frames they ask for.
///
/// Main thread only, like the texture output that owns it.
final class VideoFrameEffectProcessor {

  private struct Stage {
    let effect: VideoFrameEffect
    let offsetsUs: [Int64]
    let startUs: Int64?
    let endUs: Int64?
    /// Where in ``histories`` its earlier frames are kept; `nil` for an
    /// effect that asks for none.
    var history: Int?

    func isActive(atUs timeUs: Int64) -> Bool {
      (startUs.map { timeUs >= $0 } ?? true) && (endUs.map { timeUs < $0 } ?? true)
    }
  }

  private struct Kept {
    let timeUs: Int64
    let clip: Int
    let buffer: CVPixelBuffer
  }

  /// The frames the player showed, kept at one size for the effects that ask
  /// for it, back as far as the furthest of them reaches.
  ///
  /// Each size an effect asks for has its own, as each stage of the export
  /// keeps its own: an effect that needs whole frames, such as one that
  /// compares the frame with the one before, would see lost detail as change
  /// if it got the smaller copies another effect asked for.
  private final class History {
    let scale: CGFloat
    var maxOffsetUs: Int64 = 0
    var frames: [Kept] = []
    var pool: CVPixelBufferPool?
    var size = CGSize.zero

    init(scale: CGFloat) { self.scale = scale }
  }

  /// A frame decoded from the asset: wanted for `targetUs`, shown from `frameUs`.
  private struct Decoded {
    let targetUs: Int64
    let frameUs: Int64
    let clip: Int
    let buffer: CVPixelBuffer
  }

  /// How far short of an offset a frame may lie and still count, in µs, as
  /// on the export side.
  private static let toleranceUs: Int64 = 1_000

  /// How far from the time it was decoded for a decoded frame may stand in.
  /// While scrubbing, the frames decoded for where the playhead just was
  /// serve the next positions; further off they would show the wrong moment.
  private static let maxDecodedDriftUs: Int64 = 150_000

  /// How far a newer seek may lie from a running decode before that decode
  /// is dropped; closer, its frames still serve.
  private static let fillKeepDistanceUs: Int64 = 500_000

  private var stages: [Stage] = []
  /// The configs the stages were built from, to tell a repeated list apart.
  private var lastConfigs: NSArray?
  private var maxOffsetUs: Int64 = 0
  private var clipOffsetsUs: [Int64] = []
  /// The frames the player showed since the last seek, one store per size
  /// the effects ask for.
  private var histories: [History] = []
  /// Where the frame kept last lies, at whichever size.
  private var lastKept: (timeUs: Int64, clip: Int)?
  /// The frames decoded for the last seek, kept across seeks for scrubbing.
  private var decoded: [Decoded] = []

  /// Made the first time an effect is drawn, because creating it sets up Metal
  /// on the main thread and most players never draw an effect.
  private lazy var context = makeContext()
  private let makeContext: () -> CIContext
  /// The item whose asset a seek's missing earlier frames are decoded from.
  weak var playerItem: AVPlayerItem?

  /// Called on the main thread once earlier frames decoded after a seek are
  /// in, so the frame on screen can be drawn again with them.
  var onHistoryFilled: (() -> Void)?

  /// Set when the history started over, so the next frame asks for the
  /// earlier frames it is missing.
  private var needsFill = true
  private var generator: AVAssetImageGenerator?
  private var fillGeneration = 0
  /// The newest time earlier frames are still wanted for, and the time the
  /// running decode is for.
  private var fillRequest: (timeUs: Int64, clip: Int)?
  private var fillRunning: (timeUs: Int64, clip: Int)?
  private var lastFrameSize = CGSize.zero

  private var outputPool: CVPixelBufferPool?
  private var outputSize = CGSize.zero
  /// Frames decoded after a seek are kept at the largest size any effect
  /// asks for, so each effect gets them at least as sharp as it asked.
  private var decodedScale: CGFloat = 1
  private var decodedPool: CVPixelBufferPool?
  private var decodedSize = CGSize.zero

  /// `makeContext` builds the context effects are drawn with, once an effect
  /// is first drawn.
  init(makeContext: @escaping () -> CIContext = VideoFrameEffectProcessor.makeRenderContext) {
    self.makeContext = makeContext
  }

  /// A context that draws in the frames' own colour space.
  static func makeRenderContext() -> CIContext {
    CIContext(options: [
      .workingColorSpace: NSNull(),
      .outputColorSpace: NSNull(),
      .cacheIntermediates: false,
    ])
  }

  /// Whether any effect is set, so frames have to pass through.
  var isActive: Bool { !stages.isEmpty }

  /// Replaces the effects with those in `configs`, each a map of `id`,
  /// `params`, `startUs` and `endUs` on the player's timeline. Ids nothing
  /// is registered under are skipped, with a warning. Returns whether
  /// anything changed: an unchanged list keeps the effects and their earlier
  /// frames as they are.
  @discardableResult
  func setEffects(_ configs: [[String: Any]]) -> Bool {
    let incoming = configs as NSArray
    if let lastConfigs, lastConfigs.isEqual(incoming) { return false }
    lastConfigs = incoming
    var stages: [Stage] = configs.compactMap { config in
      guard let id = config["id"] as? String else { return nil }
      guard let factory = VideoFrameEffects.factory(for: id) else {
        DivineVideoPlayerLog.shared.warning(
          "No frame effect is registered under \(id)", name: "DivineVideoPlayer.Effects")
        return nil
      }
      let effect = factory(config["params"] as? [String: Any] ?? [:])
      return Stage(
        effect: effect,
        offsetsUs: effect.historyOffsetsUs,
        startUs: (config["startUs"] as? NSNumber)?.int64Value,
        endUs: (config["endUs"] as? NSNumber)?.int64Value)
    }
    maxOffsetUs = stages.flatMap { $0.offsetsUs }.max() ?? 0
    // A store already kept at a size keeps its frames: they are keyed by
    // time.
    var kept: [History] = []
    for index in stages.indices where !stages[index].offsetsUs.isEmpty {
      let scale = Self.clampedScale(stages[index].effect.historyScale)
      let position: Int
      if let existing = kept.firstIndex(where: { $0.scale == scale }) {
        position = existing
      } else {
        let store = histories.first { $0.scale == scale } ?? History(scale: scale)
        store.maxOffsetUs = 0
        kept.append(store)
        position = kept.count - 1
      }
      kept[position].maxOffsetUs = max(
        kept[position].maxOffsetUs, stages[index].offsetsUs.max() ?? 0)
      stages[index].history = position
    }
    self.stages = stages
    histories = kept
    let largest = histories.map(\.scale).max() ?? 1
    if largest != decodedScale {
      decodedScale = largest
      decodedPool = nil
      decoded.removeAll()
    }
    if maxOffsetUs == 0 {
      lastKept = nil
      decoded.removeAll()
    }
    needsFill = true
    return true
  }

  /// `scale` within the range ``VideoFrameEffect/historyScale`` allows.
  static func clampedScale(_ scale: Double) -> CGFloat {
    CGFloat(min(1, max(0.05, scale)))
  }

  /// Where each clip starts on the player's timeline, in seconds, so the
  /// history starts over at every cut.
  func setClipOffsets(_ offsets: [Double]) {
    clipOffsetsUs = offsets.map { Int64(($0 * 1_000_000).rounded()) }
    decoded.removeAll()
    startOver()
  }

  /// Forgets every earlier frame, after a seek flushed the player.
  func reset() {
    startOver()
  }

  /// Stops decoding earlier frames, for good.
  func dispose() {
    generator?.cancelAllCGImageGeneration()
    generator = nil
    fillGeneration += 1
    fillRequest = nil
    fillRunning = nil
    lastConfigs = nil
    stages = []
    histories = []
    lastKept = nil
    decoded.removeAll()
  }

  private func startOver() {
    for store in histories { store.frames.removeAll() }
    lastKept = nil
    needsFill = true
  }

  /// Returns `buffer` with the active effects drawn on it, the frame at
  /// `timeUs` on the player's timeline; `buffer` itself when none applies.
  func process(_ buffer: CVPixelBuffer, timeUs: Int64) -> CVPixelBuffer {
    guard !stages.isEmpty else { return buffer }
    let clip = clipIndex(atUs: timeUs)
    if let last = lastKept,
      last.clip != clip || timeUs < last.timeUs
        || timeUs - last.timeUs > maxOffsetUs + 500_000
    {
      // A cut, a jump back or a jump past the trail: start over.
      startOver()
    }
    if needsFill {
      needsFill = false
      requestFill(beforeUs: timeUs, clip: clip)
    }

    let image = CIImage(cvPixelBuffer: buffer)
    let extent = image.extent
    lastFrameSize = extent.size
    var output = image
    var drew = false
    for stage in stages where stage.isActive(atUs: timeUs) {
      let earlier: [CIImage?] = stage.offsetsUs.map { offset in
        let wantedUs = timeUs - offset
        let buffer =
          newest(in: stage.history, atOrBeforeUs: wantedUs + Self.toleranceUs)?.buffer
          ?? nearestDecoded(forUs: wantedUs, clip: clip)?.buffer
        return buffer.map { upscaled(CIImage(cvPixelBuffer: $0), to: extent) }
      }
      output = stage.effect.render(
        output, history: earlier, timeUs: timeUs,
        effectTimeUs: timeUs - (stage.startUs ?? 0)
      ).cropped(to: extent)
      drew = true
    }

    if !histories.isEmpty, lastKept?.timeUs != timeUs {
      keep(image, timeUs: timeUs, clip: clip)
    }
    guard drew, let rendered = render(output, size: extent.size) else { return buffer }
    return rendered
  }

  /// Asks for the earlier frames the frame at `timeUs` of clip `clip` needs
  /// to be decoded from the asset.
  ///
  /// Runs after the history started over: a seek, a scrub, a newly picked
  /// effect. A running decode is not dropped for a seek close to it: while
  /// scrubbing slowly every seek would otherwise cancel the one before, and
  /// no frames would ever arrive. Its frames serve the positions near it,
  /// and the newest one is decoded right after.
  private func requestFill(beforeUs timeUs: Int64, clip: Int) {
    fillRequest = (timeUs, clip)
    if let running = fillRunning {
      guard running.clip != clip || abs(running.timeUs - timeUs) > Self.fillKeepDistanceUs
      else { return }
      generator?.cancelAllCGImageGeneration()
      generator = nil
      fillGeneration += 1
      fillRunning = nil
    }
    startFill()
  }

  /// Decodes the earlier frames for the newest request and swaps them in
  /// once they are all there.
  private func startFill() {
    guard let request = fillRequest else { return }
    fillRequest = nil
    guard maxOffsetUs > 0, let item = playerItem else { return }
    let clip = request.clip
    let clipStart = clip < clipOffsetsUs.count ? clipOffsetsUs[clip] : 0
    let times = Set(stages.flatMap { $0.offsetsUs })
      .map { request.timeUs - $0 }
      .filter { $0 >= clipStart }
      .sorted()
    guard !times.isEmpty else { return }

    // The same picture the player's output hands over: its video
    // composition, and no extra orientation on top.
    let generator = AVAssetImageGenerator(asset: item.asset)
    generator.appliesPreferredTrackTransform = false
    generator.videoComposition = item.videoComposition
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    self.generator = generator
    fillGeneration += 1
    fillRunning = request

    let generation = fillGeneration
    let pending = PendingFill(count: times.count)
    generator.generateCGImagesAsynchronously(
      forTimes: times.map { NSValue(time: CMTime(value: $0, timescale: 1_000_000)) }
    ) { [weak self] requestedTime, image, actualTime, result, error in
      // A failed or cancelled request reports an invalid time.
      let frame = result == .succeeded ? image : nil
      let failure = result == .failed ? error : nil
      let targetUs = requestedTime.microseconds
      let frameUs = actualTime.microseconds
      DispatchQueue.main.async {
        guard let self, generation == self.fillGeneration else { return }
        if let frame, let targetUs, let frameUs {
          pending.decoded.append((targetUs, frameUs, frame))
        } else if pending.failure == nil {
          pending.failure = failure
        }
        pending.remaining -= 1
        guard pending.remaining == 0 else { return }
        if pending.decoded.isEmpty, let cause = pending.failure {
          DivineVideoPlayerLog.shared.warning(
            "Frame effects could not decode earlier frames: \(cause)",
            name: "DivineVideoPlayer.Effects")
        }
        self.generator = nil
        self.fillRunning = nil
        self.replaceDecoded(with: pending.decoded, clip: clip)
        self.onHistoryFilled?()
        self.startFill()
      }
    }
  }

  /// The frames of one fill decoded so far; touched on the main thread only.
  private final class PendingFill: @unchecked Sendable {
    var decoded: [(targetUs: Int64, frameUs: Int64, image: CGImage)] = []
    /// The first error a frame failed with, to report when none decoded.
    var failure: Error?
    var remaining: Int

    init(count: Int) { remaining = count }
  }

  /// Swaps in the frames decoded last, each scaled to the largest size an
  /// effect asks for.
  private func replaceDecoded(
    with frames: [(targetUs: Int64, frameUs: Int64, image: CGImage)], clip: Int
  ) {
    guard !frames.isEmpty, lastFrameSize.width > 0 else { return }
    let size = CGSize(
      width: max(1, (lastFrameSize.width * decodedScale).rounded()),
      height: max(1, (lastFrameSize.height * decodedScale).rounded()))
    if decodedPool == nil || decodedSize != size {
      decodedPool = Self.makePool(size: size)
      decodedSize = size
    }
    guard let pool = decodedPool else { return }
    var replacement: [Decoded] = []
    for frame in frames {
      var copy: CVPixelBuffer?
      guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &copy) == kCVReturnSuccess,
        let copy
      else { continue }
      let image = CIImage(cgImage: frame.image)
      context.render(
        image.transformed(
          by: CGAffineTransform(
            scaleX: size.width / image.extent.width, y: size.height / image.extent.height)),
        to: copy)
      replacement.append(
        Decoded(targetUs: frame.targetUs, frameUs: frame.frameUs, clip: clip, buffer: copy))
    }
    decoded = replacement
  }

  /// The decoded frame for `timeUs`: the one decoded for the nearest time,
  /// if that lies close enough, and never one shown after `timeUs`.
  private func nearestDecoded(forUs timeUs: Int64, clip: Int) -> Decoded? {
    decoded
      .filter {
        $0.clip == clip && abs($0.targetUs - timeUs) <= Self.maxDecodedDriftUs
          && $0.frameUs <= timeUs + Self.toleranceUs
      }
      .min { abs($0.targetUs - timeUs) < abs($1.targetUs - timeUs) }
  }

  private func clipIndex(atUs timeUs: Int64) -> Int {
    var index = 0
    for (i, start) in clipOffsetsUs.enumerated() where timeUs >= start {
      index = i
    }
    return index
  }

  /// The newest frame kept in store `index` at or before `limitUs`.
  private func newest(in index: Int?, atOrBeforeUs limitUs: Int64) -> Kept? {
    guard let index, index < histories.count else { return nil }
    return histories[index].frames.last { $0.timeUs <= limitUs }
  }

  /// Keeps a copy of the frame at each size the effects ask for, and drops
  /// what no later frame can ask for.
  private func keep(_ image: CIImage, timeUs: Int64, clip: Int) {
    lastKept = (timeUs, clip)
    for store in histories {
      let size = CGSize(
        width: max(1, (image.extent.width * store.scale).rounded()),
        height: max(1, (image.extent.height * store.scale).rounded()))
      if store.pool == nil || store.size != size {
        store.pool = Self.makePool(size: size)
        store.size = size
        store.frames.removeAll()
      }
      guard let pool = store.pool else { continue }
      var copy: CVPixelBuffer?
      guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &copy) == kCVReturnSuccess,
        let copy
      else { continue }
      let scaled = image.transformed(
        by: CGAffineTransform(
          scaleX: size.width / image.extent.width, y: size.height / image.extent.height))
      context.render(scaled, to: copy)
      store.frames.append(Kept(timeUs: timeUs, clip: clip, buffer: copy))

      let limit = timeUs - store.maxOffsetUs + Self.toleranceUs
      if let oldestNeeded = store.frames.lastIndex(where: { $0.timeUs <= limit }),
        oldestNeeded > 0
      {
        store.frames.removeFirst(oldestNeeded)
      }
    }
  }

  private func upscaled(_ image: CIImage, to extent: CGRect) -> CIImage {
    let source = image.extent
    guard source.width > 0, source.height > 0, source.size != extent.size else { return image }
    return image.samplingLinear().transformed(
      by: CGAffineTransform(
        scaleX: extent.width / source.width, y: extent.height / source.height))
  }

  private func render(_ image: CIImage, size: CGSize) -> CVPixelBuffer? {
    if outputPool == nil || outputSize != size {
      outputPool = Self.makePool(size: size)
      outputSize = size
    }
    guard let pool = outputPool else { return nil }
    var buffer: CVPixelBuffer?
    guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess,
      let buffer
    else { return nil }
    context.render(image, to: buffer)
    return buffer
  }

  /// A pool of BGRA, IOSurface-backed buffers, the shape the Flutter texture
  /// uploads without a copy.
  private static func makePool(size: CGSize) -> CVPixelBufferPool? {
    let attributes: [String: Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
      kCVPixelBufferWidthKey as String: Int(size.width),
      kCVPixelBufferHeightKey as String: Int(size.height),
      kCVPixelBufferIOSurfacePropertiesKey as String: [:],
      kCVPixelBufferMetalCompatibilityKey as String: true,
    ]
    var pool: CVPixelBufferPool?
    CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &pool)
    return pool
  }
}

/// When frame effects over a held frame are drawn at the clock's time instead
/// of the frame's own.
///
/// A still — a freeze frame, a long stop-motion hold — is encoded as one
/// sample lasting its whole length, while the export draws effects on every
/// frame of it. Drawn at the still's own time, they stood still with it.
enum HeldFrameEffects {
  /// How long a frame may stand while the clock runs before effects take the
  /// clock's time. Footage at 17 fps or more replaces its frames inside it
  /// and keeps their own time. A slow-motion clip, or a frame the decoder is
  /// late with, stands longer and is treated like a still.
  static let afterUs: Int64 = 60_000

  /// Spacing of redraws over a held frame the output hands over nothing new
  /// for, the 30 fps the export draws effects at. A little under a frame's
  /// 33.3 ms so a late display tick cannot push a redraw to the tick after:
  /// it lands on every second tick at 60 Hz, third at 90 Hz, fourth at 120 Hz.
  static let intervalUs: Int64 = 30_000

  /// The time effects are drawn at over a frame from `frameUs` shown at
  /// `itemUs`, given they were last drawn at `drawnUs` since the last flush.
  ///
  /// A frame shown well past its own time is held: a device's output hands
  /// over nothing new, the simulator's and macOS's the same frame on every
  /// tick, and a paused seek can land inside a still. A frame behind
  /// `drawnUs`, decoded late after a hold, takes the clock's time as well:
  /// its own would count as a jump back, and the effects would start over.
  static func timeUs(frameUs: Int64, itemUs: Int64, drawnUs: Int64?) -> Int64 {
    if itemUs - frameUs >= afterUs { return itemUs }
    if let drawnUs, frameUs < drawnUs, itemUs >= drawnUs { return itemUs }
    return frameUs
  }

  /// The time to draw effects at again over the frame from `heldUs`, last
  /// drawn at `drawnUs`, with the clock at `nowUs`; `nil` while it is too
  /// soon, either for the frame to count as held or since the last draw.
  static func redrawTimeUs(heldUs: Int64, drawnUs: Int64, nowUs: Int64) -> Int64? {
    guard nowUs - heldUs >= afterUs, nowUs - drawnUs >= intervalUs else { return nil }
    return nowUs
  }
}

extension CMTime {
  /// This time in microseconds, or `nil` when it is not a number: an
  /// invalid or indefinite time has NaN seconds, which no integer holds.
  var microseconds: Int64? {
    guard isNumeric else { return nil }
    return Int64((CMTimeGetSeconds(self) * 1_000_000).rounded())
  }
}
