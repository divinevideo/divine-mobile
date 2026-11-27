import CoreImage
import Foundation
import Metal
import divine_video_player
import pro_video_editor

/// An effect Divine draws with one Metal compute shader over the current
/// frame, in the export (pro_video_editor) and in the editor preview
/// (divine_video_player) alike.
///
/// No stock Core Image filter draws these effects, and runtime-compiled Core
/// Image Metal kernels need an A13 or later, so ``ShaderVideoEffectKernel``
/// runs a plain Metal compute shader on the frame instead, as
/// `DropsVideoEffect` does. Plain Metal compiles on every device.
///
/// Each subclass's kernel is the Android effect's fragment shader of the same
/// name, line for line, and the picker tile's `shaders/<name>.frag`.
///
/// A subclass that asks for earlier frames, through ``historyOffsetsUs``, gets
/// them as further textures after ``textures()``, newest first, each at
/// ``historyScale`` of the frame's size. One the clip has not played far
/// enough back for yet is the current frame, as on Android.
class ShaderVideoEffect: CustomVideoEffectRenderer, VideoFrameEffect {
  /// The intensity a new effect starts at, as in the Dart editor.
  static let defaultIntensity = 0.7

  /// The earlier frames the kernel reads; none by default.
  var historyOffsetsUs: [Int64] { [] }

  /// The size the earlier frames are kept and read at, relative to the
  /// frame.
  var historyScale: Double { 1 }

  private let function: String
  private let source: String

  /// An effect drawn by the kernel `function` in `source`.
  init(function: String, source: String) {
    self.function = function
    self.source = source
  }

  /// Reads `intensity` from `params`, clamped to 0–1.
  static func readIntensity(_ params: [String: Any]) -> Double {
    min(1, max(0, (params["intensity"] as? NSNumber)?.doubleValue ?? defaultIntensity))
  }

  /// Reads the number `key` from `params`, clamped to `range`, or `fallback`
  /// when it is missing. The Dart effect settings catalog stores each setting
  /// with the same range and default.
  static func readNumber(
    _ params: [String: Any], _ key: String, fallback: Double, in range: ClosedRange<Double>
  ) -> Double {
    guard let value = (params[key] as? NSNumber)?.doubleValue, !value.isNaN else {
      return fallback
    }
    return min(range.upperBound, max(range.lowerBound, value))
  }

  /// Where the effect sits, from `centerX` and `centerY`: shares of the
  /// frame's width from its left edge and of its height from its top edge,
  /// the middle unless the user moved it.
  static func readCenter(_ params: [String: Any]) -> [Double] {
    [
      readNumber(params, "centerX", fallback: 0.5, in: 0...1),
      readNumber(params, "centerY", fallback: 0.5, in: 0...1),
    ]
  }

  /// Reads the colour `key` from `params`, an ARGB integer, as red, green and
  /// blue from 0 to 1, or those of `fallback` when it is missing.
  static func readColor(_ params: [String: Any], _ key: String, fallback: Int64) -> [Double] {
    let argb = (params[key] as? NSNumber)?.int64Value ?? fallback
    return [16, 8, 0].map { Double((argb >> $0) & 0xFF) / 255 }
  }

  /// The cosine and sine of `degrees`.
  static func turn(degrees: Double) -> [Double] {
    let radians = degrees * .pi / 180
    return [cos(radians), sin(radians)]
  }

  /// `direction`: -1 for an effect the user turned the other way, 1
  /// otherwise.
  static func readDirection(_ params: [String: Any]) -> Double {
    ((params["direction"] as? NSNumber)?.doubleValue ?? 1) < 0 ? -1 : 1
  }

  /// The values the kernel reads after the frame's layout, for a frame
  /// `effectTimeUs` after the effect started, or `nil` to leave the frame as
  /// it is.
  func values(effectTimeUs: Int64) -> [Double]? { nil }

  /// Images the kernel reads besides the frame, each whole, bound as its
  /// textures 2 and up; none by default.
  func textures() -> [CIImage] { [] }

