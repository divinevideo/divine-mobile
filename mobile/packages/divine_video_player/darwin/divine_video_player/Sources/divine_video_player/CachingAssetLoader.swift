import AVFoundation
import Foundation
import UniformTypeIdentifiers

/// Shared `URLSession` pool and delegate router so consecutive feed clips reuse
/// warm HTTP/2 and TLS connections instead of creating and invalidating a
/// fresh `URLSession` per video.
private final class CachingAssetLoaderSessionRouter: NSObject, URLSessionDataDelegate {
    private struct WeakLoader {
        weak var value: CachingAssetLoader?
    }

    static let shared = CachingAssetLoaderSessionRouter()

    private let lock = NSLock()
    private var defaultLoaders: [Int: WeakLoader] = [:]
    private var ephemeralLoaders: [Int: WeakLoader] = [:]

    // Created once, in `init`, rather than as `lazy var`s: loaders start tasks
    // from their own queues, and a lazy property first read from two threads at
    // once can be initialized twice. A task made on the losing session would
    // then fail `owner(for:)`'s identity check and be cancelled. `shared` is a
    // static `let`, which Swift initializes exactly once.
    private var defaultSession: URLSession!
    private var ephemeralSession: URLSession!

    private override init() {
        super.init()
        defaultSession = Self.makeSession(
            configuration: .default,
            queueName: "co.divine.video_player.caching_asset_loader.default_session",
            delegate: self
        )
        let ephemeral = URLSessionConfiguration.ephemeral
        ephemeral.urlCache = nil
        // Keep the process-wide ephemeral session stateless across clips so
        // redirect cookies or credentials never leak from one load to another.
        ephemeral.httpShouldSetCookies = false
        ephemeral.httpCookieAcceptPolicy = .never
        ephemeral.httpCookieStorage = nil
        ephemeral.urlCredentialStorage = nil
        ephemeralSession = Self.makeSession(
            configuration: ephemeral,
            queueName: "co.divine.video_player.caching_asset_loader.ephemeral_session",
            delegate: self
        )
    }

    private static func makeSession(
        configuration: URLSessionConfiguration,
        queueName: String,
        delegate: URLSessionDataDelegate
    ) -> URLSession {
        let queue = OperationQueue()
        queue.name = queueName
        queue.maxConcurrentOperationCount = 1
        return URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: queue
        )
    }

    func startDataTask(
        with request: URLRequest,
        keepsDownload: Bool,
        owner: CachingAssetLoader
    ) -> URLSessionDataTask {
        let session: URLSession = keepsDownload ? defaultSession! : ephemeralSession!
        let task = session.dataTask(with: request)
        lock.lock()
        if keepsDownload {
            defaultLoaders[task.taskIdentifier] = WeakLoader(value: owner)
        } else {
            ephemeralLoaders[task.taskIdentifier] = WeakLoader(value: owner)
        }
        lock.unlock()
        return task
    }

    func unregister(taskIdentifier: Int, keepsDownload: Bool) {
        lock.lock()
        if keepsDownload {
            defaultLoaders.removeValue(forKey: taskIdentifier)
        } else {
            ephemeralLoaders.removeValue(forKey: taskIdentifier)
        }
        lock.unlock()
    }

    private func owner(for session: URLSession, taskIdentifier: Int) -> CachingAssetLoader? {
        let isDefault = session === defaultSession
        lock.lock()
        let loader = isDefault
            ? defaultLoaders[taskIdentifier]?.value
            : ephemeralLoaders[taskIdentifier]?.value
        lock.unlock()
        return loader
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let loader = owner(for: session, taskIdentifier: dataTask.taskIdentifier) else {
            completionHandler(.cancel)
            return
        }
        loader.handleDidReceive(
            session: session,
            dataTask: dataTask,
            response: response,
            completionHandler: completionHandler
        )
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        owner(for: session, taskIdentifier: dataTask.taskIdentifier)?.handleDidReceive(
            session: session,
            dataTask: dataTask,
            chunk: data
        )
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let isDefault = session === defaultSession
        lock.lock()
        let loader = isDefault
            ? defaultLoaders.removeValue(forKey: task.taskIdentifier)?.value
            : ephemeralLoaders.removeValue(forKey: task.taskIdentifier)?.value
        lock.unlock()
        loader?.handleDidComplete(session: session, task: task, error: error)
    }
}

