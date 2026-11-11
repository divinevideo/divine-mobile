import CoreImage
import Foundation
import Metal
import divine_video_player
import pro_video_editor

/// The Adjust controls a colour matrix cannot draw (#10392): highlights,
/// shadows, vibrance, sharpening, the Color section's per-colour hue,
/// saturation and lightness, and the tone curve (#10871).
///
/// A matrix changes every pixel the same way, but these depend on each
/// pixel's own brightness, hue or saturation, or on its neighbours. Sharpening
/// adds back the difference between a pixel's brightness and a small blur of
/// it, but never past the brightest or darkest pixel it sampled, so hard edges
/// get no halo. Shadows and highlights move the brightness along a curve that
/// leaves black and white in place, scaling red, green and blue alike so the
/// colour stays. The tone curve maps each channel through a smooth curve
/// through five points that never overshoots them, first the master curve,
/// then the channel's own. Vibrance saturates dull colours more than strong
/// ones and mostly spares skin tones. The Color section turns, mutes or
/// strengthens, and darkens or lightens each of eight colour bands, which
/// blend into each other so no hue edge shows.
///
/// Core Image ships stock filters for all four, but Android has none of
/// them to match, and `CIHighlightShadowAdjust` pushes white past 1 when it
/// lifts shadows and greys it out at the strongest highlight setting. So a
/// `CIImageProcessorKernel` runs a plain Metal compute shader instead, which
/// compiles on every device, as ``DropsVideoEffect`` does. The shader is the
/// Android `AdjustVideoEffect`'s, line for line.
///
/// Its params, from the Dart `CustomVideoEffect`, are `highlights`, `shadows`
/// and `vibrance` (-1 to 1), `sharpen` (0 to 1), a hue, saturation and
/// lightness per colour band, like `redHue` (-1 to 1), and a value per tone
/// curve point, like `curveRgbShadows` (how far the point's output sits above
/// its input level); a missing one is 0.
final class AdjustVideoEffect: CustomVideoEffectRenderer, VideoFrameEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.adjust"

  let historyOffsetsUs: [Int64] = []
  let historyScale = 1.0

  private let settings: AdjustSettings

  init(params: [String: Any]) {
    settings = AdjustSettings(params: params)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in AdjustVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in AdjustVideoEffect(params: params) }
    AdjustKernel.prepare()
  }

  func render(_ frame: CustomVideoEffectFrame) -> CIImage {
    adjust(frame.image)
  }

  func render(_ image: CIImage, history: [CIImage?], timeUs: Int64, effectTimeUs: Int64)
    -> CIImage
  {
    adjust(image)
  }

  private func adjust(_ image: CIImage) -> CIImage {
    let extent = image.extent
    guard !settings.isNeutral, !extent.isEmpty, !extent.isInfinite else { return image }
    do {
      return try AdjustKernel.apply(
        withExtent: extent,
        inputs: [image],
        arguments: [
          AdjustKernel.extentKey: CIVector(cgRect: extent),
          AdjustKernel.valuesKey: settings.kernelValues,
        ])
    } catch {
      // Only malformed arguments throw here, and these are always complete.
      return image
    }
  }
}

/// The values the effect draws with, each kept in its range. The Dart
/// `AdjustVideoEffect` writes them.
struct AdjustSettings {
  /// The colour bands, in hue order, as the Dart `AdjustColorBand` names them.
  static let bands = ["red", "orange", "yellow", "green", "aqua", "blue", "purple", "magenta"]

  /// The tone curves, as their params name them after `curve`.
  static let curveNames = ["Rgb", "Red", "Green", "Blue"]

  /// A curve's points from black to white, as their params name them last.
  static let curvePoints = ["Blacks", "Shadows", "Midtones", "Highlights", "Whites"]

