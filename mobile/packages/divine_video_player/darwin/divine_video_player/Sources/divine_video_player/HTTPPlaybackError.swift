import Foundation

/// AVFoundation can wrap a URL loader's error. Cap the walk to avoid following
/// an arbitrarily long or cyclic underlying-error chain.
private func playbackErrorChain(from error: NSError) -> [NSError] {
    var chain: [NSError] = []
    var underlying: NSError? = error
    for _ in 0..<8 {
        guard let current = underlying else { break }
        chain.append(current)
        underlying = current.userInfo[NSUnderlyingErrorKey] as? NSError
    }
    return chain
}

private func playbackHTTPStatus(in chain: [NSError]) -> Int? {
    let statuses: [Int] = chain.compactMap {
        ($0.userInfo["NSURLErrorFailingURLResponseErrorKey"] as? HTTPURLResponse)?.statusCode
    }
    return statuses.first { [401, 403, 404].contains($0) }
        ?? statuses.first
        ?? coreMediaPlaybackHTTPStatus(in: chain)
}

/// AVURLAsset may expose the HTTP status only in an underlying CoreMedia
/// error. Read the numeric status from the framework's HTTP marker.
private func coreMediaPlaybackHTTPStatus(in chain: [NSError]) -> Int? {
    for error in chain where error.domain == "CoreMediaErrorDomain" {
        let description = error.localizedDescription
        guard let marker = description.range(of: #"(^| - )HTTP "#, options: .regularExpression) else {
            continue
        }
        let statusText = description[marker.upperBound...]
        if statusText.dropFirst(3).first == ":",
           let status = Int(statusText.prefix(3)),
           status == 202 || (400...599).contains(status) {
            return status
        }
    }
    return nil
}

/// A resource-loader response can cross AVFoundation as just a URL or
/// OSStatus error code. A response that survived that crossing is preferred.
func playbackErrorLostProxyHTTPResponse(_ error: NSError) -> Bool {
    let chain = playbackErrorChain(from: error)
    let urlCodes = chain
        .filter { $0.domain == NSURLErrorDomain || $0.domain == NSOSStatusErrorDomain }
        .map(\.code)
    return urlCodes.contains(NSURLErrorBadServerResponse)
        && !urlCodes.contains(NSURLErrorCancelled)
        && playbackHTTPStatus(in: chain) == nil
}

/// Classifies network errors before AVFoundation's outer composition error.
/// A captured HTTP response takes precedence over a transport failure.
func playbackNetworkErrorCode(in error: NSError) -> String? {
    let chain = playbackErrorChain(from: error)
    if let status = playbackHTTPStatus(in: chain) {
        switch status {
        case 202: return "media_processing"
        case 401: return "auth_required"
        case 403: return "forbidden"
        case 404: return "not_found"
        case 503: return "service_unavailable"
        default: return status >= 500 ? "http_server_error" : "http_client_error"
        }
    }
    if error.localizedDescription.contains("HTTP 202") {
        return "media_processing"
    }
    let urlErrorCodes = chain.filter { $0.domain == NSURLErrorDomain }.map(\.code)
    if urlErrorCodes.contains(NSURLErrorUserAuthenticationRequired) {
        return "auth_required"
    }
    for code in urlErrorCodes {
        switch code {
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost,
             NSURLErrorDataNotAllowed, NSURLErrorCannotFindHost,
             NSURLErrorDNSLookupFailed, NSURLErrorCannotConnectToHost:
            return "network_error"
        case NSURLErrorTimedOut:
            return "timeout"
        default:
            continue
        }
    }
    return nil
}

/// The Bunny pilot's diagnostics carry a provider and typed error only.
/// Canonical requests in the pilot carry the client-cache bypass directive.
func playbackPilotProvider(url: URL?, headers: [String: String] = [:]) -> String? {
    switch url?.host?.lowercased() {
    case "media-bunny.divine.video":
        return "Bunny"
    case "media.divine.video":
        return headers.contains {
            $0.key.lowercased() == "cache-control" && $0.value.lowercased() == "no-store"
        } ? "canonical" : nil
    default:
        return nil
    }
}
