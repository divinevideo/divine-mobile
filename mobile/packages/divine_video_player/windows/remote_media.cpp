#include "remote_media.h"

#include <robuffer.h>
#include <windows.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Storage.Streams.h>
#include <winrt/Windows.Web.Http.Filters.h>
#include <winrt/Windows.Web.Http.Headers.h>

#include <algorithm>
#include <cctype>
#include <chrono>
#include <cstring>
#include <cwchar>
#include <deque>
#include <iterator>
#include <list>
#include <mutex>
#include <utility>
#include <vector>

#include "media_sources.h"

namespace divine_video_player {

namespace {

using winrt::Windows::Foundation::IAsyncAction;
using winrt::Windows::Foundation::IAsyncOperation;
using winrt::Windows::Foundation::IAsyncOperationWithProgress;
using winrt::Windows::Foundation::Uri;
using winrt::Windows::Media::Core::MediaSource;
using winrt::Windows::Media::Streaming::Adaptive::AdaptiveMediaSource;
using winrt::Windows::Media::Streaming::Adaptive::
    AdaptiveMediaSourceDownloadCompletedEventArgs;
using winrt::Windows::Media::Streaming::Adaptive::
    AdaptiveMediaSourceDownloadFailedEventArgs;
using winrt::Windows::Media::Streaming::Adaptive::
    AdaptiveMediaSourceDownloadStatistics;
using winrt::Windows::Storage::Streams::IBuffer;
using winrt::Windows::Storage::Streams::IInputStream;
using winrt::Windows::Storage::Streams::InputStreamOptions;
using winrt::Windows::Storage::Streams::IOutputStream;
using winrt::Windows::Storage::Streams::IRandomAccessStream;
using winrt::Windows::Web::Http::HttpClient;
using winrt::Windows::Web::Http::HttpCompletionOption;
using winrt::Windows::Web::Http::HttpMethod;
using winrt::Windows::Web::Http::HttpProgress;
using winrt::Windows::Web::Http::HttpRequestMessage;
using winrt::Windows::Web::Http::HttpResponseMessage;
using winrt::Windows::Web::Http::Filters::HttpBaseProtocolFilter;
using winrt::Windows::Web::Http::Filters::IHttpFilter;

// One Range request's worth of a file. Short-form clips are a few of these.
constexpr uint64_t kChunkBytes = 1ull << 20;
// Chunks of anonymous files kept for every player and for preload.
constexpr uint64_t kSharedCacheBytes = 64ull << 20;
// Chunks a file with app headers keeps for its own stream.
constexpr size_t kPrivateChunks = 8;
// A server that ignores Range sends the whole file; past this, give up.
constexpr uint64_t kMaxWholeFileBytes = 256ull << 20;
// Files whose length and type are remembered.
constexpr size_t kMaxRememberedFiles = 1024;
constexpr wchar_t kDefaultContentType[] = L"video/mp4";

using Chunk = std::shared_ptr<const std::vector<uint8_t>>;

struct FileInfo {
  uint64_t size = 0;
  std::wstring content_type;
};

int64_t ElapsedMs(std::chrono::steady_clock::time_point since) {
  return std::chrono::duration_cast<std::chrono::milliseconds>(
             std::chrono::steady_clock::now() - since)
      .count();
}

uint8_t* BufferData(const IBuffer& buffer) {
  uint8_t* data = nullptr;
  auto access = buffer.as<::Windows::Storage::Streams::IBufferByteAccess>();
  winrt::check_hresult(access->Buffer(&data));
  return data;
}

// The B2 playback canary hosts and the Bunny playback host. Android's
// VideoCache keeps them out of its cache so every open checks the
// endpoint's policy instead of replaying an earlier approved copy.
constexpr const wchar_t* kUncachedHosts[] = {
    L"media-b2.divine.video", L"media-b2-cdn.divine.video",
    L"media-bunny.divine.video"};

bool IsUncachedHost(const std::string& uri) {
  winrt::hstring host;
  try {
    host = Uri(winrt::to_hstring(uri)).Host();
  } catch (const winrt::hresult_error&) {
    // Not a URI with a host, so not one of these.
    return false;
  }
  return std::any_of(std::begin(kUncachedHosts), std::end(kUncachedHosts),
                     [&host](const wchar_t* uncached) {
                       return _wcsicmp(host.c_str(), uncached) == 0;
                     });
}

bool IsRemoteProgressive(const std::string& uri) {
  std::string lower = uri;
  std::transform(lower.begin(), lower.end(), lower.begin(), [](unsigned char c) {
    return static_cast<char>(std::tolower(c));
  });
  return (lower.rfind("http://", 0) == 0 || lower.rfind("https://", 0) == 0) &&
         !IsHlsUri(uri);
}

// Chunks of files without app headers, shared by every player and by
// preload, least recently used first out. Never destroyed: it may still be
// in use on Media Foundation threads while the process exits.
class SharedChunkCache {
 public:
  static SharedChunkCache& Instance() {
    static SharedChunkCache* cache = new SharedChunkCache();
    return *cache;
  }