  /// Below 0 darkens bright areas, above 0 brightens them.
  let highlights: Double
  /// Above 0 lifts dark areas, below 0 deepens them.
  let shadows: Double
  /// Above 0 strengthens dull colours, below 0 mutes strong ones.
  let vibrance: Double
  /// How strongly fine detail is crisped up.
  let sharpen: Double
  /// Per band, in ``bands`` order, from -1 to 1: below 0 turns it towards the
  /// band before, above 0 towards the band after, by up to 30°.
  let hue: [Double]
  /// Per band, from -1 (grey) to 1 (twice as strong).
  let saturation: [Double]
  /// Per band, from -1 (darker) to 1 (lighter).
  let lightness: [Double]
  /// Per curve, in ``curveNames`` order, how far each point's output sits
  /// above its input level, from black to white.
  let curves: [[Double]]

  init(params: [String: Any]) {
    func value(_ key: String, min: Double, max: Double = 1) -> Double {
      Swift.min(max, Swift.max(min, (params[key] as? NSNumber)?.doubleValue ?? 0))
    }
    highlights = value("highlights", min: -1)
    shadows = value("shadows", min: -1)
    vibrance = value("vibrance", min: -1)
    sharpen = value("sharpen", min: 0)
    hue = Self.bands.map { value("\($0)Hue", min: -1) }
    saturation = Self.bands.map { value("\($0)Saturation", min: -1) }
    lightness = Self.bands.map { value("\($0)Lightness", min: -1) }
    let last = Double(Self.curvePoints.count - 1)
    curves = Self.curveNames.map { curve in
      Self.curvePoints.enumerated().map { point, name in
        let x = Double(point) / last
        return value("curve\(curve)\(name)", min: -x, max: 1 - x)
      }
    }
  }

  /// How many values ``kernelValues`` holds.
  static let kernelValueCount = 4 + 3 * bands.count + curveNames.count * curvePoints.count

  /// Whether the effect leaves every pixel as it is.
  var isNeutral: Bool { kernelValues.allSatisfy { $0 == 0 } }

  /// The values as the kernel reads them, four at a time: highlights,
  /// shadows, vibrance and sharpen; the hue of bands 0–3 and 4–7, then their
  /// saturation and lightness; each curve's points below white; and the
  /// curves' white points.
  var kernelValues: [Double] {
    var values = [highlights, shadows, vibrance, sharpen]
    values += hue
    values += saturation
    values += lightness
    values += curves.flatMap { $0.dropLast() }
    values += curves.map { $0.last ?? 0 }
    return values
  }
}

/// Runs the Metal shader on a frame inside the Core Image graph.
final class AdjustKernel: CIImageProcessorKernel {
  static let extentKey = "extent"
  static let valuesKey = "values"

  private enum Failure: Error {
    case noMetal
    case missingFunction
  }

  private static let lock = NSLock()
  private static var pipelines: [ObjectIdentifier: MTLComputePipelineState] = [:]

  /// Compiles the shader for the default device in the background, so the
  /// first frame does not wait for it.
  static func prepare() {
    DispatchQueue.global(qos: .utility).async {
      guard let device = MTLCreateSystemDefaultDevice() else { return }
      _ = try? pipeline(for: device)
    }
  }

  /// How far the sharpening blur reaches from a pixel: 1.5 px on a 1080p
  /// frame, more on larger ones, so a video looks as sharp after it at any
  /// resolution.
  static func spacing(for extent: CGRect) -> Double {
    let shorterSide = Double(min(extent.width, extent.height))
    return max(1, 1.5 * shorterSide / 1080)
  }

  // Half floats keep the frame's precision, and every Apple GPU filters them;
  // 32-bit float textures are not filterable on all of them.
  override class func formatForInput(at input: Int32) -> CIFormat { .RGBAh }

  override class var outputFormat: CIFormat { .RGBAh }

  /// The output region and the ring the sharpening blur samples around it.
  override class func roi(forInput input: Int32, arguments: [String: Any]?, outputRect: CGRect)
    -> CGRect
  {
    guard let extent = (arguments?[extentKey] as? CIVector)?.cgRectValue else {
      return outputRect
    }
    let reach = CGFloat(spacing(for: extent).rounded(.up) + 1)
    return outputRect.insetBy(dx: -reach, dy: -reach).intersection(extent)
  }