/// Streams a remote clip to `AVPlayer` through one download it keeps, so the
/// clip's audio can be decoded from the same bytes without fetching them
/// again — the Apple counterpart of decoding from ExoPlayer's cache on
/// Android (#9327).
///
/// `AVAssetReader` refuses a remote asset and `AVPlayer` keeps what it
/// downloads to itself, so the player is handed an asset whose URL scheme only
/// this loader can resolve. The loader fetches the file once into a temporary
/// file, answers the player's byte-range requests from what has arrived, and
/// reports the file once it is complete.
///
/// A file larger than `maxKeptBytes` is not kept: a feed plays only its first
/// seconds, and fetching all of a long video to loop them would waste the
/// data. The loader then fetches each byte range the player asks for on its
/// own, as `AVFoundation` would have, and never reports a file.
final class CachingAssetLoader: NSObject, AVAssetResourceLoaderDelegate {

    /// The largest file kept for decoding. Feed clips are a few megabytes.
    static let maxKeptBytes: Int64 = 16 * 1024 * 1024

    /// The most read from the file for one answer to the player.
    private static let maxAnswerBytes = 1024 * 1024

    /// The asset to play: the remote URL under a scheme `AVFoundation` hands
    /// to this loader.
    let asset: AVURLAsset

    /// Called on the main queue with the complete download — at once when
    /// set after the download has finished, which a clip of a few seconds
    /// often has by the time its item is ready.
    var onDownloaded: ((URL) -> Void)? {
        didSet {
            if let downloadedURL { onDownloaded?(downloadedURL) }
        }
    }

    /// The written file, once the download is complete. Main queue only.
    private var downloadedURL: URL?

    private let remoteURL: URL
    private let keepsDownload: Bool
    private static let telemetryLock = NSLock()
    private static let telemetryLoaders = NSHashTable<CachingAssetLoader>.weakObjects()

    /// Includes loaders still preparing an item, before the player owns it.
    static func clearAllPlaybackTelemetry() {
        telemetryLock.lock()
        let loaders = telemetryLoaders.allObjects
        telemetryLock.unlock()
        loaders.forEach { $0.clearPlaybackTelemetry() }
    }

    private var headers: [String: String]
    private let onPlaybackNetwork: ([String: Any]) -> Void
    private var observations: [Int: PlaybackNetworkObservation] = [:]

    /// Future requests stop carrying IDs; already-sent requests cannot be recalled.
    func clearPlaybackTelemetry() {
        queue.async { [self] in
            headers = PlaybackNetworkObservation.withoutCorrelation(headers)
            observations.values.forEach { $0.invalidate() }
            observations.removeAll()
        }
    }

    private func observe(_ task: URLSessionTask) {
        guard let id = headers.first(where: { $0.key.lowercased() == "x-playback-load-id" })?.value else { return }
        observations[task.taskIdentifier] = PlaybackNetworkObservation(loadID: id, emit: onPlaybackNetwork)
    }
    private let queue = DispatchQueue(label: "co.divine.video_player.caching_asset_loader")
    private var download: URLSessionDataTask?
    private let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("divine-loop-\(UUID().uuidString).mp4")
    private var writer: FileHandle?
    private var reader: FileHandle?
    private var received: Int64 = 0
    private var contentLength: Int64?
    private var contentType: String?
    private var finished = false
    private var failure: Error?
    private var cancelled = false
    private var pending: [AVAssetResourceLoadingRequest] = []

    /// Set once the file turned out too large to keep: every request the
    /// player makes is then fetched on its own.
    private var proxying = false
    private var proxied: [Int: AVAssetResourceLoadingRequest] = [:]
    private var proxiedTasks: [Int: URLSessionDataTask] = [:]
    private let httpFailureLock = NSLock()
    private var httpFailure: (status: Int, error: NSError)?