  std::optional<FileInfo> Info(const std::string& uri) {
    std::lock_guard<std::mutex> lock(mutex_);
    const auto it = infos_.find(uri);
    if (it == infos_.end()) return std::nullopt;
    return it->second;
  }

  void PutInfo(const std::string& uri, FileInfo info) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (infos_.size() >= kMaxRememberedFiles) infos_.clear();
    infos_[uri] = std::move(info);
  }

  Chunk Find(const std::string& uri, uint64_t index) {
    std::lock_guard<std::mutex> lock(mutex_);
    const auto it = chunks_.find({uri, index});
    if (it == chunks_.end()) return nullptr;
    order_.splice(order_.begin(), order_, it->second.second);
    return it->second.first;
  }

  void Put(const std::string& uri, uint64_t index, Chunk chunk) {
    std::lock_guard<std::mutex> lock(mutex_);
    const Key key{uri, index};
    if (chunks_.count(key) != 0) return;
    order_.push_front(key);
    bytes_ += chunk->size();
    chunks_[key] = {std::move(chunk), order_.begin()};
    while (bytes_ > kSharedCacheBytes && order_.size() > 1) {
      const auto oldest = chunks_.find(order_.back());
      bytes_ -= oldest->second.first->size();
      chunks_.erase(oldest);
      order_.pop_back();
    }
  }

 private:
  using Key = std::pair<std::string, uint64_t>;

  std::mutex mutex_;
  std::list<Key> order_;
  std::map<Key, std::pair<Chunk, std::list<Key>::iterator>> chunks_;
  uint64_t bytes_ = 0;
  std::map<std::string, FileInfo> infos_;
};

// Sends every request with a context's headers, through the system stack.
struct HeaderFilter
    : winrt::implements<HeaderFilter, IHttpFilter,
                        winrt::Windows::Foundation::IClosable> {
  explicit HeaderFilter(std::shared_ptr<const RequestContext> context)
      : context_(std::move(context)) {}

  IAsyncOperationWithProgress<HttpResponseMessage, HttpProgress>
  SendRequestAsync(const HttpRequestMessage& request) {
    context_->Apply(request);
    return inner_.SendRequestAsync(request);
  }

  void Close() { inner_.Close(); }

 private:
  std::shared_ptr<const RequestContext> context_;
  HttpBaseProtocolFilter inner_;
};

// What one Range request brought back.
struct Download {
  Chunk data;
  uint64_t total = 0;
  std::wstring content_type;
};

// Fetches bytes [start, end] of `uri`, reporting the request when it
// carries a load id.
IAsyncAction DownloadAsync(std::shared_ptr<const RequestContext> context,
                           HttpClient client, Uri uri, uint64_t start,
                           uint64_t end, std::shared_ptr<Download> out) {
  const std::optional<std::string> load_id = context->CurrentLoadId();
  const std::string request_id = load_id ? NewUuid() : std::string();
  const auto started = std::chrono::steady_clock::now();
  std::optional<int64_t> headers_ms;
  int64_t bytes = 0;
  const auto report = [&](const char* outcome, bool terminal) {
    if (!load_id) return;
    NetworkSample sample{request_id, outcome, headers_ms, std::nullopt,
                         std::nullopt};
    if (terminal) {
      sample.duration_ms = ElapsedMs(started);
      sample.bytes = bytes;
    }
    context->Report(*load_id, sample);
  };
  try {
    HttpRequestMessage request(HttpMethod::Get(), uri);
    request.Headers().TryAppendWithoutValidation(
        L"Range",
        L"bytes=" + winrt::to_hstring(start) + L"-" + winrt::to_hstring(end));
    HttpResponseMessage response = co_await client.SendRequestAsync(
        request, HttpCompletionOption::ResponseHeadersRead);
    const int32_t status = static_cast<int32_t>(response.StatusCode());
    if (status != 200 && status != 206) {
      // 202 is the media server still processing an upload.
      response.Close();
      throw winrt::hresult_error(HttpStatusHresult(status));
    }
    headers_ms = ElapsedMs(started);
    report("unavailable", false);

    const auto content_headers = response.Content().Headers();
    out->content_type = kDefaultContentType;
    if (const auto type = content_headers.ContentType()) {
      out->content_type = type.MediaType().c_str();
    }
    if (status == 206) {
      // Content-Range: bytes <start>-<end>/<total>
      if (content_headers.HasKey(L"Content-Range")) {
        const std::wstring text(content_headers.Lookup(L"Content-Range"));
        const size_t slash = text.rfind(L'/');
        if (slash != std::wstring::npos) {
          out->total = std::wcstoull(text.c_str() + slash + 1, nullptr, 10);
        }
      }
    } else if (const auto length = content_headers.ContentLength()) {
      if (length.Value() > kMaxWholeFileBytes) {
        response.Close();
        throw winrt::hresult_error(E_OUTOFMEMORY,
                                   L"Server sent the whole file, too large");
      }
    }

    const IBuffer body = co_await response.Content().ReadAsBufferAsync();
    bytes = body.Length();
    const uint8_t* source = BufferData(body);
    // A server that ignores Range sends the whole file from byte 0.
    const uint64_t skip = status == 200 ? start : 0;
    if (status == 200) out->total = body.Length();
    const uint64_t available = body.Length() > skip ? body.Length() - skip : 0;
    const uint64_t wanted = end - start + 1;
    const size_t length = static_cast<size_t>(std::min(available, wanted));
    out->data = std::make_shared<const std::vector<uint8_t>>(
        source + skip, source + skip + length);
    report("complete", true);
  } catch (const winrt::hresult_canceled&) {
    report("cancelled", true);
    throw;
  } catch (...) {
    report("error", true);
    throw;
  }
}

// One remote file as every stream over it sees it: its length, its chunks
// and the fetches in flight.
class RangeFile : public std::enable_shared_from_this<RangeFile> {
 public:
  // A fetch other readers of the same chunk wait for.
  struct Fetch {
    winrt::handle done{CreateEventW(nullptr, TRUE, FALSE, nullptr)};
    Chunk data;
    winrt::hresult error{S_OK};
  };