  override class func process(
    with inputs: [CIImageProcessorInput]?, arguments: [String: Any]?,
    output: CIImageProcessorOutput
  ) throws {
    guard let input = inputs?.first,
      let source = input.metalTexture,
      let target = output.metalTexture,
      let commandBuffer = output.metalCommandBuffer
    else { throw Failure.noMetal }
    let extent = (arguments?[extentKey] as? CIVector)?.cgRectValue ?? input.region
    let settings = (arguments?[valuesKey] as? [Double]) ?? []
    guard settings.count == AdjustSettings.kernelValueCount else { return }

    let pipeline = try pipeline(for: commandBuffer.device)
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
    var values: [Float] = [
      Float(extent.minX), Float(extent.minY), Float(extent.width), Float(extent.height),
      Float(output.region.minX), Float(output.region.minY),
      Float(input.region.minX), Float(input.region.minY),
      Float(input.region.width), Float(input.region.height), 0, 0,
    ]
    values += settings.map { Float($0) }
    encoder.setComputePipelineState(pipeline)
    encoder.setTexture(source, index: 0)
    encoder.setTexture(target, index: 1)
    encoder.setBytes(&values, length: values.count * MemoryLayout<Float>.size, index: 0)
    let width = pipeline.threadExecutionWidth
    let height = max(1, pipeline.maxTotalThreadsPerThreadgroup / width)
    encoder.dispatchThreadgroups(
      MTLSize(
        width: (target.width + width - 1) / width,
        height: (target.height + height - 1) / height,
        depth: 1),
      threadsPerThreadgroup: MTLSize(width: width, height: height, depth: 1))
    encoder.endEncoding()
  }

  static func pipeline(for device: MTLDevice) throws -> MTLComputePipelineState {
    lock.lock()
    defer { lock.unlock() }
    if let pipeline = pipelines[ObjectIdentifier(device)] { return pipeline }
    let library = try device.makeLibrary(source: source, options: nil)
    guard let function = library.makeFunction(name: "divineAdjust") else {
      throw Failure.missingFunction
    }
    let pipeline = try device.makeComputePipelineState(function: function)
    pipelines[ObjectIdentifier(device)] = pipeline
    return pipeline
  }

  /// `p` is in pixels with y up, from the frame's bottom left. Hues are in
  /// degrees. `u[3]` holds highlights, shadows, vibrance and sharpen;
  /// `u[4]`–`u[9]` the bands' hue, saturation and lightness, four bands each;
  /// `u[10]`–`u[13]` the master, red, green and blue curves' points below
  /// white, and `u[14]` their white points.
  static let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct Frame {
      float2 origin;
      float2 size;
      float2 inputOrigin;
      float2 inputSize;
    };

    constexpr sampler linearClamp(coord::normalized, address::clamp_to_edge, filter::linear);
    constant float3 kLuma = float3(0.2126, 0.7152, 0.0722);

    static float3 tap(texture2d<float, access::sample> frame, Frame f, float2 q) {
      q = clamp(q, float2(0.5), f.size - 0.5);
      float2 uv = (q + f.origin - f.inputOrigin) / f.inputSize;
      return frame.sample(linearClamp, float2(uv.x, 1.0 - uv.y)).rgb;
    }

    static float luma(texture2d<float, access::sample> frame, Frame f, float2 q) {
      return dot(tap(frame, f, q), kLuma);
    }

    static float slope(float before, float after) {
      return (sign(before) + sign(after)) * min(min(abs(before), abs(after)), 0.25 * abs(before + after));
    }