    /// A loader for [remoteURL], or nil for a URL it cannot serve.
    init?(remoteURL: URL, headers: [String: String], onPlaybackNetwork: @escaping ([String: Any]) -> Void = { _ in }) {
        guard var components = URLComponents(url: remoteURL, resolvingAgainstBaseURL: false),
            let scheme = components.scheme?.lowercased(),
            scheme == "https" || scheme == "http"
        else { return nil }
        components.scheme = Self.schemePrefix + scheme
        guard let loaderURL = components.url else { return nil }
        self.remoteURL = remoteURL
        let requestsNoStore = headers.contains {
            $0.key.lowercased() == "cache-control" && $0.value.lowercased() == "no-store"
        }
        let keepsDownload = components.host?.lowercased() != "media-bunny.divine.video" && !requestsNoStore
        self.keepsDownload = keepsDownload
        // Canary playback goes through fresh range requests and preserves the
        // HTTP status for Dart's fallback policy without creating a loop file.
        self.proxying = !keepsDownload
        self.headers = headers
        self.onPlaybackNetwork = onPlaybackNetwork
        self.asset = AVURLAsset(url: loaderURL)
        super.init()
        Self.telemetryLock.lock()
        Self.telemetryLoaders.add(self)
        Self.telemetryLock.unlock()
        asset.resourceLoader.setDelegate(self, queue: queue)
    }

    /// AVFoundation may strip the HTTP status from resource-loader errors.
    /// Recover it from this asset's own download or range request.
    func preservedHTTPFailure(for error: NSError) -> NSError? {
        guard !Task.isCancelled,
              let failure = httpFailureLock.withLock({ httpFailure }),
              playbackErrorCanUseProxyHTTPStatus(failure.status, in: error)
        else {
            return nil
        }
        return failure.error
    }