  RangeFile(std::shared_ptr<const RequestContext> context, HttpClient client,
            FileInfo info)
      : context_(std::move(context)),
        client_(std::move(client)),
        uri_(winrt::to_hstring(context_->uri())),
        info_(std::move(info)),
        shared_(context_->shareable()) {}

  uint64_t size() const { return info_.size; }
  uint64_t chunk_count() const { return (info_.size + kChunkBytes - 1) / kChunkBytes; }

  Chunk Cached(uint64_t index) {
    if (shared_) return SharedChunkCache::Instance().Find(context_->uri(), index);
    std::lock_guard<std::mutex> lock(mutex_);
    const auto it = private_chunks_.find(index);
    return it == private_chunks_.end() ? nullptr : it->second;
  }

  void Store(uint64_t index, Chunk chunk) {
    if (shared_) {
      SharedChunkCache::Instance().Put(context_->uri(), index, std::move(chunk));
      return;
    }
    std::lock_guard<std::mutex> lock(mutex_);
    if (private_chunks_.count(index) != 0) return;
    private_chunks_[index] = std::move(chunk);
    private_order_.push_back(index);
    if (private_order_.size() > kPrivateChunks) {
      private_chunks_.erase(private_order_.front());
      private_order_.pop_front();
    }
  }

  // The fetch of chunk `index`, started unless one is already running.
  std::shared_ptr<Fetch> StartFetch(uint64_t index) {
    std::shared_ptr<Fetch> fetch;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      auto& running = in_flight_[index];
      if (running) return running;
      running = fetch = std::make_shared<Fetch>();
    }
    Run(shared_from_this(), index, fetch);
    return fetch;
  }

  // Starts fetching chunk `index` ahead of the reader, if it is not here.
  void Prefetch(uint64_t index) {
    if (index >= chunk_count() || Cached(index)) return;
    StartFetch(index);
  }

 private:
  static winrt::fire_and_forget Run(std::shared_ptr<RangeFile> file,
                                    uint64_t index,
                                    std::shared_ptr<Fetch> fetch) {
    try {
      const uint64_t start = index * kChunkBytes;
      const uint64_t end = std::min(start + kChunkBytes, file->info_.size) - 1;
      auto download = std::make_shared<Download>();
      co_await DownloadAsync(file->context_, file->client_, file->uri_, start,
                             end, download);
      fetch->data = download->data;
      file->Store(index, download->data);
    } catch (const winrt::hresult_error& error) {
      fetch->error = error.code();
    } catch (...) {
      fetch->error = E_FAIL;
    }
    {
      std::lock_guard<std::mutex> lock(file->mutex_);
      file->in_flight_.erase(index);
    }
    SetEvent(fetch->done.get());
  }