    static float curve(float x, float4 points, float whites) {
      if (all(points == 0.0) && whites == 0.0) return x;
      float y0 = clamp(points.x, 0.0, 1.0);
      float y1 = clamp(0.25 + points.y, 0.0, 1.0);
      float y2 = clamp(0.5 + points.z, 0.0, 1.0);
      float y3 = clamp(0.75 + points.w, 0.0, 1.0);
      float y4 = clamp(1.0 + whites, 0.0, 1.0);
      float d0 = 4.0 * (y1 - y0);
      float d1 = 4.0 * (y2 - y1);
      float d2 = 4.0 * (y3 - y2);
      float d3 = 4.0 * (y4 - y3);
      float s = clamp(x, 0.0, 1.0) * 4.0;
      float k = min(floor(s), 3.0);
      float t = s - k;
      float ya = y3;
      float yb = y4;
      float ma = slope(d2, d3);
      float mb = d3;
      if (k < 0.5) {
        ya = y0; yb = y1; ma = d0; mb = slope(d0, d1);
      } else if (k < 1.5) {
        ya = y1; yb = y2; ma = slope(d0, d1); mb = slope(d1, d2);
      } else if (k < 2.5) {
        ya = y2; yb = y3; ma = slope(d1, d2); mb = slope(d2, d3);
      }
      float t2 = t * t;
      float t3 = t2 * t;
      float y = (2.0 * t3 - 3.0 * t2 + 1.0) * ya + (t3 - 2.0 * t2 + t) * 0.25 * ma
        + (3.0 * t2 - 2.0 * t3) * yb + (t3 - t2) * 0.25 * mb;
      return clamp(y, 0.0, 1.0);
    }

    static float band(float hue, float before, float centre, float after) {
      if (hue < before || hue > after) return 0.0;
      float t = hue < centre ? (hue - before) / (centre - before) : (after - hue) / (after - centre);
      return t * t * (3.0 - 2.0 * t);
    }

    static float3 fromHsl(float hue, float saturation, float lightness) {
      float3 k = float3(0.0, 8.0, 4.0) + hue / 30.0;
      k = k - 12.0 * floor(k / 12.0);
      float a = saturation * min(lightness, 1.0 - lightness);
      return lightness - a * clamp(min(k - 3.0, 9.0 - k), -1.0, 1.0);
    }

    static float3 mixColors(float3 color, constant float4 *u) {
      float hi = max(color.r, max(color.g, color.b));
      float lo = min(color.r, min(color.g, color.b));
      float chroma = hi - lo;
      if (chroma < 0.00001) return color;
      float lightness = (hi + lo) * 0.5;
      float saturation = min(chroma / (1.0 - abs(2.0 * lightness - 1.0)), 1.0);
      float hue = hi == color.r ? (color.g - color.b) / chroma
        : hi == color.g ? (color.b - color.r) / chroma + 2.0
        : (color.r - color.g) / chroma + 4.0;
      hue *= 60.0;
      if (hue < 0.0) hue += 360.0;
      float redHue = hue > 180.0 ? hue - 360.0 : hue;
      float4 a = float4(
        band(redHue, -60.0, 0.0, 30.0),
        band(hue, 0.0, 30.0, 60.0),
        band(hue, 30.0, 60.0, 120.0),
        band(hue, 60.0, 120.0, 180.0));
      float4 b = float4(
        band(hue, 120.0, 180.0, 240.0),
        band(hue, 180.0, 240.0, 270.0),
        band(hue, 240.0, 270.0, 300.0),
        band(hue, 270.0, 300.0, 360.0));
      float turn = dot(a, u[4]) + dot(b, u[5]);
      float strength = dot(a, u[6]) + dot(b, u[7]);
      float light = (dot(a, u[8]) + dot(b, u[9])) * smoothstep(0.0, 0.2, chroma);
      hue += 30.0 * turn;
      if (hue < 0.0) hue += 360.0;
      if (hue >= 360.0) hue -= 360.0;
      saturation = clamp(saturation * (1.0 + strength), 0.0, 1.0);
      lightness = light > 0.0 ? lightness + (1.0 - lightness) * light * 0.5 : lightness * (1.0 + light * 0.5);
      return clamp(fromHsl(hue, saturation, lightness), 0.0, 1.0);
    }

