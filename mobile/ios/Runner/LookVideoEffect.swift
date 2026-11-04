import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import divine_video_player
import pro_video_editor

#if os(iOS)
  import Flutter
#else
  import FlutterMacOS
#endif

/// A colour-graded look: every colour of the picture is mapped through the
/// look's 33×33×33 lookup table, as a film stock or a colourist's grade would
/// map it.
///
/// The table is the look's PNG in the Flutter assets, which
/// `tools/generate_looks.dart` writes: 33 slices of 33×33 side by side, one per
/// blue level, with red growing to the right and green downwards. Core Image's
/// `CIColorCube` applies it with trilinear interpolation, measured to within
/// 0.56/255 of a CPU reference, which the Android `LookVideoEffect` shader and
/// the picker tile's `shaders/look.frag` interpolate the same way. Every
/// context the preview and the export render in has no working colour space,
/// so the lookup and the mix run on the sRGB-encoded values, as on Android.
///
/// Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
/// much of the look is mixed over the picture), mixed with `CIMix`.
final class LookVideoEffect: CustomVideoEffectRenderer, VideoFrameEffect {
  /// Each look, under the id the Dart `CustomVideoEffect` names; the raw
  /// value is the name of its table.
  enum Look: String, CaseIterable {
    case tealOrange = "teal_orange"
    case warmFilm = "warm_film"
    case slideFilm = "slide_film"
    case coolFilm = "cool_film"
    case matte = "matte"
    case bleachBypass = "bleach_bypass"
    case crossProcess = "cross_process"
    case goldenHour = "golden_hour"
    case moonlight = "moonlight"
    case silver = "silver"

    /// The id the Dart `CustomVideoEffect` names.
    var id: String { "divine.look.\(self)" }
  }

  /// Points per side of a look's table.
  static let points = 33

  let historyOffsetsUs: [Int64] = []
  let historyScale = 1.0

  private let look: Look
  private let intensity: Double

  init(look: Look, params: [String: Any]) {
    self.look = look
    intensity = ShaderVideoEffect.readIntensity(params)
  }

  /// Registers every look, each under its own id, for exports and for the
  /// editor preview.
  static func register() {
    for look in Look.allCases {
      CustomVideoEffects.register(look.id) { params in LookVideoEffect(look: look, params: params) }
      VideoFrameEffects.register(look.id) { params in LookVideoEffect(look: look, params: params) }
    }
  }

  func render(_ frame: CustomVideoEffectFrame) -> CIImage {
    grade(frame.image)
  }

  func render(_ image: CIImage, history: [CIImage?], timeUs: Int64, effectTimeUs: Int64)
    -> CIImage
  {
    grade(image)
  }

  private func grade(_ image: CIImage) -> CIImage {
    guard intensity > 0, let cube = Self.cube(of: look) else { return image }
    let graded = image.applyingFilter(
      "CIColorCube",
      parameters: ["inputCubeDimension": Self.points, "inputCubeData": cube])
    guard intensity < 1 else { return graded }
    return graded.applyingFilter(
      "CIMix",
      parameters: [kCIInputBackgroundImageKey: image, kCIInputAmountKey: intensity])
  }

  private static let lock = NSLock()
  private static var cubes: [Look: Data] = [:]

  /// The table of `look` as `CIColorCube` data, read on first use, or `nil`
  /// when the app does not carry it.
  static func cube(of look: Look) -> Data? {
    lock.lock()
    defer { lock.unlock() }
    if let cube = cubes[look] { return cube }
    guard let url = tableURL(of: look), let cube = cubeData(fromTableAt: url) else { return nil }
    cubes[look] = cube
    return cube
  }

  /// Where the Flutter assets hold the table of `look`: in the main bundle
  /// on iOS, in the Flutter app framework on macOS.
  private static func tableURL(of look: Look) -> URL? {
    let key = FlutterDartProject.lookupKey(forAsset: "assets/looks/\(look.rawValue).png")
    return [Bundle.main, Bundle(identifier: "io.flutter.flutter.app")]
      .lazy
      .compactMap { $0?.url(forResource: key, withExtension: nil) }
      .first
  }

  /// Reads a table PNG into `CIColorCube` data: RGBA floats, red changing
  /// fastest, then green, then blue.
  ///
  /// The PNG carries no colour profile. It is drawn into a bitmap of its own
  /// colour space, so Core Graphics converts nothing and the values stay
  /// exactly as the file holds them.
  static func cubeData(fromTableAt url: URL) -> Data? {
    let width = points * points
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
      image.width == width, image.height == points,
      let space = image.colorSpace,
      let context = CGContext(
        data: nil, width: width, height: points, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: space,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
      let pixels = context.data
    else { return nil }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: points))
    // The bitmap's first row is the top of the image: green 0.
    let bytes = pixels.bindMemory(to: UInt8.self, capacity: width * points * 4)
    var cube = [Float](repeating: 1, count: points * points * points * 4)
    for b in 0..<points {
      for g in 0..<points {
        for r in 0..<points {
          let from = (g * width + b * points + r) * 4
          let to = ((b * points + g) * points + r) * 4
          for channel in 0..<3 {
            cube[to + channel] = Float(bytes[from + channel]) / 255
          }
        }
      }
    }
    return cube.withUnsafeBufferPointer { Data(buffer: $0) }
  }
}
