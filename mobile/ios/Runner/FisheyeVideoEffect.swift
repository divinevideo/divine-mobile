import CoreImage
import Foundation
import divine_video_player
import pro_video_editor

/// The fisheye: the middle of the picture bulges out, as through a wide-angle
/// lens, while the corners stay where they are.
///
/// Drawn with Core Image's `CIBumpDistortion` around the centre, with the
/// radius at half the frame's diagonal, so the whole picture bulges and the
/// corners stay put. Runtime Metal kernels need an A13 or later, so a stock
/// filter is the only bulge every supported device can draw. Its mapping,
/// measured to within 0.002 px,
///
///     source = centre + offset * (1 - scale * (1 - smoothstep(0, 1, t)))
///
/// with t the distance from the centre over the radius, is what the Android
/// `FisheyeVideoEffect` draws in its shader.
///
/// Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1):
/// how far the middle bulges out.
final class FisheyeVideoEffect: CustomVideoEffectRenderer, VideoFrameEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.fisheye"

  private static let defaultIntensity = 0.7
  /// The bump scale at intensity 1; 1 would pinch the centre to a point.
  private static let maxScale = 0.8

  let historyOffsetsUs: [Int64] = []
  let historyScale = 1.0

  private let scale: Double

  init(params: [String: Any]) {
    let intensity = min(
      1, max(0, (params["intensity"] as? NSNumber)?.doubleValue ?? Self.defaultIntensity))
    scale = Self.maxScale * intensity
  }

  /// Registers the effect for exports and for the editor preview.
  static func register() {
    CustomVideoEffects.register(id) { params in FisheyeVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in FisheyeVideoEffect(params: params) }
  }

  func render(_ frame: CustomVideoEffectFrame) -> CIImage {
    bulge(frame.image)
  }

  func render(_ image: CIImage, history: [CIImage?], timeUs: Int64, effectTimeUs: Int64)
    -> CIImage
  {
    bulge(image)
  }

  private func bulge(_ image: CIImage) -> CIImage {
    let extent = image.extent
    guard scale > 0, !extent.isEmpty, !extent.isInfinite else { return image }
    // Every pixel samples closer to the centre, so the clamp only keeps the
    // edge pixels from blending with the transparency outside the frame.
    return image.clampedToExtent().applyingFilter(
      "CIBumpDistortion",
      parameters: [
        kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
        kCIInputRadiusKey: hypot(extent.width, extent.height) / 2,
        kCIInputScaleKey: scale,
      ]
    ).cropped(to: extent)
  }
}
