import Foundation
import Vision
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Device capability and generation boundary; the plugin owns channel replies.
protocol PublishingSuggestionsModel {
  var isSupported: Bool { get }
  func isAvailable(language: String) -> Bool
  func generate(prompt: String, frames: [Data]) async throws -> String
}

struct DevicePublishingSuggestionsModel: PublishingSuggestionsModel {
  var isSupported: Bool {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, macOS 26.0, *) { return true }
    #endif
    return false
  }

  func isAvailable(language: String) -> Bool {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, macOS 26.0, *) {
      let model = SystemLanguageModel.default
      return model.availability == .available && model.supportsLocale(Locale(identifier: language))
    }
    #endif
    return false
  }

  func generate(prompt: String, frames: [Data]) async throws -> String {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, macOS 26.0, *) {
      return try await PublishingIdeasEngine.generate(prompt: prompt, frames: frames)
    }
    #endif
    throw NSError(domain: "PublishingIdeas", code: 1)
  }
}

/// Shared decoding path used before model inference.
enum PublishingFrameLabels {
  static func classify(frames: [Data]) throws -> [[String]] {
    try frames.prefix(3).map { data -> [String] in
      let request = VNClassifyImageRequest()
      try VNImageRequestHandler(data: data).perform([request])
      return (request.results ?? []).filter { $0.confidence >= 0.7 }
        .prefix(5).map { $0.identifier }
    }
  }
}
