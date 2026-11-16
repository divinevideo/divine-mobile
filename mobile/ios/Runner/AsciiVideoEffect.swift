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

/// ASCII: the picture redrawn in characters on black, in a grid of square
/// cells.
///
/// Each cell shows the glyph whose ink matches the cell's brightness, from the
/// glyph atlas in the Flutter assets, which `tools/generate_ascii_glyphs.dart`
/// writes: ten glyphs of 24×24 side by side, emptiest first. It is uploaded as
/// a second texture and read with bilinear filtering, as the Android
/// `AsciiVideoEffect` and the picker tile's `shaders/ascii.frag` read it. The
/// glyph is drawn in the cell's colour brightened to full strength, so the
/// glyphs carry the brightness and the colour stays clear.
///
/// Its one param, from the Dart `CustomVideoEffect`, is `intensity` (0–1: how
/// far the picture turns into characters).
final class AsciiVideoEffect: ShaderVideoEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.ascii"

  /// The glyph atlas in the Flutter assets.
  static let asset = "assets/effects/ascii_glyphs.png"

  private let intensity: Double

  init(params: [String: Any]) {
    intensity = Self.readIntensity(params)
    super.init(function: Self.function, source: Self.source)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in AsciiVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in AsciiVideoEffect(params: params) }
    ShaderVideoEffectKernel.prepare(function: function, source: source)
  }

  /// Leaves the frame as it is when the app does not carry the atlas.
  override func values(effectTimeUs: Int64) -> [Double]? {
    intensity > 0 && Self.glyphs() != nil ? [intensity] : nil
  }

  override func textures() -> [CIImage] {
    Self.glyphs().map { [$0] } ?? []
  }

  private static let lock = NSLock()
  private static var cached: CIImage?

  /// The glyph atlas, read on first use, or `nil` when the app does not
  /// carry it.
  static func glyphs() -> CIImage? {
    lock.lock()
    defer { lock.unlock() }
    if let cached { return cached }
    let key = FlutterDartProject.lookupKey(forAsset: asset)
    guard
      let url = [Bundle.main, Bundle(identifier: "io.flutter.flutter.app")]
        .lazy
        .compactMap({ $0?.url(forResource: key, withExtension: nil) })
        .first,
      let image = glyphs(fromAtlasAt: url)
    else { return nil }
    cached = image
    return image
  }

  /// Reads an atlas PNG into an image of exactly the values it holds.
  ///
  /// The PNG carries no colour profile. It is drawn into a bitmap of its own
  /// colour space, so Core Graphics converts nothing, and the image is made
  /// without a colour space, so Core Image converts nothing either.
  static func glyphs(fromAtlasAt url: URL) -> CIImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
      let space = image.colorSpace,
      let context = CGContext(
        data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
        bytesPerRow: image.width * 4, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
      let pixels = context.data
    else { return nil }
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return CIImage(
      bitmapData: Data(bytes: pixels, count: image.width * image.height * 4),
      bytesPerRow: image.width * 4,
      size: CGSize(width: image.width, height: image.height),
      format: .RGBA8,
      colorSpace: nil)
  }

  static let function = "divineAscii"

  /// `s` is the frame's shorter side and `c` a cell's side, in pixels. The
  /// kernel reads the atlas top row first, the glyphs' top. The cell's colour
  /// is the mean of four taps inside it, which steadies the glyphs against
  /// noise.
  static let source = """
    constant float kGlyphs = 10.0;
    constant float kGlyphSize = 24.0;

    static float luma(float3 c) {
      return dot(c, float3(0.299, 0.587, 0.114));
    }

    kernel void divineAscii(
      texture2d<float, access::sample> frame [[texture(0)]],
      texture2d<float, access::write> target [[texture(1)]],
      texture2d<float, access::sample> glyphs [[texture(2)]],
      constant float4 *u [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
    ) {
      if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
      Frame f = frameOf(u);
      float intensity = u[3].x;
      float2 p = pixelOf(u, gid, target.get_height());
      float s = min(f.size.x, f.size.y);
      float c = max(8.0, s / 60.0);
      float2 cell = floor(p / c);
      float2 middle = (cell + 0.5) * c;
      float3 ink = 0.25 * (tap(frame, f, middle + float2(-0.25, -0.25) * c) + tap(frame, f, middle + float2(0.25, -0.25) * c) +
        tap(frame, f, middle + float2(-0.25, 0.25) * c) + tap(frame, f, middle + float2(0.25, 0.25) * c));
      float level = min(floor(luma(ink) * kGlyphs), kGlyphs - 1.0);
      float2 inCell = p / c - cell;
      float2 texel = clamp(float2(inCell.x, 1.0 - inCell.y) * kGlyphSize, 0.5, kGlyphSize - 0.5);
      float2 atlas = float2(kGlyphs * kGlyphSize, kGlyphSize);
      float glyph = glyphs.sample(linearClamp, float2(level * kGlyphSize + texel.x, texel.y) / atlas).r;
      float hi = max(max(ink.r, ink.g), ink.b);
      float3 ascii = clamp(ink / max(hi, 0.25), 0.0, 1.0) * glyph;
      target.write(float4(mix(tap(frame, f, p), ascii, intensity), 1.0), gid);
    }
    """
}
