import 'dart:io'
    if (dart.library.js_interop) 'package:openvine/utils/platform_io_web.dart'
    as io;

import 'package:web_socket_channel/web_socket_channel.dart';

/// Prefix `dart:io` gives every DNS resolution failure.
///
/// `dart:io` builds this text itself rather than taking it from the OS:
/// `_NativeSocket.lookup` and `_NativeSocket._resolveHost` both interpolate
/// `"Failed host lookup: '$host'"`. Everything the platform contributes lands
/// in the separate `osError` field, so the prefix does not vary by OS or
/// locale the way an `errno` or a strerror string does.
const _hostLookupFailure = 'Failed host lookup:';

/// Prefix google_fonts gives a font fetch that failed in transport.
///
/// `_httpFetchFontAndSaveToDevice` catches the `http` failure and rethrows
/// `Exception('Failed to load font with url $url: $e')`, so the inner type is
/// gone by the time anything can classify it. Its two other throws read
/// `Failed to load font with url: $url` (a non-200) and
/// `did not match expected length and checksum` — neither carries a transport
/// marker, so neither is silenced here.
const _fontFetchFailure = 'Failed to load font with url';

/// `package:http`'s transport failure, matched as text for the same reason.
const _clientException = 'ClientException';

/// Whether [error] is an expected network failure that should not be reported.
///
/// Being offline, sitting behind a captive portal, or running on a network
/// without working DNS is a normal state rather than a defect, which is why
/// the decision matrix in `.claude/rules/error_handling.md` puts "Network /
/// IO (timeout, dropped connection, DNS)" in the not-reportable row. Crash
/// reporters call this to drop such errors; nothing else changes, so the
/// connection retry, the relay state machine, and the UI's own offline
/// handling all still see the failure.
///
/// Both types it inspects are wider than the failure they usually carry, so
/// neither is trusted on type alone:
///
/// * A SocketException counts only when its message is a DNS resolution
///   failure. Every other socket error stays reportable — notably the
///   `Bad file descriptor` raised by a leaked or double-closed descriptor,
///   which is the one signal that would show such a leak.
/// * A WebSocketChannelException is unwrapped instead, because
///   `AdapterWebSocketChannel` wraps *every* connect error in it. Recursing on
///   `inner` keeps a TLS HandshakeException and the ArgumentError from a
///   malformed relay URI reportable; silencing those would mean never
///   connecting to that relay and never hearing why. A wrapper with no `inner`
///   carries nothing to classify and stays expected.
///
/// A connect `TimeoutException` is the one error the wrapper passes through
/// untouched, so it reaches neither branch and is still reported.
///
/// A third branch matches text rather than a type, because google_fonts
/// reports a failed font fetch as a bare `Exception` carrying the transport
/// error only as a string. It is scoped to that wrapper's own prefix, so an
/// unrelated error that merely mentions a transport failure stays reportable,
/// and to the transport markers, so a checksum mismatch or a non-200 from the
/// font CDN stays reportable too.
///
/// On web the `dart:io` half resolves to a stub whose `SocketException` is
/// never instantiated, so the first check is simply always false there.
bool isExpectedNetworkFailure(Object error) {
  if (error is io.SocketException) {
    return error.message.startsWith(_hostLookupFailure);
  }
  if (error is WebSocketChannelException) {
    final inner = error.inner;
    return inner == null || isExpectedNetworkFailure(inner);
  }
  // Text, not type: google_fonts has already stringified the inner error,
  // and no `try`/`catch` of ours can reach this throw anyway. The font load
  // is registered with a `.then` that carries no `onError` (google_fonts
  // 6.3.3, `google_fonts_base.dart:112`), so the derived future's error has
  // no listener and reaches the zone handler however the caller guards its
  // own await. `preloadEditorTextFonts` already catches the half it can see,
  // on `pendingFonts()`; this is the orphaned half.
  final text = error.toString();
  if (text.contains(_fontFetchFailure)) {
    return text.contains(_hostLookupFailure) || text.contains(_clientException);
  }
  return false;
}
