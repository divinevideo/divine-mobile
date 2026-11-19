import Foundation

@main
enum HTTPPlaybackErrorTests {
    static func main() {
        let url = URL(string: "https://example.test/clip.mp4")!
        for (status, expected) in [
            (202, "media_processing"), (401, "auth_required"),
            (403, "forbidden"), (404, "not_found"), (410, "http_client_error"),
            (500, "http_server_error"), (502, "http_server_error"),
            (503, "service_unavailable"), (504, "http_server_error")
        ] {
            let loaderError = responseError(url: url, status: status)
            precondition(playbackNetworkErrorCode(in: loaderError) == expected)
            precondition(playbackNetworkErrorCode(in: wrapping(loaderError)) == expected)
        }

        for (code, expected) in [
            (NSURLErrorTimedOut, "timeout"),
            (NSURLErrorCannotFindHost, "network_error"),
            (NSURLErrorDNSLookupFailed, "network_error"),
            (NSURLErrorCannotConnectToHost, "network_error"),
            (NSURLErrorNetworkConnectionLost, "network_error")
        ] {
            let transport = NSError(domain: NSURLErrorDomain, code: code)
            precondition(playbackNetworkErrorCode(in: transport) == expected)
            precondition(playbackNetworkErrorCode(in: wrapping(wrapping(transport))) == expected)
        }
        let denied = [(401, "auth_required"), (403, "forbidden"), (404, "not_found")]
        for (status, expected) in denied {
            let denial = responseError(url: url, status: status)
            let timedOut = NSError(
                domain: NSURLErrorDomain,
                code: NSURLErrorTimedOut,
                userInfo: [NSUnderlyingErrorKey: denial]
            )
            precondition(playbackNetworkErrorCode(in: timedOut) == expected)
        }

        // AVURLAsset.load(.duration) reports these statuses without an HTTPURLResponse.
        for (urlCode, mediaCode, status, expected) in [
            (NSURLErrorUserAuthenticationRequired, -16840, "401: Unauthorized", "auth_required"),
            (NSURLErrorNoPermissionsToReadFile, -12660, "403: Forbidden", "forbidden"),
            (NSURLErrorFileDoesNotExist, -12938, "404: File Not Found", "not_found"),
            (NSURLErrorResourceUnavailable, -12668, "410: Gone", "http_client_error"),
            (NSURLErrorResourceUnavailable, -16845, "429: (unhandled)", "http_client_error"),
            (NSURLErrorResourceUnavailable, -16848, "502: Bad Gateway", "http_server_error"),
            (NSURLErrorResourceUnavailable, -16849, "503: Service Unavailable", "service_unavailable"),
            (NSURLErrorResourceUnavailable, -16850, "504: Gateway Timeout", "http_server_error")
        ] {
            let error = NSError(
                domain: NSURLErrorDomain,
                code: urlCode,
                userInfo: [NSUnderlyingErrorKey: coreMediaResponseError(code: mediaCode, status: status)]
            )
            let actual = playbackNetworkErrorCode(in: wrapping(error))
            precondition(actual == expected, "HTTP \(status) classified as \(actual ?? "nil")")
        }

        let processing = coreMediaResponseError(code: -12667, status: "202: (unhandled)")
        precondition(playbackNetworkErrorCode(in: processing) == "media_processing")
        precondition(playbackNetworkErrorCode(in: wrapping(processing)) == "media_processing")
        let legacyProcessing = NSError(
            domain: "AVFoundationErrorDomain",
            code: -11800,
            userInfo: [NSLocalizedDescriptionKey: "The operation failed with HTTP 202"]
        )
        precondition(playbackNetworkErrorCode(in: legacyProcessing) == "media_processing")

        let typedFailure = responseError(
            url: url, status: 503, underlying: responseError(url: url, status: 410)
        )
        precondition(
            playbackNetworkErrorCode(in: typedFailure) == "http_client_error",
            "A captured HTTP 503 must not mask a later HTTP 410"
        )
        precondition(!playbackErrorCanUseProxyHTTPStatus(503, in: typedFailure))
        precondition(playbackErrorCanUseProxyHTTPStatus(403, in: typedFailure))
        precondition(playbackErrorCanUseProxyHTTPStatus(410, in: responseError(url: url, status: 503)))

        let coreMediaDenial = coreMediaResponseError(code: -12660, status: "403: Forbidden")
        for status in [410, 503] {
            let wrapped = responseError(url: url, status: status, underlying: coreMediaDenial)
            precondition(playbackNetworkErrorCode(in: wrapped) == "forbidden")
        }
        let coreMediaServiceFailure = coreMediaResponseError(
            code: -16849, status: "503: Service Unavailable", underlying: coreMediaDenial
        )
        precondition(playbackNetworkErrorCode(in: coreMediaServiceFailure) == "forbidden")
        let typedDenial = responseError(url: url, status: 404, underlying: coreMediaDenial)
        precondition(playbackNetworkErrorCode(in: typedDenial) == "not_found")

        let strippedProxyError = NSError(domain: NSOSStatusErrorDomain, code: NSURLErrorBadServerResponse)
        precondition(playbackErrorCanUseProxyHTTPStatus(503, in: wrapping(strippedProxyError)))
        let typedAuthError = NSError(domain: NSURLErrorDomain, code: NSURLErrorUserAuthenticationRequired)
        precondition(
            playbackNetworkErrorCode(in: responseError(url: url, status: 503, underlying: typedAuthError))
                == "auth_required",
            "A captured HTTP 503 must not mask a typed authentication denial"
        )
        let wrappedAuthError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorBadServerResponse,
            userInfo: [NSUnderlyingErrorKey: typedAuthError]
        )
        precondition(!playbackErrorCanUseProxyHTTPStatus(503, in: wrappedAuthError))
        let proxyTimeout = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        precondition(playbackErrorCanUseProxyHTTPStatus(404, in: proxyTimeout))
        precondition(!playbackErrorCanUseProxyHTTPStatus(503, in: proxyTimeout))
        let cancelledProxyError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorCancelled,
            userInfo: [NSUnderlyingErrorKey: strippedProxyError]
        )
        precondition(!playbackErrorCanUseProxyHTTPStatus(403, in: cancelledProxyError))

        let unrelatedDescription = NSError(
            domain: "UnrelatedErrorDomain",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "HTTP 403: Forbidden"]
        )
        precondition(playbackNetworkErrorCode(in: unrelatedDescription) == nil)
        let malformed = coreMediaResponseError(code: -12938, status: "4040: File Not Found")
        precondition(playbackNetworkErrorCode(in: malformed) == nil)
        let misleadingReason = coreMediaResponseError(
            code: -16848,
            status: "502: Bad Gateway - HTTP 503: Service Unavailable"
        )
        precondition(playbackNetworkErrorCode(in: misleadingReason) == "http_server_error")
        for code in [NSURLErrorNoPermissionsToReadFile, NSURLErrorFileDoesNotExist, NSURLErrorResourceUnavailable] {
            let urlError = NSError(domain: NSURLErrorDomain, code: code)
            precondition(playbackNetworkErrorCode(in: urlError) == nil)
        }

        var deeplyNested = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        for _ in 0..<8 {
            deeplyNested = wrapping(deeplyNested)
        }
        precondition(playbackNetworkErrorCode(in: deeplyNested) == nil)
        let cancelled = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)
        precondition(playbackNetworkErrorCode(in: wrapping(cancelled)) == nil)
        let badCertificate = NSError(domain: NSURLErrorDomain, code: NSURLErrorServerCertificateUntrusted)
        precondition(playbackNetworkErrorCode(in: wrapping(badCertificate)) == nil)

        print("HTTP playback error tests passed")
    }
}

private func wrapping(_ error: NSError) -> NSError {
    NSError(domain: "AVFoundationErrorDomain", code: -11800, userInfo: [NSUnderlyingErrorKey: error])
}

private func responseError(url: URL, status: Int, underlying: NSError? = nil) -> NSError {
    let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
    var userInfo: [String: Any] = ["NSURLErrorFailingURLResponseErrorKey": response]
    userInfo[NSUnderlyingErrorKey] = underlying
    return NSError(
        domain: NSURLErrorDomain,
        code: NSURLErrorBadServerResponse,
        userInfo: userInfo
    )
}

private func coreMediaResponseError(code: Int, status: String, underlying: NSError? = nil) -> NSError {
    var userInfo: [String: Any] = [
        "NSDescription": "The operation couldn’t be completed. (CoreMediaErrorDomain error \(code) - HTTP \(status))"
    ]
    userInfo[NSUnderlyingErrorKey] = underlying
    return NSError(
        domain: "CoreMediaErrorDomain",
        code: code,
        userInfo: userInfo
    )
}