  std::shared_ptr<const RequestContext> context_;
  HttpClient client_;
  Uri uri_;
  FileInfo info_;
  bool shared_;
  std::mutex mutex_;
  std::map<uint64_t, Chunk> private_chunks_;
  std::deque<uint64_t> private_order_;
  std::map<uint64_t, std::shared_ptr<Fetch>> in_flight_;
};

// A read-only stream over a RangeFile. MediaSource.CreateFromUri cannot
// send headers, and reading through chunks turns Media Foundation's many
// small reads into a few Range requests.
struct HttpRangeStream
    : winrt::implements<HttpRangeStream, IRandomAccessStream, IInputStream,
                        IOutputStream, winrt::Windows::Foundation::IClosable> {
  explicit HttpRangeStream(std::shared_ptr<RangeFile> file, uint64_t position = 0)
      : file_(std::move(file)), position_(position) {}

  uint64_t Size() const { return file_->size(); }
  void Size(uint64_t) { throw winrt::hresult_not_implemented(); }
  uint64_t Position() const { return position_; }
  void Seek(uint64_t position) { position_ = position; }
  bool CanRead() const { return true; }
  bool CanWrite() const { return false; }

  IRandomAccessStream CloneStream() { return winrt::make<HttpRangeStream>(file_); }

  IInputStream GetInputStreamAt(uint64_t position) {
    return winrt::make<HttpRangeStream>(file_, position);
  }

  IOutputStream GetOutputStreamAt(uint64_t) {
    throw winrt::hresult_not_implemented();
  }

  IAsyncOperationWithProgress<uint32_t, uint32_t> WriteAsync(IBuffer) {
    throw winrt::hresult_not_implemented();
  }

  IAsyncOperation<bool> FlushAsync() { throw winrt::hresult_not_implemented(); }

  void Close() {}

  IAsyncOperationWithProgress<IBuffer, uint32_t> ReadAsync(
      IBuffer buffer, uint32_t count, InputStreamOptions) {
    auto strong = get_strong();
    std::shared_ptr<RangeFile> file = file_;
    uint64_t position = position_;
    const uint32_t wanted = std::min(count, buffer.Capacity());
    uint8_t* out = BufferData(buffer);
    uint32_t written = 0;
    uint64_t index = position / kChunkBytes;
    while (written < wanted && position < file->size()) {
      index = position / kChunkBytes;
      Chunk chunk = file->Cached(index);
      if (!chunk) {
        const std::shared_ptr<RangeFile::Fetch> fetch = file->StartFetch(index);
        co_await winrt::resume_on_signal(fetch->done.get());
        winrt::check_hresult(fetch->error);
        chunk = fetch->data;
      }
      const uint64_t offset = position - index * kChunkBytes;
      if (!chunk || offset >= chunk->size()) break;
      const uint32_t length = static_cast<uint32_t>(
          std::min<uint64_t>(wanted - written, chunk->size() - offset));
      std::memcpy(out + written, chunk->data() + offset, length);
      written += length;
      position += length;
    }
    // Media Foundation reads a file front to back, so fetch ahead of it.
    file->Prefetch(index + 1);
    buffer.Length(written);
    strong->position_ = position;
    co_return buffer;
  }

 private:
  std::shared_ptr<RangeFile> file_;
  uint64_t position_;
};

void ReportAdaptive(const RequestContext& context,
                    const AdaptiveMediaSourceDownloadStatistics& statistics,
                    const char* outcome) {
  const std::optional<std::string> load_id = context.CurrentLoadId();
  if (!load_id || !statistics) return;
  const auto to_ms = [](const auto& time) -> std::optional<int64_t> {
    if (!time) return std::nullopt;
    return std::chrono::duration_cast<std::chrono::milliseconds>(time.Value())
        .count();
  };
  const std::string request_id = NewUuid();
  const std::optional<int64_t> headers_ms =
      to_ms(statistics.TimeToHeadersReceived());
  if (headers_ms) {
    context.Report(*load_id, {request_id, "unavailable", headers_ms,
                              std::nullopt, std::nullopt});
  }
  context.Report(*load_id,
                 {request_id, outcome, headers_ms,
                  to_ms(statistics.TimeToLastByteReceived()),
                  static_cast<int64_t>(statistics.ContentBytesReceivedCount())});
}

}  // namespace

