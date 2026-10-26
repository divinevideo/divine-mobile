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
class ShaderVideoEffect: CustomVideoEffectRenderer, VideoFrameEffect {
  /// The intensity a new effect starts at, as in the Dart editor.
  static let defaultIntensity = 0.7

  let historyOffsetsUs: [Int64] = []
  let historyScale = 1.0

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

  /// The values the kernel reads after the frame's layout, for a frame
  /// `effectTimeUs` after the effect started, or `nil` to leave the frame as
  /// it is.
  func values(effectTimeUs: Int64) -> [Double]? { nil }

  func render(_ frame: CustomVideoEffectFrame) -> CIImage {
    draw(frame.image, effectTimeUs: frame.effectTimeUs)
  }

  func render(_ image: CIImage, history: [CIImage?], timeUs: Int64, effectTimeUs: Int64)
    -> CIImage
  {
    draw(image, effectTimeUs: effectTimeUs)
  }

  private func draw(_ image: CIImage, effectTimeUs: Int64) -> CIImage {
    let extent = image.extent
    guard !extent.isEmpty, !extent.isInfinite, let values = values(effectTimeUs: effectTimeUs)
    else { return image }
    do {
      return try ShaderVideoEffectKernel.apply(
        withExtent: extent,
        inputs: [image],
        arguments: [
          ShaderVideoEffectKernel.extentKey: CIVector(cgRect: extent),
          ShaderVideoEffectKernel.functionKey: function,
          ShaderVideoEffectKernel.sourceKey: source,
          ShaderVideoEffectKernel.valuesKey: values,
        ])
    } catch {
      // Only malformed arguments throw here, and these are always complete.
      return image
    }
  }
}

/// Runs one of Divine's effect shaders on the frame's Metal texture, as a node
/// of the Core Image graph the preview and the export already render.
///
/// The shader's buffer holds the frame's layout in its first three `float4`s,
/// which ``prelude``'s `frameOf` and `pixelOf` read, and the effect's own
/// values from the fourth on.
final class ShaderVideoEffectKernel: CIImageProcessorKernel {
  static let extentKey = "extent"
  /// The name of the kernel function to run.
  static let functionKey = "function"
  /// The Metal source the function is in, without ``prelude``.
  static let sourceKey = "source"
  /// The effect's own values.
  static let valuesKey = "values"

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

  /// The whole frame: the effects sample the picture around each pixel.
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
    guard let function = arguments?[functionKey] as? String,
      let code = arguments?[sourceKey] as? String,
      let settings = arguments?[valuesKey] as? [Double]
    else { return }
    let extent = (arguments?[extentKey] as? CIVector)?.cgRectValue ?? input.region

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

    """
}
