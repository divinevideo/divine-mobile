import CoreImage
import Foundation
import Metal
import divine_video_player
import pro_video_editor

/// The Adjust controls a colour matrix cannot draw (#10392): highlights,
/// shadows, vibrance and sharpening.
///
/// A matrix changes every pixel the same way, but these depend on each
/// pixel's own brightness or saturation, or on its neighbours. Sharpening adds
/// back the difference between a pixel's brightness and a small blur of it,
/// but never past the brightest or darkest pixel it sampled, so hard edges get
/// no halo. Shadows and highlights move the brightness along a curve that leaves black
/// and white in place, scaling red, green and blue alike so the colour stays.
/// Vibrance saturates dull colours more than strong ones and mostly spares
/// skin tones.
///
/// Core Image ships stock filters for all four, but Android has none of
/// them to match, and `CIHighlightShadowAdjust` pushes white past 1 when it
/// lifts shadows and greys it out at the strongest highlight setting. So a
/// `CIImageProcessorKernel` runs a plain Metal compute shader instead, which
/// compiles on every device, as ``DropsVideoEffect`` does. The shader is the
/// Android `AdjustVideoEffect`'s, line for line.
///
/// Its params, from the Dart `CustomVideoEffect`, are `highlights`, `shadows`
/// and `vibrance` (-1 to 1) and `sharpen` (0 to 1); a missing one is 0.
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
          AdjustKernel.valuesKey: [
            settings.highlights, settings.shadows, settings.vibrance, settings.sharpen,
          ],
        ])
    } catch {
      // Only malformed arguments throw here, and these are always complete.
      return image
    }
  }
}

/// The four values, each from -1 to 1 except ``sharpen``, from 0 to 1. The
/// Dart `AdjustVideoEffect` writes them.
struct AdjustSettings {
  /// Below 0 darkens bright areas, above 0 brightens them.
  var highlights = 0.0
  /// Above 0 lifts dark areas, below 0 deepens them.
  var shadows = 0.0
  /// Above 0 strengthens dull colours, below 0 mutes strong ones.
  var vibrance = 0.0
  /// How strongly fine detail is crisped up.
  var sharpen = 0.0

  init() {}

  init(params: [String: Any]) {
    func value(_ key: String, min: Double) -> Double {
      Swift.min(1, Swift.max(min, (params[key] as? NSNumber)?.doubleValue ?? 0))
    }
    highlights = value("highlights", min: -1)
    shadows = value("shadows", min: -1)
    vibrance = value("vibrance", min: -1)
    sharpen = value("sharpen", min: 0)
  }

  /// Whether the effect leaves every pixel as it is.
  var isNeutral: Bool { highlights == 0 && shadows == 0 && vibrance == 0 && sharpen == 0 }
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
    max(1, 1.5 * min(extent.width, extent.height) / 1080)
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
    guard settings.count == 4 else { return }

    let pipeline = try pipeline(for: commandBuffer.device)
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
    var values: [Float] = [
      Float(extent.minX), Float(extent.minY), Float(extent.width), Float(extent.height),
      Float(output.region.minX), Float(output.region.minY),
      Float(input.region.minX), Float(input.region.minY),
      Float(input.region.width), Float(input.region.height), 0, 0,
    ] + settings.map(Float.init)
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

  /// `p` is in pixels with y up, from the frame's bottom left.
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
      target.write(float4(color, 1.0), gid);
    }
    """
}
