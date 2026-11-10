// ABOUTME: Pure bridge helpers for the Nostr app sandbox — bootstrap script
// ABOUTME: builder, HTML injection, origin matching and web-message rules.

/// Builds the bridge bootstrap JavaScript with optional eager pubkey,
/// provider metadata, ready-event dispatch, and per-app auto-login.
///
/// [nonce] is a per-mount secret embedded in every outgoing bridge
/// request. The host rejects messages whose nonce does not match,
/// which prevents iframes that bypass `window.nostr` and call the
/// `divineSandboxBridge` channel directly from impersonating the main
/// frame.
String buildBridgeBootstrapScript({
  required String nonce,
  String? pubkey,
  String? autoLoginScript,
}) {
  final escapedPubkey = pubkey != null && pubkey.isNotEmpty
      ? _escapeJs(pubkey)
      : '';
  final escapedNonce = _escapeJs(nonce);
  final loginJs = autoLoginScript != null && autoLoginScript.isNotEmpty
      ? autoLoginScript.replaceAll('{{PUBKEY}}', escapedPubkey)
      : '';

  return '''
(() => {
  if (window.__divineNostrBridgeInstalled) {
    return;
  }

  // Refuse to install in non-main frames. Cross-origin access to
  // window.top throws; treat that as "not main frame" and bail.
  try {
    if (window.top !== window.self) {
      return;
    }
  } catch (_) {
    return;
  }

  const __divineBridgeNonce = '$escapedNonce';
  const pending = new Map();
  let nextId = 0;

  const request = (method, args) => {
    const id = `divine-\${++nextId}`;
    const payload = JSON.stringify({
      id,
      method,
      args: args ?? {},
      nonce: __divineBridgeNonce,
    });

    return new Promise((resolve, reject) => {
      pending.set(id, { resolve, reject });
      divineSandboxBridge.postMessage(payload);
    });
  };

  window.__divineNostrBridge = {
    handleResponse(response) {
      const pendingRequest = pending.get(response.id);
      if (!pendingRequest) {
        return;
      }

      pending.delete(response.id);

      if (response.success) {
        pendingRequest.resolve(response.result);
        return;
      }

      const error = response.error || { code: 'bridge_error' };
      const exception = new Error(error.message || error.code);
      exception.code = error.code;
      pendingRequest.reject(exception);
    },
  };

  window.nostr = {
    _pubkey: '$escapedPubkey' || null,
    _metadata: {
      name: 'Divine',
      version: '1.0',
      supports: ['nip44'],
    },
    getPublicKey() {
      if (this._pubkey) return Promise.resolve(this._pubkey);
      return request('getPublicKey', {});
    },
    getRelays() {
      return request('getRelays', {});
    },
    signEvent(event) {
      return request('signEvent', { event });
    },
    nip44: {
      encrypt(pubkey, plaintext) {
        return request('nip44.encrypt', { pubkey, plaintext });
      },
      decrypt(pubkey, ciphertext) {
        return request('nip44.decrypt', { pubkey, ciphertext });
      },
    },
  };

  window.__divineNostrBridgeInstalled = true;

  // Auto-login: seed localStorage so the app recognises the session.
  // Failures are non-fatal; the app still works without the seed.
  try { $loginJs } catch (_) { /* best-effort */ }

  // Signal that a NIP-07 signer is available.
  window.dispatchEvent(new Event('nostr:ready'));
  document.dispatchEvent(new CustomEvent('nlAuth', {
    detail: { type: 'login', method: 'extension' },
  }));
})();
''';
}

/// The `scheme://host[:port]` web origin of [uri], or `null` when it has none.
///
/// Only `http`/`https` URIs with a host have one. `Uri.origin` throws a
/// `StateError` for anything else, and the WebView reports such pages
/// (`data:`, `about:blank`, `blob:`, `file:`) as ordinary page URLs.
String? webOriginOf(Uri uri) {
  const originSchemes = {'http', 'https'};
  if (uri.host.isEmpty || !originSchemes.contains(uri.scheme)) {
    return null;
  }
  return uri.origin;
}

/// Whether [uri] is on one of the web origins in [allowedOrigins].
///
/// Fails closed: a URI without a web origin never matches, so a `data:`,
/// `about:` or `blob:` page is never treated as an allowed origin, even when
/// it was created by one. Allowed entries without a web origin are ignored.
bool isAllowedSandboxOrigin(Uri uri, List<String> allowedOrigins) {
  final origin = webOriginOf(uri);
  return origin != null &&
      webMessageAllowedOriginRules(allowedOrigins).contains(origin);
}

/// Normalises an app's allowed origins to `scheme://host[:port]` rules: the
/// form [isAllowedSandboxOrigin] matches on every platform, and the rules
/// `WebViewCompat.addWebMessageListener` takes on Android. Only entries with
/// a web origin survive (see [webOriginOf]): a websocket URL (`ws`/`wss`) or a
/// `nostrsigner:` entry can never be a web frame's origin, so it is
/// meaningless for both. Unparseable entries are dropped too, so the result
/// is always a valid rule set the native side can pass through.
List<String> webMessageAllowedOriginRules(List<String> allowedOrigins) {
  final rules = <String>[];
  for (final origin in allowedOrigins) {
    final parsed = Uri.tryParse(origin);
    final rule = parsed == null ? null : webOriginOf(parsed);
    if (rule != null) {
      rules.add(rule);
    }
  }
  return rules;
}

/// Escapes a string for safe embedding inside a JS single-quoted
/// literal.
String _escapeJs(String value) {
  return value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('`', r'\`')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r');
}

/// Injects the bridge bootstrap `<script>` into [html] at the earliest of
/// `<head>`, `<!doctype>`, `<html>`, or `<body>`, falling back to prepending
/// it when none are present.
String injectBridgeBootstrapIntoHtml(
  String html, {
  required String nonce,
  String? pubkey,
  String? autoLoginScript,
}) {
  final script = buildBridgeBootstrapScript(
    nonce: nonce,
    pubkey: pubkey,
    autoLoginScript: autoLoginScript,
  );
  final bridgeMarkup = '<!-- divine-nostr-bridge --><script>$script</script>';
  final insertionPoints = <RegExp>[
    RegExp('<head[^>]*>', caseSensitive: false),
    RegExp('<!doctype[^>]*>', caseSensitive: false),
    RegExp('<html[^>]*>', caseSensitive: false),
    RegExp('<body[^>]*>', caseSensitive: false),
  ];

  for (final insertionPoint in insertionPoints) {
    final match = insertionPoint.firstMatch(html);
    if (match != null) {
      return html.replaceRange(match.end, match.end, bridgeMarkup);
    }
  }

  return '$bridgeMarkup$html';
}
