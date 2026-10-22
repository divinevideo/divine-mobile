import CoreImage
import Foundation
import Metal
import divine_video_player
import pro_video_editor

/// Drops: clear glass drops drift over the picture and flow into each other
/// where they meet. Each drop bends the picture at its rim, with colour
/// fringes, frosts it, catches a highlight on its top left edge and casts a
/// soft shadow below.
///
/// No stock Core Image filter draws this, and runtime-compiled Core Image
/// Metal kernels need an A13 or later, so a `CIImageProcessorKernel` runs a
/// plain Metal compute shader on the frame instead. Plain Metal compiles on
/// every device. The shader is the Android `DropsVideoEffect`'s, line for line,
/// and so is `shaders/drops.frag`, which draws the effects picker's tile.
///
/// Its params, from the Dart `CustomVideoEffect`, are `intensity` (0–1: how
/// strongly the glass bends, lights and shades the picture) and the
/// ``DropsSettings``. The drops move with the time since the effect started,
/// so they follow the same path in the preview and in the export.
final class DropsVideoEffect: CustomVideoEffectRenderer, VideoFrameEffect {
  /// The id the Dart `CustomVideoEffect` names.
  static let id = "divine.drops"

  private static let defaultIntensity = 0.7

  let historyOffsetsUs: [Int64] = []
  let historyScale = 1.0

  private let intensity: Double
  private let settings: DropsSettings

  init(params: [String: Any]) {
    intensity = min(
      1, max(0, (params["intensity"] as? NSNumber)?.doubleValue ?? Self.defaultIntensity))
    settings = DropsSettings(params: params)
  }

  /// Registers the effect for exports and for the editor preview, and
  /// compiles its shader ahead of the first frame.
  static func register() {
    CustomVideoEffects.register(id) { params in DropsVideoEffect(params: params) }
    VideoFrameEffects.register(id) { params in DropsVideoEffect(params: params) }
    DropsKernel.prepare()
  }

  func render(_ frame: CustomVideoEffectFrame) -> CIImage {
    drops(frame.image, effectTimeUs: frame.effectTimeUs)
  }

  func render(_ image: CIImage, history: [CIImage?], timeUs: Int64, effectTimeUs: Int64)
    -> CIImage
  {
    drops(image, effectTimeUs: effectTimeUs)
  }

  private func drops(_ image: CIImage, effectTimeUs: Int64) -> CIImage {
    let extent = image.extent
    guard intensity > 0, !extent.isEmpty, !extent.isInfinite else { return image }
    let layout = DropsLayout.drops(settings, seconds: Double(effectTimeUs) / 1_000_000)
    do {
      return try DropsKernel.apply(
        withExtent: extent,
        inputs: [image],
        arguments: [
          DropsKernel.extentKey: CIVector(cgRect: extent),
          DropsKernel.valuesKey: [
            intensity, DropsLayout.scale(settings), settings.frost, settings.fringes,
          ] + layout.flatMap { [$0.x, $0.y, $0.radius] },
        ])
    } catch {
      // Only malformed arguments throw here, and these are always complete.
      return image
    }
  }
}

/// The drops' settings beyond the intensity, each from 0 to 1 except
/// [count] and [seed]. The Dart `DropsEffectSettings` writes them.
struct DropsSettings {
  /// How many drops show, 1 to ``DropsLayout/maxDrops``.
  var count = 3
  /// How large the drops are; 0.5 is the default size.
  var size = 0.5
  /// How fast they drift; 0 holds them still, 0.5 is the default pace.
  var speed = 0.5
  /// How frosted the glass is.
  var frost = 0.5
  /// How strongly red and blue part at the rims.
  var fringes = 0.5
  /// Which arrangement and paths the drops take; 0 is the default one.
  var seed = 0

  init() {}

  init(params: [String: Any]) {
    func unit(_ key: String, _ fallback: Double) -> Double {
      min(1, max(0, (params[key] as? NSNumber)?.doubleValue ?? fallback))
    }
    count = min(
      DropsLayout.maxDrops, max(1, (params["count"] as? NSNumber)?.intValue ?? count))
    size = unit("size", size)
    speed = unit("speed", speed)
    frost = unit("frost", frost)
    fringes = unit("fringes", fringes)
    seed = (params["seed"] as? NSNumber)?.intValue ?? seed
  }
}

