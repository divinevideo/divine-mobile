import AVFoundation
import Foundation
import UniformTypeIdentifiers

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
/// A file larger than [maxKeptBytes] is not kept: a feed plays only its first
/// seconds, and fetching all of a long video to loop them would waste the
/// data. The loader then fetches each byte range the player asks for on its
/// own, as `AVFoundation` would have, and never reports a file.
final class CachingAssetLoader: NSObject, AVAssetResourceLoaderDelegate, URLSessionDataDelegate {

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
    private let headers: [String: String]
    private let queue = DispatchQueue(label: "co.divine.video_player.caching_asset_loader")
    private var session: URLSession?
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

    /// A loader for [remoteURL], or nil for a URL it cannot serve.
    init?(remoteURL: URL, headers: [String: String]) {
        guard var components = URLComponents(url: remoteURL, resolvingAgainstBaseURL: false),
            let scheme = components.scheme?.lowercased(),
            scheme == "https" || scheme == "http"
        else { return nil }
        components.scheme = Self.schemePrefix + scheme
        guard let loaderURL = components.url else { return nil }
        self.remoteURL = remoteURL
        self.headers = headers
        self.asset = AVURLAsset(url: loaderURL)
        super.init()
        asset.resourceLoader.setDelegate(self, queue: queue)
    }

    /// Stops every fetch, fails whatever the player still waits for, and
    /// deletes the file.
    func cancel() {
        queue.async { [self] in
            cancelled = true
            session?.invalidateAndCancel()
            session = nil
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
            session?.getAllTasks { tasks in
                tasks.first { $0.taskIdentifier == id }?.cancel()
            }
        }
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if let request = proxied[dataTask.taskIdentifier] {
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                proxied[dataTask.taskIdentifier] = nil
                request.finishLoading(with: NSError(
                    domain: NSURLErrorDomain,
                    code: NSURLErrorBadServerResponse,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]
                ))
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
            failure = NSError(
                domain: NSURLErrorDomain,
                code: NSURLErrorBadServerResponse,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]
            )
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

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive chunk: Data) {
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

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
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
        let task = makeSession().dataTask(with: request)
        download = task
        task.resume()
    }

    private func makeSession() -> URLSession {
        if let session { return session }
        let operationQueue = OperationQueue()
        operationQueue.underlyingQueue = queue
        operationQueue.maxConcurrentOperationCount = 1
        let session = URLSession(
            configuration: .default,
            delegate: self,
            delegateQueue: operationQueue
        )
        self.session = session
        return session
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
        guard let dataRequest = request.dataRequest else {
            request.finishLoading()
            return
        }
        var urlRequest = URLRequest(url: remoteURL)
        for (field, value) in headers { urlRequest.setValue(value, forHTTPHeaderField: field) }
        let start = dataRequest.currentOffset
        let range = dataRequest.requestsAllDataToEndOfResource
            ? "bytes=\(start)-"
            : "bytes=\(start)-\(dataRequest.requestedOffset + Int64(dataRequest.requestedLength) - 1)"
        urlRequest.setValue(range, forHTTPHeaderField: "Range")
        let task = makeSession().dataTask(with: urlRequest)
        proxied[task.taskIdentifier] = request
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