RequestContext::RequestContext(
    std::string uri, const std::map<std::string, std::string>& headers,
    std::shared_ptr<const PlaybackTelemetry> telemetry)
    : uri_(std::move(uri)), telemetry_(std::move(telemetry)) {
  for (const auto& [name, value] : headers) {
    if (!IsPlaybackLoadIdHeader(name)) {
      headers_[name] = value;
    } else if (IsValidLoadId(value)) {
      load_id_ = value;
    }
  }
  shareable_ = headers_.empty() && !IsUncachedHost(uri_);
}

std::optional<std::string> RequestContext::CurrentLoadId() const {
  if (!load_id_ || !telemetry_ || !telemetry_->IsCurrent(uri_, *load_id_)) {
    return std::nullopt;
  }
  return load_id_;
}

void RequestContext::Apply(const HttpRequestMessage& request) const {
  const auto headers = request.Headers();
  for (const auto& [name, value] : headers_) {
    headers.TryAppendWithoutValidation(winrt::to_hstring(name),
                                       winrt::to_hstring(value));
  }
  // Revoked loads stop correlating at the next request, as on Android.
  if (const std::optional<std::string> load_id = CurrentLoadId()) {
    headers.TryAppendWithoutValidation(winrt::to_hstring(kPlaybackLoadIdHeader),
                                       winrt::to_hstring(*load_id));
  }
}

void RequestContext::Report(const std::string& load_id,
                            const NetworkSample& sample) const {
  if (telemetry_) telemetry_->Report(uri_, load_id, sample);
}

HttpClient ClientFor(std::shared_ptr<const RequestContext> context) {
  return HttpClient(winrt::make<HeaderFilter>(std::move(context)));
}

IAsyncOperation<MediaSource> OpenRangeSourceAsync(
    std::shared_ptr<const RequestContext> context) {
  HttpClient client = ClientFor(context);
  const bool shared = context->shareable();
  std::optional<FileInfo> info;
  if (shared) info = SharedChunkCache::Instance().Info(context->uri());
  std::shared_ptr<RangeFile> file;
  if (info) {
    // Preloaded or played before: Media Foundation's first reads come from
    // memory, and anything missing is fetched as it reads.
    file = std::make_shared<RangeFile>(context, client, *info);
  } else {
    auto first = std::make_shared<Download>();
    co_await DownloadAsync(context, client, Uri(winrt::to_hstring(context->uri())),
                           0, kChunkBytes - 1, first);
    if (first->total == 0) {
      throw winrt::hresult_error(E_FAIL, L"Unknown content length");
    }
    info = FileInfo{first->total, first->content_type};
    file = std::make_shared<RangeFile>(context, client, *info);
    file->Store(0, first->data);
    if (shared) SharedChunkCache::Instance().PutInfo(context->uri(), *info);
  }
  co_return MediaSource::CreateFromStream(winrt::make<HttpRangeStream>(file),
                                          winrt::hstring(info->content_type));
}

void ObserveAdaptiveDownloads(const AdaptiveMediaSource& source,
                              std::shared_ptr<const RequestContext> context) {
  source.DownloadCompleted(
      [context](const AdaptiveMediaSource&,
                const AdaptiveMediaSourceDownloadCompletedEventArgs& args) {
        ReportAdaptive(*context, args.Statistics(), "complete");
      });
  source.DownloadFailed(
      [context](const AdaptiveMediaSource&,
                const AdaptiveMediaSourceDownloadFailedEventArgs& args) {
        ReportAdaptive(*context, args.Statistics(), "error");
      });
}

IAsyncAction PreloadAsync(std::string uri) {
  if (!IsRemoteProgressive(uri)) co_return;
  // As on Android, preload sends no app headers and no load id.
  auto context = std::make_shared<const RequestContext>(
      uri, std::map<std::string, std::string>{}, nullptr);
  // Nothing a player could take from the shared cache.
  if (!context->shareable()) co_return;
  SharedChunkCache& cache = SharedChunkCache::Instance();
  if (cache.Info(uri) && cache.Find(uri, 0)) co_return;
  auto first = std::make_shared<Download>();
  try {
    co_await DownloadAsync(context, ClientFor(context),
                           Uri(winrt::to_hstring(uri)), 0, kChunkBytes - 1,
                           first);
  } catch (...) {
    // Best effort: the player fetches it again when it opens the file.
    co_return;
  }
  if (first->total == 0 || !first->data) co_return;
  cache.Put(uri, 0, first->data);
  cache.PutInfo(uri, FileInfo{first->total, first->content_type});
}

}  // namespace divine_video_player