/// Where the drops are. Mirrors the Android `DropsLayout` and the Dart
/// `dropsLayout`.
///
/// Each drop follows a path of its own, `0.5 + a · sin(f · t + phase)` along
/// each axis, where `t` is the time since the effect started times twice the
/// speed. The seed shifts every phase, which rearranges the drops and when
/// they meet without changing how they move.
enum DropsLayout {
  /// The most drops the effect draws.
  static let maxDrops = 5

  /// A drop: its centre as fractions of the frame's width and height, up
  /// from the bottom left, and its radius as a fraction of the shorter side.
  struct Drop: Equatable {
    let x: Double
    let y: Double
    let radius: Double
  }

  /// Per drop: frequency, phase and amplitude across, the same up, and the
  /// radius at the default size.
  private static let paths: [(Double, Double, Double, Double, Double, Double, Double)] = [
    (0.53, 0.0, 0.24, 0.41, 1.570796, 0.17, 0.17),
    (0.37, 2.1, 0.26, 0.29, 0.7, 0.21, 0.13),
    (0.45, 5.570796, 0.20, 0.51, 3.3, 0.19, 0.15),
    (0.31, 5.2, 0.22, 0.47, 1.9, 0.23, 0.11),
    (0.59, 0.4, 0.18, 0.33, 4.6, 0.16, 0.14),
  ]

  /// Where the drop that is not shown sits: far outside the frame.
  private static let hidden = Drop(x: -100, y: -100, radius: 0)

  /// How much larger than at the default size the drops, and everything
  /// around their rims, are drawn.
  static func scale(_ settings: DropsSettings) -> Double { 0.5 + settings.size }

  /// All ``maxDrops`` drops `seconds` into the effect; the ones past the
  /// settings' count are hidden.
  static func drops(_ settings: DropsSettings, seconds: Double) -> [Drop] {
    let t = seconds * 2 * settings.speed
    let seed = Double(settings.seed)
    return paths.enumerated().map { i, path in
      guard i < settings.count else { return hidden }
      let (fx, px, ax, fy, py, ay, r) = path
      let n = Double(i + 1)
      return Drop(
        x: 0.5 + ax * sin(fx * t + px + seed * 2.399963 * n),
        y: 0.5 + ay * sin(fy * t + py + seed * 1.618034 * n),
        radius: r * scale(settings))
    }
  }
}

/// Runs the drops shader on the frame's Metal texture, as a node of the
/// Core Image graph the preview and the export already render.
final class DropsKernel: CIImageProcessorKernel {
  static let extentKey = "extent"
  /// Intensity, scale, frost and fringes, then x, y and radius of each drop.
  static let valuesKey = "values"

  enum Failure: Error {
    /// The context rendering the frame does not run on Metal.
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

  // Half floats keep the frame's precision, and every Apple GPU filters them;
  // 32-bit float textures are not filterable on all of them.
  override class func formatForInput(at input: Int32) -> CIFormat { .RGBAh }

  override class var outputFormat: CIFormat { .RGBAh }

  /// The whole frame: the rim and the frost sample the picture around each
  /// pixel.
  override class func roi(forInput input: Int32, arguments: [String: Any]?, outputRect: CGRect)
    -> CGRect
  {
    (arguments?[extentKey] as? CIVector)?.cgRectValue ?? outputRect
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
    guard settings.count == 4 + 3 * DropsLayout.maxDrops else { return }

    let pipeline = try pipeline(for: commandBuffer.device)
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
    var values: [Float] = [
      Float(extent.minX), Float(extent.minY), Float(extent.width), Float(extent.height),
      Float(output.region.minX), Float(output.region.minY),
      Float(input.region.minX), Float(input.region.minY),
      Float(input.region.width), Float(input.region.height),
      Float(settings[0]), Float(settings[1]), Float(settings[2]), Float(settings[3]), 0, 0,
    ]
    for drop in 0..<DropsLayout.maxDrops {
      values += settings[(4 + 3 * drop)..<(7 + 3 * drop)].map(Float.init) + [0]
    }
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
    guard let function = library.makeFunction(name: "divineDrops") else {
      throw Failure.missingFunction
    }
    let pipeline = try device.makeComputePipelineState(function: function)
    pipelines[ObjectIdentifier(device)] = pipeline
    return pipeline
  }

