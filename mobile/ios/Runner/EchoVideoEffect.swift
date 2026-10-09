import CoreImage
import Foundation
import divine_video_player
import pro_video_editor

/// The echo trail (#9708): moving subjects leave fading copies of where they
/// were 100 ms, 200 ms, ... ago, as many as the intensity asks for.
///
/// Every copy is an earlier source frame of the same clip, which
/// pro_video_editor hands over, so the export looks the same however the clip
/// was played or seeked before. Mirrors the Android `EchoVideoEffect`.
///
/// The editor preview draws the same blend through divine_video_player,
/// whose earlier frames come from what the player showed while playing.
///
/// Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1):
/// more and stronger copies. Each copy lightens the frame, so the subject
/// stays solid where the copies overlap it.
final class EchoVideoEffect: CustomVideoEffectRenderer, VideoFrameEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.echo"

  private static let defaultIntensity = 0.7
  private static let spacingUs: Int64 = 100_000
  // Matches Android, where the frame and its copies share eight texture units.
  private static let maxCopies = 7

  let historyOffsetsUs: [Int64]

  // The copies fade anyway; Android keeps them at half size, so do the same.
  let historyScale = 0.5

  /// The weight of each copy, newest first: stronger copies, fading slower.
  private let weights: [CGFloat]

  init(params: [String: Any]) {
    let intensity = min(
      1, max(0, (params["intensity"] as? NSNumber)?.doubleValue ?? Self.defaultIntensity))
    let copies = min(Self.maxCopies, max(1, Int((1 + 6 * intensity).rounded())))
    historyOffsetsUs = (1...copies).map { Int64($0) * Self.spacingUs }
    weights = (0..<copies).map { k in
      CGFloat((0.25 + 0.55 * intensity) * pow(0.55 + 0.25 * intensity, Double(k)))
    }
  }

  /// Registers the effect for exports and for the editor preview.
  static func register() {
    CustomVideoEffects.register(id) { params in EchoVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in EchoVideoEffect(params: params) }
  }

  func render(_ frame: CustomVideoEffectFrame) -> CIImage {
    blend(frame.image, frame.history)
  }

  func render(_ image: CIImage, history: [CIImage?], timeUs: Int64, effectTimeUs: Int64)
    -> CIImage
  {
    blend(image, history)
  }

  /// Oldest copy first: each pixel moves by its weight towards the brighter
  /// of itself and the copy, `mix(color, max(color, copy), weight)`.
  private func blend(_ image: CIImage, _ history: [CIImage?]) -> CIImage {
    var color = image
    for (k, copy) in history.enumerated().reversed() {
      guard let copy else { continue }
      let brighter = copy.applyingFilter(
        "CILightenBlendMode", parameters: [kCIInputBackgroundImageKey: color])
      color = mix(color, brighter, weights[k])
    }
    return color
  }

  /// `from` moved by `amount` towards `to`, both opaque.
  private func mix(_ from: CIImage, _ to: CIImage, _ amount: CGFloat) -> CIImage {
    from.applyingFilter(
      "CIDissolveTransition",
      parameters: [kCIInputTargetImageKey: to, kCIInputTimeKey: amount])
  }
}
