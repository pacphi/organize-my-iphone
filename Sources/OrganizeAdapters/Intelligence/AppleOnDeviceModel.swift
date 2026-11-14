import Foundation
import OrganizeCore

#if canImport(FoundationModels)
import FoundationModels

/// Apple's on-device language model, through the Foundation Models framework (macOS 26+).
///
/// Nothing leaves the Mac. The model is small, so the classifier feeds it a few apps at a time.
/// Each call uses a fresh session so earlier batches do not eat into the context window.
@available(macOS 26.0, *)
public struct AppleOnDeviceModel: TextCompletionModel {
    public let name = "apple-on-device"

    public init() {}

    /// True when Apple Intelligence is switched on and the model has finished downloading.
    public static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
    }

    public func complete(prompt: String, schema: JSONValue?) async throws -> String {
        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt)
        return response.content
    }
}
#endif

/// Entry point that hides the availability checks from callers.
public enum AppleIntelligence {
    /// Returns Apple's on-device model, or `nil` when this Mac cannot run it (older macOS,
    /// unsupported hardware, Apple Intelligence turned off, or model still downloading).
    public static func makeOnDeviceModel() -> (any TextCompletionModel)? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            if AppleOnDeviceModel.isAvailable {
                return AppleOnDeviceModel()
            }
        }
        #endif
        return nil
    }
}