  /// Distances are in pixels with y up, from the frame's bottom left; `s` is
  /// the frame's shorter side, and `z` scales everything around the drops'
  /// rims with their size.
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

    static float smin(float a, float b, float k) {
      float h = max(k - abs(a - b), 0.0) / k;
      return min(a, b) - h * h * k * 0.25;
    }

    // Signed distance to the glass, negative inside.
    static float glass(float2 p, thread const float3 *drops, float k) {
      float d = 1e5;
      for (int i = 0; i < 5; i++) {
        d = smin(d, length(p - drops[i].xy) - drops[i].z, k);
      }
      return d;
    }

    static float3 tap(texture2d<float, access::sample> frame, Frame f, float2 q) {
      q = clamp(q, float2(0.5), f.size - 0.5);
      float2 uv = (q + f.origin - f.inputOrigin) / f.inputSize;
      return frame.sample(linearClamp, float2(uv.x, 1.0 - uv.y)).rgb;
    }

    static float3 frosted(texture2d<float, access::sample> frame, Frame f, float2 q, float r) {
      float3 sum = tap(frame, f, q);
      for (int i = 0; i < 8; i++) {
        float n = float(i);
        float angle = n * 2.399963;
        sum += tap(frame, f, q + r * sqrt((n + 0.5) / 8.0) * float2(cos(angle), sin(angle)));
      }
      return sum / 9.0;
    }

    kernel void divineDrops(
      texture2d<float, access::sample> frame [[texture(0)]],
      texture2d<float, access::write> target [[texture(1)]],
      constant float4 *u [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
    ) {
      if (gid.x >= target.get_width() || gid.y >= target.get_height()) return;
      Frame f = { u[0].xy, u[0].zw, u[1].zw, u[2].xy };
      float intensity = u[2].z;
      float z = u[2].w;
      float frost = u[3].x;
      float fringes = u[3].y;
      // The textures' first row is the top of their region, while Core
      // Image's y axis points up.
      float2 p = float2(
        u[1].x + float(gid.x) + 0.5,
        u[1].y + float(target.get_height()) - float(gid.y) - 0.5) - f.origin;
      float s = min(f.size.x, f.size.y);
      float3 drops[5];
      for (int i = 0; i < 5; i++) {
        drops[i] = float3(u[4 + i].xy * f.size, u[4 + i].z * s);
      }
      float k = 0.13 * s * z;

      float3 base = tap(frame, f, p);
      float d = glass(p, drops, k);
      float shadow = 1.0 - smoothstep(0.0, 0.07 * s * z, glass(p + float2(0.0, 0.018 * s * z), drops, k));
      float3 background = base * (1.0 - shadow * 0.3 * intensity);
      if (d > 1.0) {
        target.write(float4(background, 1.0), gid);
        return;
      }

      float2 g = float2(
        glass(p + float2(1.0, 0.0), drops, k) - glass(p - float2(1.0, 0.0), drops, k),
        glass(p + float2(0.0, 1.0), drops, k) - glass(p - float2(0.0, 1.0), drops, k));
      float2 n = g / max(length(g), 1e-4);
      float w = 0.11 * s * z;
      float e = 1.0 - clamp(-d / w, 0.0, 1.0);
      float slope = e * e * e * pow(max(1.0 - e * e * e * e, 1e-4), -0.75);
      float bend = slope / sqrt(1.0 + slope * slope);
      float2 shift = -n * bend * 0.95 * intensity * w;
      float r = 0.028 * s * frost * intensity;
      float spread = 0.28 * fringes;
      float3 color = float3(
        frosted(frame, f, p + shift * (1.0 - spread), r).r,
        frosted(frame, f, p + shift, r).g,
        frosted(frame, f, p + shift * (1.0 + spread), r).b);
      color = mix(color, float3(1.0), (0.05 + 0.12 * frost) * intensity);
      float rim = 1.0 - smoothstep(0.0, 0.014 * s * z, -d);
      float light = dot(n, float2(-0.5524, 0.8336));
      float lit = max(light, 0.0);
      float back = max(-light, 0.0);
      color += intensity * rim * (0.85 * (lit * lit * lit + 0.45 * back * back * back) + 0.08);
      color = clamp(color, 0.0, 1.0);
      target.write(float4(mix(background, color, clamp(0.5 - d, 0.0, 1.0)), 1.0), gid);
    }
    """
}
