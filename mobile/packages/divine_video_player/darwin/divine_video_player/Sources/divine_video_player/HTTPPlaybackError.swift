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
    let captured: [Int] = chain.compactMap {
        ($0.userInfo["NSURLErrorFailingURLResponseErrorKey"] as? HTTPURLResponse)?.statusCode
    }
    var statuses = captured + chain.compactMap(coreMediaPlaybackHTTPStatus)
    if chain.contains(where: {
        $0.domain == NSURLErrorDomain && $0.code == NSURLErrorUserAuthenticationRequired
    }) {
        statuses.append(401)
    }
    return statuses.max {
        playbackHTTPStatusPriority($0) < playbackHTTPStatusPriority($1)
    }
}

/// Client failures prevent failover. Keep an explicit policy denial when
/// another request for the same asset fails with a generic client status.
func playbackHTTPStatusPriority(_ status: Int) -> Int {
    switch status {
    case 401, 403, 404: return 2
    case 400...499: return 1
    default: return 0
    }
}

/// AVURLAsset may expose the HTTP status only in an underlying CoreMedia
/// error. Read the numeric status from the framework's HTTP marker.
private func coreMediaPlaybackHTTPStatus(in error: NSError) -> Int? {
    guard error.domain == "CoreMediaErrorDomain" else { return nil }
    let description = error.localizedDescription
    guard let marker = description.range(of: #"(^| - )HTTP "#, options: .regularExpression) else {
        return nil
    }
    let statusText = description[marker.upperBound...]
    guard statusText.dropFirst(3).first == ":",
          let status = Int(statusText.prefix(3)),
          status == 202 || (400...599).contains(status)
    else { return nil }
    return status
}

/// A proxy denial for this asset takes precedence over a transport error.
/// Other proxy responses restore HTTP metadata stripped by AVFoundation.
func playbackErrorCanUseProxyHTTPStatus(_ status: Int, in error: NSError) -> Bool {
    let chain = playbackErrorChain(from: error)
    let urlCodes = chain
        .filter { $0.domain == NSURLErrorDomain || $0.domain == NSOSStatusErrorDomain }
        .map(\.code)
    guard !urlCodes.contains(NSURLErrorCancelled) else { return false }
    if let reported = playbackHTTPStatus(in: chain) {
        return playbackHTTPStatusPriority(status) > playbackHTTPStatusPriority(reported)
    }
    return (400...499).contains(status) || urlCodes.contains(NSURLErrorBadServerResponse)
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