  func render(_ frame: CustomVideoEffectFrame) -> CIImage {
    draw(frame.image, history: frame.history, effectTimeUs: frame.effectTimeUs)
  }

  func render(_ image: CIImage, history: [CIImage?], timeUs: Int64, effectTimeUs: Int64)
    -> CIImage
  {
    draw(image, history: history, effectTimeUs: effectTimeUs)
  }

  private func draw(_ image: CIImage, history: [CIImage?], effectTimeUs: Int64) -> CIImage {
    let extent = image.extent
    guard !extent.isEmpty, !extent.isInfinite, let values = values(effectTimeUs: effectTimeUs)
    else { return image }
    let textures = textures() + earlier(image, history)
    do {
      return try ShaderVideoEffectKernel.apply(
        withExtent: extent,
        inputs: [image] + textures,
        arguments: [
          ShaderVideoEffectKernel.extentKey: CIVector(cgRect: extent),
          ShaderVideoEffectKernel.functionKey: function,
          ShaderVideoEffectKernel.sourceKey: source,
          ShaderVideoEffectKernel.valuesKey: values,
          ShaderVideoEffectKernel.texturesKey: textures.map { CIVector(cgRect: $0.extent) },
        ])
    } catch {
      // Only malformed arguments throw here, and these are always complete.
      return image
    }
  }

  /// One image per ``historyOffsetsUs``, newest first, scaled down to
  /// ``historyScale``: the earlier frame, or `image` where there is none.
  ///
  /// The earlier frames arrive scaled back up to the frame's extent; scaling
  /// them down again hands the kernel the small copy instead of a full-size
  /// one rendered from it.
  private func earlier(_ image: CIImage, _ history: [CIImage?]) -> [CIImage] {
    let scale = CGFloat(min(1, max(0.05, historyScale)))
    return historyOffsetsUs.indices.map { k in
      let frame = (k < history.count ? history[k] : nil) ?? image
      return scale < 1 ? frame.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) : frame
    }
  }
}

/// Runs one of Divine's effect shaders on the frame's Metal texture, as a node
/// of the Core Image graph the preview and the export already render.
///
/// The shader's buffer holds the frame's layout in its first three `float4`s,
/// which ``prelude``'s `frameOf` and `pixelOf` read, and the effect's own
/// values from the fourth on. The frame is texture 0 and the output texture
/// 1; any further inputs, such as a glyph atlas or earlier frames, follow
/// from texture 2, each whole and with its first row at the top.
final class ShaderVideoEffectKernel: CIImageProcessorKernel {
  static let extentKey = "extent"
  /// The name of the kernel function to run.
  static let functionKey = "function"
  /// The Metal source the function is in, without ``prelude``.
  static let sourceKey = "source"
  /// The effect's own values.
  static let valuesKey = "values"
  /// The extents of the inputs after the frame, as `CIVector`s.
  static let texturesKey = "textures"

  enum Failure: Error {
    /// The context rendering the frame does not run on Metal.
    case noMetal
    case missingFunction
  }

  private struct PipelineKey: Hashable {
    let device: ObjectIdentifier
    let function: String
  }

  private static let lock = NSLock()
  private static var pipelines: [PipelineKey: MTLComputePipelineState] = [:]

  /// Compiles `function` for the default device in the background, so the
  /// first frame does not wait for it.
  static func prepare(function: String, source: String) {
    DispatchQueue.global(qos: .utility).async {
      guard let device = MTLCreateSystemDefaultDevice() else { return }
      _ = try? pipeline(for: device, function: function, source: source)
    }
  }

  // Half floats keep the frame's precision, and every Apple GPU filters them;
  // 32-bit float textures are not filterable on all of them.
  override class func formatForInput(at input: Int32) -> CIFormat { .RGBAh }

  override class var outputFormat: CIFormat { .RGBAh }

  /// The whole frame, as the effects sample the picture around each pixel,
  /// and the whole of each further input.
  override class func roi(forInput input: Int32, arguments: [String: Any]?, outputRect: CGRect)
    -> CGRect
  {
    if input > 0, let textures = arguments?[texturesKey] as? [CIVector],
      Int(input) <= textures.count
    {
      return textures[Int(input) - 1].cgRectValue
    }
    return (arguments?[extentKey] as? CIVector)?.cgRectValue ?? outputRect
  }

