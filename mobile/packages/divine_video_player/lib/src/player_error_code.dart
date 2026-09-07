/// Canonical error codes emitted by the native player, normalised across
/// Android (Media3 PlaybackException) and iOS (AVFoundation / NSURLError).
///
/// Native code maps platform-specific codes to these string values before
/// sending them over the event channel in the `errorCode` key.
///
/// This lets Dart make reliable, platform-independent retry/failover
/// decisions without string-parsing the raw error message.
enum NativePlayerErrorCode {
  /// HTTP 202 from Divine media while renditions are still processing.
  ///
  /// Android: `ERROR_CODE_IO_BAD_HTTP_STATUS` with response code 202.
  /// iOS: CoreMedia / AVFoundation errors whose message includes HTTP 202.
  mediaProcessing,

  /// Authentication is required to load the media.
  ///
  /// Android: `ERROR_CODE_IO_BAD_HTTP_STATUS` with response code 401.
  /// iOS: HTTP 401 in `userInfo` or `NSURLErrorUserAuthenticationRequired`.
  authRequired,

  /// HTTP 403 from the media server.
  ///
  /// The server acknowledged the request and refused it outright, so no
  /// credential the client can supply will change the answer. Divine returns
  /// this for moderation-blocked media, but the player cannot see the reason,
  /// so this code names the transport fact rather than the policy behind it.
  ///
  /// Android: `ERROR_CODE_IO_BAD_HTTP_STATUS` with response code 403.
  /// iOS: HTTP 403 in `userInfo`.
  forbidden,

  /// HTTP 404 from the media server.
  ///
  /// The blob is absent from *this* source. Divine media is mirrored across
  /// Blossom servers, so a 404 is per-source evidence and not proof the media
  /// is gone — see [shouldFailover].
  ///
  /// Android: `ERROR_CODE_IO_BAD_HTTP_STATUS` with response code 404.
  /// iOS: HTTP 404 in `userInfo`.
  notFound,

  /// HTTP 4xx response from the media server.
  ///
  /// Android: `ERROR_CODE_IO_BAD_HTTP_STATUS` when 400–499, except 401,
  /// 403, and 404.
  /// iOS: `NSError` with HTTP status in `userInfo`, except 401, 403, and 404.
  httpClientError,

  /// HTTP 5xx response from the media server.
  ///
  /// Android: `ERROR_CODE_IO_BAD_HTTP_STATUS` when 500+.
  /// iOS: `NSError` with HTTP status in `userInfo`.
  httpServerError,

  /// Network is unavailable or the connection was lost before the response
  /// arrived.
  ///
  /// Android: `ERROR_CODE_IO_NETWORK_CONNECTION_FAILED`.
  /// iOS: `NSURLErrorNotConnectedToInternet`,
  /// `NSURLErrorNetworkConnectionLost`.
  networkError,

  /// Connection timed out.
  ///
  /// Android: `ERROR_CODE_IO_NETWORK_CONNECTION_TIMEOUT`.
  /// iOS: `NSURLErrorTimedOut`.
  timeout,

  /// The platform reported an I/O failure that is not a concrete HTTP,
  /// network, timeout, or auth condition.
  ///
  /// Android: residual `ERROR_CODE_IO_*` values in the 2xxx range.
  ioError,

  /// The media container or segment could not be parsed.
  ///
  /// Android: `ERROR_CODE_PARSING_*` (3xxx range).
  /// iOS: `AVErrorUnknown` or format-related AVError codes.
  parseError,

  /// The device's codec/decoder failed.
  ///
  /// Android: `ERROR_CODE_DECODER_*` (4xxx range).
  /// iOS: `AVErrorNoCompatibleAlternatesForExternalDisplay` or decoder errors.
  decoderError,

  /// Any other error that does not fit the categories above.
  unknown;

  /// Whether a source failover should be attempted for this error code.
  ///
  /// This is the routing decision axis: when `true`, callers should advance
  /// to the next source instead of retrying the current one.
  ///
  /// Network / timeout errors are transient and should stay on the same
  /// source. Auth errors apply to the whole media asset and should surface
  /// immediately. Other HTTP 4xx/5xx and parse errors indicate the current
  /// source is not usable right now, so the feed should skip to the next
  /// available source.
  ///
  /// [forbidden] and [notFound] fail over for that reason: both are answers
  /// from one server about one URL, and Divine media is mirrored, so the next
  /// source may still serve the blob. They are terminal for the *source*, not
  /// for the media.
  bool get shouldFailover => switch (this) {
    mediaProcessing => false,
    authRequired => false,
    forbidden => true,
    notFound => true,
    httpClientError => true,
    httpServerError => true,
    ioError => true,
    parseError => true,
    networkError => false,
    timeout => false,
    decoderError => false,
    unknown => false,
  };

  /// Whether this error is worth retrying (same source, no failover).
  ///
  /// This is only for same-source retry decisions and must not overlap with
  /// [shouldFailover] for the same error code.
  ///
  /// Transient conditions like network loss or timeout may resolve on retry.
  bool get isTransient => switch (this) {
    mediaProcessing => true,
    networkError => true,
    timeout => true,
    ioError => false,
    authRequired => false,
    forbidden => false,
    notFound => false,
    httpServerError => false,
    httpClientError => false,
    parseError => false,
    decoderError => false,
    unknown => false,
  };

  /// Parses the string value sent over the platform channel.
  static NativePlayerErrorCode fromString(String value) => switch (value) {
    'media_processing' => mediaProcessing,
    'auth_required' => authRequired,
    'forbidden' => forbidden,
    'not_found' => notFound,
    'http_client_error' => httpClientError,
    'http_server_error' => httpServerError,
    'network_error' => networkError,
    'timeout' => timeout,
    'io_error' => ioError,
    'parse_error' => parseError,
    'decoder_error' => decoderError,
    _ => unknown,
  };
}