    kernel void divineAdjust(
      texture2d<float, access::sample> frame [[texture(0)]],
      texture2d<float, access::write> target [[texture(1)]],
      constant float4 *u [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
    ) {
      if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
      Frame f = { u[0].xy, u[0].zw, u[1].zw, u[2].xy };
      // The textures' first row is the top of their region, while Core
      // Image's y axis points up.
      float2 p = float2(
        u[1].x + float(gid.x) + 0.5,
        u[1].y + float(target.get_height()) - float(gid.y) - 0.5) - f.origin;
      float highlights = u[3].x;
      float shadows = u[3].y;
      float vibrance = u[3].z;
      float sharpen = u[3].w;
      float3 color = tap(frame, f, p);
      if (sharpen > 0.0) {
        float r = max(1.0, 1.5 * min(f.size.x, f.size.y) / 1080.0);
        float y = dot(color, kLuma);
        float e0 = luma(frame, f, p + float2(r, 0.0));
        float e1 = luma(frame, f, p - float2(r, 0.0));
        float e2 = luma(frame, f, p + float2(0.0, r));
        float e3 = luma(frame, f, p - float2(0.0, r));
        float c0 = luma(frame, f, p + float2(r, r));
        float c1 = luma(frame, f, p + float2(-r, r));
        float c2 = luma(frame, f, p + float2(r, -r));
        float c3 = luma(frame, f, p - float2(r, r));
        float blur = (4.0 * y + 2.0 * (e0 + e1 + e2 + e3) + c0 + c1 + c2 + c3) / 16.0;
        float lo = min(y, min(min(min(e0, e1), min(e2, e3)), min(min(c0, c1), min(c2, c3))));
        float hi = max(y, max(max(max(e0, e1), max(e2, e3)), max(max(c0, c1), max(c2, c3))));
        float sharp = clamp(y + 3.0 * sharpen * (y - blur), lo, hi);
        color = clamp(color + (sharp - y), 0.0, 1.0);
      }
      float l = dot(color, kLuma);
      float dark = 1.0 - l;
      float lows = l * dark * dark * dark * dark * 12.20703125;
      float highs = l * l * l * l * dark * 12.20703125;
      float toned = l
        + shadows * (shadows > 0.0 ? 0.2 : 0.065) * lows
        + highlights * (highlights < 0.0 ? 0.2 : 0.065) * highs;
      color = clamp(l > 0.0001 ? color * (toned / l) : color + (toned - l), 0.0, 1.0);
      color = float3(
        curve(curve(color.r, u[10], u[14].x), u[11], u[14].y),
        curve(curve(color.g, u[10], u[14].x), u[12], u[14].z),
        curve(curve(color.b, u[10], u[14].x), u[13], u[14].w));
      if (vibrance != 0.0) {
        float chroma = max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));
        float skin = 0.0;
        if (color.r >= color.g && color.g >= color.b && chroma > 0.0001) {
          float hue = (color.g - color.b) / chroma;
          skin = smoothstep(0.05, 0.25, hue) * (1.0 - smoothstep(0.6, 0.85, hue))
            * smoothstep(0.02, 0.08, chroma) * (1.0 - smoothstep(0.5, 0.75, chroma));
        }
        float keep = 1.0 - 0.85 * skin;
        float amount = vibrance > 0.0
          ? vibrance * 1.25 * (1.0 - chroma) * (1.0 - chroma) * keep
          : vibrance * (0.4 + 0.6 * chroma) * keep;
        float grey = dot(color, kLuma);
        color = clamp(grey + (color - grey) * (1.0 + amount), 0.0, 1.0);
      }
      if (any(u[4] != 0.0) || any(u[5] != 0.0) || any(u[6] != 0.0)
          || any(u[7] != 0.0) || any(u[8] != 0.0) || any(u[9] != 0.0)) {
        color = mixColors(color, u);
      }
      target.write(float4(color, 1.0), gid);
    }
    """
}