  override class func process(
    with inputs: [CIImageProcessorInput]?, arguments: [String: Any]?,
    output: CIImageProcessorOutput
  ) throws {
    guard let inputs, let input = inputs.first,
      let source = input.metalTexture,
      let target = output.metalTexture,
      let commandBuffer = output.metalCommandBuffer
    else { throw Failure.noMetal }
    guard let function = arguments?[functionKey] as? String,
      let code = arguments?[sourceKey] as? String,
      let settings = arguments?[valuesKey] as? [Double]
    else { return }
    let extent = (arguments?[extentKey] as? CIVector)?.cgRectValue ?? input.region
    let extras: [MTLTexture] = try inputs.dropFirst().map { extra in
      guard let texture = extra.metalTexture else { throw Failure.noMetal }
      return texture
    }

    let pipeline = try pipeline(for: commandBuffer.device, function: function, source: code)
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
    var values: [Float] = [
      Float(extent.minX), Float(extent.minY), Float(extent.width), Float(extent.height),
      Float(output.region.minX), Float(output.region.minY),
      Float(input.region.minX), Float(input.region.minY),
      Float(input.region.width), Float(input.region.height), 0, 0,
    ]
    values += settings.map(Float.init)
    values += [Float](repeating: 0, count: (4 - values.count % 4) % 4)
    encoder.setComputePipelineState(pipeline)
    encoder.setTexture(source, index: 0)
    encoder.setTexture(target, index: 1)
    for (index, texture) in extras.enumerated() {
      encoder.setTexture(texture, index: 2 + index)
    }
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

  static func pipeline(for device: MTLDevice, function: String, source: String) throws
    -> MTLComputePipelineState
  {
    lock.lock()
    defer { lock.unlock() }
    let key = PipelineKey(device: ObjectIdentifier(device), function: function)
    if let pipeline = pipelines[key] { return pipeline }
    let library = try device.makeLibrary(source: prelude + source, options: nil)
    guard let kernel = library.makeFunction(name: function) else {
      throw Failure.missingFunction
    }
    let pipeline = try device.makeComputePipelineState(function: kernel)
    pipelines[key] = pipeline
    return pipeline
  }

  /// What every effect shader starts with: the frame's layout, and a `tap`
  /// that reads the frame at a point in pixels with y up from the bottom
  /// left, clamped to the frame's edge pixels, as Android's does.
  static let prelude = """
    #include <metal_stdlib>
    using namespace metal;

    struct Frame {
      float2 origin;
      float2 size;
      float2 inputOrigin;
      float2 inputSize;
    };

    constexpr sampler linearClamp(coord::normalized, address::clamp_to_edge, filter::linear);

    static Frame frameOf(constant float4 *u) {
      return { u[0].xy, u[0].zw, u[1].zw, u[2].xy };
    }

    // The textures' first row is the top of their region, while Core Image's
    // y axis points up.
    static float2 pixelOf(constant float4 *u, uint2 gid, uint height) {
      return float2(
        u[1].x + float(gid.x) + 0.5,
        u[1].y + float(height) - float(gid.y) - 0.5) - u[0].xy;
    }

    static float3 tap(texture2d<float, access::sample> frame, Frame f, float2 q) {
      q = clamp(q, float2(0.5), f.size - 0.5);
      float2 uv = (q + f.origin - f.inputOrigin) / f.inputSize;
      return frame.sample(linearClamp, float2(uv.x, 1.0 - uv.y)).rgb;
    }

    // An earlier frame, a whole texture of any size, at the point p of the
    // frame, as Android's texture2D(uEarlier, vTexCoord) reads it.
    static float3 earlierAt(texture2d<float, access::sample> earlier, Frame f, float2 p) {
      float2 uv = p / f.size;
      return earlier.sample(linearClamp, float2(uv.x, 1.0 - uv.y)).rgb;
    }

    """
}
