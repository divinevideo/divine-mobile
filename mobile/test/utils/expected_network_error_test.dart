import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:openvine/utils/expected_network_error.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  group('isExpectedNetworkFailure', () {
    group('SocketException', () {
      test('treats a media host lookup failure as expected', () {
        // The signature behind the `dart:_http - _HttpClient.getUrl` and
        // `video_thumbnail_widget.dart - _resolveImageStream` non-fatals.
        const error = SocketException(
          "Failed host lookup: 'media.divine.video'",
          osError: OSError(
            'nodename nor servname provided, or not known',
            8,
          ),
        );

        expect(isExpectedNetworkFailure(error), isTrue);
      });

      test('reports a self-inflicted socket error', () {
        // EBADF means the app read a descriptor it had already closed, or ran
        // out of descriptors — a lifecycle bug, not a flaky network. #7310
        // tracks a live socket leak in `WebSocketConnectionManager`, so this
        // must keep reaching Crashlytics or the leak loses its only signal.
        const error = SocketException(
          'OS Error: Bad file descriptor',
          osError: OSError('Bad file descriptor', 9),
        );

        expect(isExpectedNetworkFailure(error), isFalse);
      });

      test('reports a refused connection', () {
        // DNS resolved; the peer answered. That is not the offline state the
        // predicate exists to drop.
        const error = SocketException(
          'Connection refused',
          osError: OSError('Connection refused', 61),
          port: 443,
        );

        expect(isExpectedNetworkFailure(error), isFalse);
      });
    });

    group('WebSocketChannelException', () {
      test('treats a handshake that failed on DNS as expected', () {
        // The relay transport wraps the socket error rather than rethrowing
        // it, so a bare `SocketException` check misses every relay DNS
        // failure.
        final error = WebSocketChannelException.from(
          const SocketException("Failed host lookup: 'relay.divine.video'"),
        );

        expect(isExpectedNetworkFailure(error), isTrue);
      });

      test('reports a TLS handshake failure', () {
        // `IOWebSocket.connect` only converts `WebSocketException`, so a bad
        // or expired relay certificate arrives inside the wrapper untouched.
        // Dropping it would leave the app silently unable to reach that relay.
        final error = WebSocketChannelException.from(
          const HandshakeException('Handshake error in client'),
        );

        expect(isExpectedNetworkFailure(error), isFalse);
      });

      test('reports a malformed relay URI', () {
        // `IOWebSocket.connect` rejects a non-ws scheme with `ArgumentError`,
        // which the adapter wraps like any other connect failure. It is a
        // config defect that no amount of retrying fixes.
        final error = WebSocketChannelException.from(
          ArgumentError.value(
            Uri.parse('https://relay.divine.video'),
            'url',
            'only ws: and wss: schemes are supported',
          ),
        );

        expect(isExpectedNetworkFailure(error), isFalse);
      });

      test('reports a malformed relay URI that failed to parse', () {
        final error = WebSocketChannelException.from(
          const FormatException('Invalid port', 'wss://relay.divine.video:xx'),
        );

        expect(isExpectedNetworkFailure(error), isFalse);
      });

      test('reports a rejected websocket upgrade', () {
        // A non-101 response reaches the wrapper as a `WebSocketException`,
        // not a socket error, so unwrapping keeps it reportable. A relay that
        // answers every handshake with 502 is broken, not offline.
        final error = WebSocketChannelException.from(
          const WebSocketException(
            "Connection to 'https://relay.divine.video' was not upgraded to "
            'websocket',
            502,
          ),
        );

        expect(isExpectedNetworkFailure(error), isFalse);
      });

      test('treats a wrapper with nothing inside as expected', () {
        // The message-only constructor carries no inner error to classify.
        // With nothing to inspect, the wrapper keeps its old meaning: the
        // transport could not connect.
        final error = WebSocketChannelException(
          'WebSocket connection failed.',
        );

        expect(error.inner, isNull);
        expect(isExpectedNetworkFailure(error), isTrue);
      });

      test('reports a wrapped self-inflicted socket error', () {
        // A leaked descriptor is no less a defect for having crossed the
        // relay transport, so wrapping must not change the verdict.
        final error = WebSocketChannelException.from(
          const SocketException(
            'OS Error: Bad file descriptor',
            osError: OSError('Bad file descriptor', 9),
          ),
        );

        expect(isExpectedNetworkFailure(error), isFalse);
      });
    });

    group('google_fonts font fetch', () {
      // google_fonts reports the fetch failure as a bare `Exception` whose
      // message is the transport error stringified, on a future nothing
      // listens to — so the zone handler is the only place left to classify
      // it. Both messages below are the shipped 1.0.22 non-fatals.
      const fontUrl = 'https://fonts.gstatic.com/s/a/e3bb63f2cd24.ttf';

      test('treats a font fetch that failed on DNS as expected', () {
        final error = Exception(
          'Failed to load font with url $fontUrl: ClientException with '
          "SocketException: Failed host lookup: 'fonts.gstatic.com' "
          '(OS Error: nodename nor servname provided, or not known, '
          'errno = 8)',
        );

        expect(isExpectedNetworkFailure(error), isTrue);
      });

      test('treats a dropped font connection as expected', () {
        final error = Exception(
          'Failed to load font with url $fontUrl: ClientException: '
          'Connection closed before full header was received, uri=$fontUrl',
        );

        expect(isExpectedNetworkFailure(error), isTrue);
      });

      test('reports a font the CDN answered with a non-200', () {
        // No transport marker: the request completed and the server said no,
        // which is worth hearing about for a font we pin by hash.
        final error = Exception('Failed to load font with url: $fontUrl');

        expect(isExpectedNetworkFailure(error), isFalse);
      });

      test('reports a font whose bytes failed the checksum', () {
        // Integrity, not connectivity — this is the one font failure that
        // would mean something served us the wrong file.
        final error = Exception(
          'File from $fontUrl did not match expected length and checksum.',
        );

        expect(isExpectedNetworkFailure(error), isFalse);
      });
    });

    group('unrelated errors', () {
      test('does not treat a programming-invariant violation as expected', () {
        expect(
          isExpectedNetworkFailure(StateError('No public key available')),
          isFalse,
        );
      });

      test('does not treat a media decode failure as expected', () {
        // A broken image is recoverable but not a network failure — it keeps
        // its existing non-fatal report.
        expect(
          isExpectedNetworkFailure(
            const MediaCacheImageLoadException('https://media.divine.video/x'),
          ),
          isFalse,
        );
      });

      test(
        'does not treat an error that merely mentions a host lookup as '
        'expected',
        () {
          // The message check is scoped to `SocketException`, so prose about a
          // lookup in an unrelated failure must not silence it.
          expect(
            isExpectedNetworkFailure(
              Exception("Failed host lookup: 'relay.divine.video' in config"),
            ),
            isFalse,
          );
        },
      );
    });
  });
}
