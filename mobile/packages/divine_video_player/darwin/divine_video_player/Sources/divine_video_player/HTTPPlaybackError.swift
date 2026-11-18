import Foundation

/// Preserve an explicit readiness response without treating other 5xx as ready.
func httpServiceUnavailableCode(status: Int) -> String? {
    status == 503 ? "service_unavailable" : nil
}

/// AVFoundation can wrap a resource loader's error inside its own error.
/// Use the underlying HTTP response instead of classifying it as transport.
func playbackHTTPStatus(in error: NSError) -> Int? {
    var underlying: NSError? = error
    for _ in 0..<8 {
        guard let current = underlying else { return nil }
        if let response = current.userInfo["NSURLErrorFailingURLResponseErrorKey"] as? HTTPURLResponse {
            return response.statusCode
        }
        underlying = current.userInfo[NSUnderlyingErrorKey] as? NSError
    }
    return nil
}