    /// Stops every fetch, fails whatever the player still waits for, and
    /// deletes the file.
    func cancel() {
        queue.async { [self] in
            cancelled = true
            httpFailureLock.withLock { httpFailure = nil }
            if let downloadTask = download {
                download = nil
                cancelTask(downloadTask)
            }
            for task in proxiedTasks.values {
                cancelTask(task)
            }
            proxiedTasks.removeAll()
            let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)
            pending.forEach { $0.finishLoading(with: error) }
            pending.removeAll()
            proxied.values.forEach { $0.finishLoading(with: error) }
            proxied.removeAll()
            dropFile()
        }
    }

    // MARK: - AVAssetResourceLoaderDelegate

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard !cancelled else { return false }
        if proxying {
            proxy(loadingRequest)
            return true
        }
        pending.append(loadingRequest)
        startIfNeeded()
        serve()
        return true
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        didCancel loadingRequest: AVAssetResourceLoadingRequest
    ) {
        pending.removeAll { $0 === loadingRequest }
        for (id, request) in proxied where request === loadingRequest {
            proxied[id] = nil
            if let task = proxiedTasks.removeValue(forKey: id) {
                cancelTask(task)
            }
        }
    }

    private func cancelTask(_ task: URLSessionTask) {
        // The router stops forwarding callbacks as soon as we unregister.
        observations.removeValue(forKey: task.taskIdentifier)?.finish(outcome: "cancelled")
        CachingAssetLoaderSessionRouter.shared.unregister(
            taskIdentifier: task.taskIdentifier,
            keepsDownload: keepsDownload
        )
        task.cancel()
    }

    // MARK: - Routed URLSessionDataDelegate handlers

    fileprivate func handleDidReceive(
        session: URLSession,
        dataTask: URLSessionDataTask,
        response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        queue.async { [self] in
            self.onDidReceive(
                dataTask: dataTask,
                response: response,
                completionHandler: completionHandler
            )
        }
    }

    fileprivate func handleDidReceive(
        session: URLSession,
        dataTask: URLSessionDataTask,
        chunk: Data
    ) {
        queue.async { [self] in
            self.onDidReceive(dataTask: dataTask, chunk: chunk)
        }
    }

    fileprivate func handleDidComplete(
        session: URLSession,
        task: URLSessionTask,
        error: Error?
    ) {
        queue.async { [self] in
            self.onDidComplete(task: task, error: error)
        }
    }

    private func onDidReceive(
        dataTask: URLSessionDataTask,
        response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        observations[dataTask.taskIdentifier]?.headers()
        if let request = proxied[dataTask.taskIdentifier] {
            if let http = response as? HTTPURLResponse,
                (!keepsDownload && http.statusCode == 202) || !(200..<300).contains(http.statusCode)
            {
                proxied[dataTask.taskIdentifier] = nil
                request.finishLoading(with: recordHTTPFailure(http))
                completionHandler(.cancel)
                return
            }
            answerContentInformation(request, from: response)
            completionHandler(.allow)
            return
        }
        guard dataTask === download else {
            completionHandler(.cancel)
            return
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            failure = recordHTTPFailure(http)
            completionHandler(.cancel)
            serve()
            return
        }
        contentType = response.mimeType.flatMap { UTType(mimeType: $0)?.identifier }
            ?? AVFileType.mp4.rawValue
        let length = response.expectedContentLength
        guard length > 0, length <= Self.maxKeptBytes, openFile() else {
            completionHandler(.cancel)
            download = nil
            switchToProxying(knownLength: length > 0 ? length : nil)
            return
        }
        contentLength = length
        completionHandler(.allow)
        serve()
    }

    private func recordHTTPFailure(_ response: HTTPURLResponse) -> NSError {
        let status = response.statusCode
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorBadServerResponse,
            userInfo: [
                NSLocalizedDescriptionKey: "HTTP \(status)",
                "NSURLErrorFailingURLResponseErrorKey": response
            ]
        )
        httpFailureLock.withLock {
            if let previous = httpFailure,
               playbackHTTPStatusPriority(previous.status) >= playbackHTTPStatusPriority(status) {
                return
            }
            httpFailure = (status, error)
        }
        return error
    }

    private func onDidReceive(dataTask: URLSessionDataTask, chunk: Data) {
        observations[dataTask.taskIdentifier]?.received(chunk.count)
        if let request = proxied[dataTask.taskIdentifier] {
            request.dataRequest?.respond(with: chunk)
            return
        }
        guard dataTask === download, let writer else { return }
        do {
            try writer.write(contentsOf: chunk)
        } catch {
            failure = error
            dataTask.cancel()
            serve()
            return
        }
        received += Int64(chunk.count)
        serve()
    }

    private func onDidComplete(task: URLSessionTask, error: Error?) {
        let outcome = error == nil ? "complete" : (error as NSError?)?.code == NSURLErrorCancelled ? "cancelled" : "error"
        observations.removeValue(forKey: task.taskIdentifier)?.finish(outcome: outcome)
        proxiedTasks.removeValue(forKey: task.taskIdentifier)
        if let request = proxied.removeValue(forKey: task.taskIdentifier) {
            if let error {
                request.finishLoading(with: error)
            } else {
                request.finishLoading()
            }
            return
        }
        guard task === download, !cancelled else { return }
        download = nil
        if let error {
            if failure == nil { failure = error }
            serve()
            return
        }
        guard failure == nil else { return }
        finished = true
        try? writer?.close()
        writer = nil
        serve()
        let url = fileURL
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.downloadedURL = url
            self.onDownloaded?(url)
        }
    }

    // MARK: - Serving the kept download

    private func startIfNeeded() {
        guard download == nil, !finished, failure == nil, !cancelled, !proxying else { return }
        var request = URLRequest(url: remoteURL)
        for (field, value) in headers { request.setValue(value, forHTTPHeaderField: field) }
        let task = CachingAssetLoaderSessionRouter.shared.startDataTask(
            with: request,
            keepsDownload: keepsDownload,
            owner: self
        )
        download = task
        observe(task)
        task.resume()
    }

    private func openFile() -> Bool {
        guard FileManager.default.createFile(atPath: fileURL.path, contents: nil),
            let writer = try? FileHandle(forWritingTo: fileURL),
            let reader = try? FileHandle(forReadingFrom: fileURL)
        else { return false }
        self.writer = writer
        self.reader = reader
        return true
    }

    private func dropFile() {
        try? writer?.close()
        try? reader?.close()
        writer = nil
        reader = nil
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Answers every waiting request as far as the bytes that have arrived
    /// allow, and finishes the ones that are complete.
    private func serve() {
        pending.removeAll { request in
            if let failure {
                request.finishLoading(with: failure)
                return true
            }
            guard let contentLength else { return false }
            if let info = request.contentInformationRequest {
                info.contentType = contentType
                info.contentLength = contentLength
                info.isByteRangeAccessSupported = true
            }
            guard let dataRequest = request.dataRequest else {
                request.finishLoading()
                return true
            }
            let requestEnd = dataRequest.requestsAllDataToEndOfResource
                ? contentLength
                : dataRequest.requestedOffset + Int64(dataRequest.requestedLength)
            while dataRequest.currentOffset < min(received, requestEnd) {
                let offset = dataRequest.currentOffset
                let count = Int(min(min(received, requestEnd) - offset, Int64(Self.maxAnswerBytes)))
                guard let reader, (try? reader.seek(toOffset: UInt64(offset))) != nil,
                    let data = try? reader.read(upToCount: count), !data.isEmpty
                else { break }
                dataRequest.respond(with: data)
            }
            let reached = dataRequest.currentOffset
            if reached >= requestEnd || (finished && reached >= received) {
                request.finishLoading()
                return true
            }
            return false
        }
    }

    // MARK: - Fetching each request on its own

    /// Gives up keeping the file and fetches what every waiting and future
    /// request asks for directly.
    private func switchToProxying(knownLength: Int64?) {
        proxying = true
        contentLength = knownLength
        dropFile()
        let waiting = pending
        pending.removeAll()
        waiting.forEach(proxy)
    }

    private func proxy(_ request: AVAssetResourceLoadingRequest) {
        if let contentLength, let info = request.contentInformationRequest {
            info.contentType = contentType
            info.contentLength = contentLength
            info.isByteRangeAccessSupported = true
        }
        var urlRequest = URLRequest(url: remoteURL)
        for (field, value) in headers { urlRequest.setValue(value, forHTTPHeaderField: field) }
        if let dataRequest = request.dataRequest {
            let start = dataRequest.currentOffset
            let range = dataRequest.requestsAllDataToEndOfResource
                ? "bytes=\(start)-"
                : "bytes=\(start)-\(dataRequest.requestedOffset + Int64(dataRequest.requestedLength) - 1)"
            urlRequest.setValue(range, forHTTPHeaderField: "Range")
        } else if !keepsDownload, contentLength == nil {
            urlRequest.httpMethod = "HEAD"
        } else {
            request.finishLoading()
            return
        }
        let task = CachingAssetLoaderSessionRouter.shared.startDataTask(
            with: urlRequest,
            keepsDownload: keepsDownload,
            owner: self
        )
        proxied[task.taskIdentifier] = request
        proxiedTasks[task.taskIdentifier] = task
        observe(task)
        task.resume()
    }

    /// Fills in what the player needs to know about the resource from a
    /// ranged response, when the kept download never learned it.
    private func answerContentInformation(
        _ request: AVAssetResourceLoadingRequest,
        from response: URLResponse
    ) {
        guard let info = request.contentInformationRequest, info.contentLength == 0 else { return }
        info.contentType = response.mimeType.flatMap { UTType(mimeType: $0)?.identifier }
            ?? AVFileType.mp4.rawValue
        info.isByteRangeAccessSupported = true
        if let http = response as? HTTPURLResponse,
            let range = http.value(forHTTPHeaderField: "Content-Range"),
            let total = range.split(separator: "/").last.flatMap({ Int64($0) })
        {
            info.contentLength = total
        } else if response.expectedContentLength > 0 {
            info.contentLength = response.expectedContentLength
        }
    }

    /// Prefixed to the remote URL's scheme, so `AVFoundation` cannot load
    /// the asset itself and asks this loader.
    private static let schemePrefix = "divine-cache-"
}
