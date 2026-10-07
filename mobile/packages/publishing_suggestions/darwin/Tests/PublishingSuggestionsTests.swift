import Foundation
import FlutterMacOS
import AppKit

actor GenerationGate {
  var pending: CheckedContinuation<String, Error>?
  var started: CheckedContinuation<Void, Never>?
  func generate() async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
      pending = continuation
      started?.resume()
      started = nil
    }
  }
  func waitUntilStarted() async {
    if pending != nil { return }
    await withCheckedContinuation { started = $0 }
  }
  func finish(_ result: Result<String, Error>) {
    pending?.resume(with: result)
    pending = nil
  }
}

final class ControlledModel: PublishingSuggestionsModel {
  var isSupported = true
  var available = true
  let gate = GenerationGate()
  func isAvailable(language: String) -> Bool { available && language == "en" }
  func generate(prompt: String, frames: [Data]) async throws -> String {
    // Echo the arguments so assertions exercise the plugin's decoding and cap.
    if prompt == "echo" { return "frames=\(frames.map { $0.count })" }
    return try await gate.generate()
  }
}

@main
struct PublishingSuggestionsTests {
  @MainActor
  static func invoke(_ plugin: PublishingSuggestionsPlugin, _ method: String,
                     _ arguments: [String: Any] = [:]) async -> Any? {
    await withCheckedContinuation { continuation in
      plugin.handle(FlutterMethodCall(methodName: method, arguments: arguments)) {
        continuation.resume(returning: $0)
      }
    }
  }

  @MainActor
  static func main() async throws {
    let model = ControlledModel()
    let plugin = PublishingSuggestionsPlugin(model: model)
    let ready = await invoke(plugin, "capabilities") as! [String: Any]
    precondition(ready["availability"] as? String == "ready")
    precondition(ready["images"] as? Bool == true)
    let unsupportedLanguage = await invoke(plugin, "capabilities", ["language": "zz"]) as! [String: Any]
    precondition(unsupportedLanguage["availability"] as? String == "unavailable")
    precondition(unsupportedLanguage["images"] as? Bool == false)
    model.available = false
    let unavailable = await invoke(plugin, "capabilities") as! [String: Any]
    precondition(unavailable["availability"] as? String == "unavailable")
    model.available = true
    let invalid = await invoke(plugin, "generate") as! FlutterError
    precondition(invalid.code == "invalid_request")
    let frames = [1, 2, 3, 4].map { FlutterStandardTypedData(bytes: Data(repeating: 0, count: $0)) }
    let decoded = await invoke(plugin, "generate", ["prompt": "echo", "frames": frames])
    precondition(decoded as? String == "frames=[1, 2, 3]")
    let textOnly = await invoke(plugin, "generate", ["prompt": "echo"])
    precondition(textOnly as? String == "frames=[]")

    let cancelled = Task { await invoke(plugin, "generate", ["prompt": "pending"]) }
    await model.gate.waitUntilStarted()
    let cancellation = await invoke(plugin, "cancel")
    precondition(cancellation == nil)
    await model.gate.finish(.success("stale result"))
    let cancelledReply = await cancelled.value as? FlutterError
    precondition(cancelledReply?.code == "unavailable")

    // A replacement gets its own success; the old request receives one terminal
    // error even if the device finishes after cancellation. A duplicate reply
    // would fail invoke's checked continuation.
    let replaced = Task { await invoke(plugin, "generate", ["prompt": "pending"]) }
    await model.gate.waitUntilStarted()
    let replacement = await invoke(plugin, "generate", ["prompt": "echo"])
    precondition(replacement as? String == "frames=[]")
    await model.gate.finish(.success("obsolete result"))
    let replacedReply = await replaced.value as? FlutterError
    precondition(replacedReply?.code == "unavailable")

    let failed = Task { await invoke(plugin, "generate", ["prompt": "failure"]) }
    await model.gate.waitUntilStarted()
    await model.gate.finish(.failure(NSError(domain: "synthetic", code: 1)))
    let failedReply = await failed.value as? FlutterError
    precondition(failedReply?.code == "unavailable")

    model.isSupported = false
    let oldOS = await invoke(plugin, "capabilities") as! [String: Any]
    precondition(oldOS["availability"] as? String == "unavailable")
    let unsupportedReply = await invoke(plugin, "generate", ["prompt": "echo"]) as? FlutterError
    precondition(unsupportedReply?.code == "unavailable")

    // Exercise actual Vision decoding, without requiring a device language model.
    do {
      _ = try PublishingFrameLabels.classify(frames: [Data("invalid image".utf8)])
      preconditionFailure("Malformed frame must fail decoding")
    } catch {}
    let image = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 32, pixelsHigh: 32,
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let png = image.representation(using: .png, properties: [:])!
    let labels = try PublishingFrameLabels.classify(frames: [png, png, png, Data()])
    precondition(labels.count == 3, "Only the first three frames should be decoded")
    let emptyLabels = try PublishingFrameLabels.classify(frames: [])
    precondition(emptyLabels.isEmpty)
    print("Publishing suggestions native tests passed")
  }
}
