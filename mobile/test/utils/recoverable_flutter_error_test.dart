import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart'
    show HttpExceptionWithStatus;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_cache/media_cache.dart';
import 'package:openvine/utils/recoverable_flutter_error.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  group('classifyRecoverableFlutterError', () {
    test('classifies image 404 codec failures as recoverable', () {
      final details = FlutterErrorDetails(
        exception: Exception(
          'HTTP request failed, statusCode: 404, '
          'https://cdn.divine.video/test/thumbnails/thumbnail.jpg. '
          'Error thrown resolving an image codec.',
        ),
        library: 'package:flutter/src/painting/_network_image_io.dart',
      );

      expect(classifyRecoverableFlutterError(details), (
        reason: 'Recoverable media load failure',
        report: true,
      ));
    });

    // A raw NetworkImage that fails with a non-404 HTTP status (401, 403, 500,
    // …) is just as recoverable as a 404 — the widget falls back to a
    // placeholder. Before this was broadened, only 404 was downgraded, so
    // these slipped through as FATAL Crashlytics reports
    // (issue 72eb9f44799fa6513097c0049f68bc3b was dominated by 401/500).
    for (final statusCode in const [401, 403, 500, 502]) {
      test('classifies image $statusCode codec failures as recoverable', () {
        final details = FlutterErrorDetails(
          exception: Exception(
            'HTTP request failed, statusCode: $statusCode, '
            'https://media.divine.video/hash.jpg. '
            'Error thrown resolving an image codec.',
          ),
          context: ErrorDescription('resolving an image codec'),
          library: 'image resource service',
        );

        expect(classifyRecoverableFlutterError(details), (
          reason: 'Recoverable media load failure',
          report: true,
        ));
      });
    }

    test('classifies Divine media host lookup failures as unreported', () {
      const details = FlutterErrorDetails(
        exception: SocketException("Failed host lookup: 'media.divine.video'"),
        library: 'dart:_http',
      );

      expect(classifyRecoverableFlutterError(details), (
        reason: 'Expected network failure',
        report: false,
      ));
    });

    // Pins the legacy Vine hosts' _recoverableMediaHosts membership. The
    // typed-SocketException branch above matches any host, so only a
    // stringified failure — the shape a codec-wrapped load arrives in —
    // depends on the set. Dropping the hosts makes these errors fatal again.
    for (final host in const ['v.cdn.vine.co', 'cdn.vine.co']) {
      test('keeps stringified socket failures from $host recoverable', () {
        final details = FlutterErrorDetails(
          exception: Exception("SocketException: Failed host lookup: '$host'"),
          library: 'dart:_http',
        );

        expect(classifyRecoverableFlutterError(details), (
          reason: 'Recoverable media load failure',
          report: true,
        ));
      });
    }

    test('classifies wrapped relay host lookup failures as unreported', () {
      final details = FlutterErrorDetails(
        exception: WebSocketChannelException.from(
          const SocketException("Failed host lookup: 'relay.divine.video'"),
        ),
        library: 'dart:async',
      );

      expect(classifyRecoverableFlutterError(details), (
        reason: 'Expected network failure',
        report: false,
      ));
    });

    test('still reports non-DNS Divine media socket failures', () {
      final details = FlutterErrorDetails(
        exception: Exception(
          'SocketException: OS Error: Bad file descriptor, '
          'address = media.divine.video',
        ),
        library: 'dart:_http',
      );

      expect(classifyRecoverableFlutterError(details), (
        reason: 'Recoverable media load failure',
        report: true,
      ));
    });

    test('classifies invalid image data failures as recoverable', () {
      const details = FlutterErrorDetails(
        exception: FormatException('Invalid image data.'),
        library: 'dart:ui',
      );

      expect(classifyRecoverableFlutterError(details), (
        reason: 'Recoverable media load failure',
        report: true,
      ));
    });

    test('classifies interrupted Divine media downloads as recoverable', () {
      const details = FlutterErrorDetails(
        exception: HttpException(
          'Connection closed while receiving data, '
          'uri = https://media.divine.video/hash',
        ),
        library: 'dart:_http',
      );

      expect(classifyRecoverableFlutterError(details), (
        reason: 'Recoverable media load failure',
        report: false,
      ));
    });

    // The abort message dart:io uses when the OS kills the socket mid-download
    // rather than the parser running dry. It reached Crashlytics as a FATAL
    // (issue 198b20e41b65c26f4d7dcbd83993a011, 1.0.20) because the branch
    // matched only the parser's wording, even though the failure is the same
    // recoverable thumbnail load.
    test('classifies aborted Divine media downloads as recoverable', () {
      final details = FlutterErrorDetails(
        exception: HttpException(
          'Software caused connection abort',
          uri: Uri.parse('https://media.divine.video/hash'),
        ),
        library: 'dart:_http',
      );

      expect(classifyRecoverableFlutterError(details), (
        reason: 'Recoverable media load failure',
        report: false,
      ));
    });

    // The type arm must not swallow an HttpException from anywhere else — a
    // failing app API call is not a placeholder-recoverable thumbnail.
    test('keeps aborted downloads from other hosts fatal', () {
      final details = FlutterErrorDetails(
        exception: HttpException(
          'Software caused connection abort',
          uri: Uri.parse('https://api.example.com/thing'),
        ),
        library: 'dart:_http',
      );

      expect(classifyRecoverableFlutterError(details), isNull);
    });

    test('keeps aborted downloads from Divine non-media hosts fatal', () {
      final details = FlutterErrorDetails(
        exception: HttpException(
          'Software caused connection abort',
          uri: Uri.parse('https://api.divine.video/thing'),
        ),
        library: 'dart:_http',
      );

      expect(classifyRecoverableFlutterError(details), isNull);
    });

    // Pins the string arm, which the type arm cannot stand in for: a
    // codec-wrapped load arrives already stringified as a plain Exception, so
    // `is HttpException` is false. Every other interrupted-download test now
    // passes through the type arm, and without this one the string arm can be
    // deleted with the suite still green.
    test('keeps stringified interrupted media downloads recoverable', () {
      final details = FlutterErrorDetails(
        exception: Exception(
          'HttpException: Connection closed while receiving data, '
          'uri = https://media.divine.video/hash',
        ),
        library: 'dart:_http',
      );

      expect(classifyRecoverableFlutterError(details), (
        reason: 'Recoverable media load failure',
        report: false,
      ));
    });

    // flutter_cache_manager reports every non-2xx as HttpExceptionWithStatus,
    // a dart:io HttpException subclass whose 'Invalid statusCode' wording no
    // string arm matches — so a dead CachedNetworkImage thumbnail was fatal
    // before the type arm and is recoverable after it. Pins the arm as a
    // subtype check rather than an exact-type one.
    test('classifies cached-image non-2xx failures as recoverable', () {
      final details = FlutterErrorDetails(
        exception: HttpExceptionWithStatus(
          404,
          'Invalid statusCode: 404',
          uri: Uri.parse('https://media.divine.video/hash'),
        ),
        library: 'dart:_http',
      );

      expect(classifyRecoverableFlutterError(details), (
        reason: 'Recoverable media load failure',
        report: false,
      ));
    });

    test('classifies dart:_http missing-host URI failures as recoverable', () {
      final details = FlutterErrorDetails(
        exception: ArgumentError('No host specified in URI https:///thumb.jpg'),
        library: 'dart:_http',
      );

      expect(classifyRecoverableFlutterError(details), (
        reason: 'Recoverable media load failure',
        report: true,
      ));
    });

    test('classifies MediaCacheImageProvider download-without-file failures as '
        'recoverable and unreported regardless of host', () {
      // Dead legacy Vine avatars are commonly served through
      // web.archive.org, which is not in the recoverable-media host set —
      // the exception type alone must classify it, so the broken avatar
      // falls back to a placeholder instead of a fatal crash (#5782 follow
      // up: the download-without-file branch was still reported as fatal).
      //
      // report is false because a dead URL is a plain IO failure with no
      // actionable signal beyond the URL that the negative cache already acts
      // on (#7298).
      const details = FlutterErrorDetails(
        exception: MediaCacheImageLoadException(
          'https://web.archive.org/web/20150907190604/'
          'http://v.cdn.vine.co/r/avatars/broken.jpg',
        ),
        library: 'package:media_cache/src/media_cache_image_provider.dart',
      );

      expect(classifyRecoverableFlutterError(details), (
        reason: 'Recoverable media load failure',
        report: false,
      ));
    });

    test('classifies hero flight layout failures as recoverable', () {
      // A destination route added to the go_router pages stack under an opaque
      // cover is never laid out (_RenderTheatre lays out on-stage children
      // only), so measuring its hero throws. The scheduler catches it and
      // skips the flight, but Crashlytics filed
      // 7743fddabc5ad680dcedf319b70f4f60 as fatal. Frames are verbatim from
      // that report — flutter/flutter#136356 is the unfixed upstream bug.
      final details = FlutterErrorDetails(
        exception: StateError(
          'RenderBox was not laid out: RenderRepaintBoundary#5a1b2',
        ),
        library: 'scheduler library',
        context: ErrorDescription('during a scheduler callback'),
        stack: StackTrace.fromString(
          '#0      RenderBox.size '
          '(package:flutter/src/rendering/box.dart:2304:7)\n'
          '#1      _HeroFlightManifest._boundingBoxFor '
          '(package:flutter/src/widgets/heroes.dart:507:26)\n'
          '#2      _HeroFlightManifest.toHeroLocation '
          '(package:flutter/src/widgets/heroes.dart:520:41)\n'
          '#3      _HeroFlightManifest.isValid '
          '(package:flutter/src/widgets/heroes.dart:529:29)\n'
          '#4      HeroController._startHeroTransition '
          '(package:flutter/src/widgets/heroes.dart:1049:35)\n'
          '#5      HeroController._maybeStartHeroTransition.<anonymous '
          'closure> (package:flutter/src/widgets/heroes.dart:972:9)\n'
          '#6      SchedulerBinding._invokeFrameCallback '
          '(package:flutter/src/scheduler/binding.dart:1430:15)\n',
        ),
      );

      expect(classifyRecoverableFlutterError(details), (
        reason: 'Recoverable hero flight layout failure',
        report: true,
      ));
    });

    test('classifies hero placeholder measurement failures as recoverable', () {
      // Same root cause, second of the three throw sites: _HeroState
      // .startFlight reads box.size for the flight placeholder rather than
      // _boundingBoxFor.
      final details = FlutterErrorDetails(
        exception: StateError(
          'RenderBox was not laid out: RenderSemanticsAnnotations#3f8c9',
        ),
        library: 'scheduler library',
        context: ErrorDescription('during a scheduler callback'),
        stack: StackTrace.fromString(
          '#0      RenderBox.size '
          '(package:flutter/src/rendering/box.dart:2304:7)\n'
          '#1      _HeroState.startFlight '
          '(package:flutter/src/widgets/heroes.dart:387:26)\n'
          '#2      _HeroFlight.start '
          '(package:flutter/src/widgets/heroes.dart:734:22)\n'
          '#3      HeroController._startHeroTransition '
          '(package:flutter/src/widgets/heroes.dart:1054:56)\n'
          '#4      SchedulerBinding._invokeFrameCallback '
          '(package:flutter/src/scheduler/binding.dart:1430:15)\n',
        ),
      );

      expect(classifyRecoverableFlutterError(details), (
        reason: 'Recoverable hero flight layout failure',
        report: true,
      ));
    });

    test(
      'does not classify non-hero RenderBox layout failures as recoverable',
      () {
        // Exception, library and context are identical to the hero flight
        // failure: any post-frame callback that measures a widget which is
        // mounted but unlaid out produces this. ScrollToHideMixin
        // (scroll_to_hide_mixin.dart:38-45) guards on `box != null`, which does
        // not imply hasSize. Only the stack tells the two apart, and this one is
        // a real app bug that must stay fatal.
        final details = FlutterErrorDetails(
          exception: StateError(
            'RenderBox was not laid out: RenderPadding#7c3d1',
          ),
          library: 'scheduler library',
          context: ErrorDescription('during a scheduler callback'),
          stack: StackTrace.fromString(
            '#0      RenderBox.size '
            '(package:flutter/src/rendering/box.dart:2304:7)\n'
            '#1      ScrollToHideMixin.measureHeaderHeight.<anonymous closure> '
            '(package:openvine/widgets/scroll_to_hide_mixin.dart:42:26)\n'
            '#2      SchedulerBinding._invokeFrameCallback '
            '(package:flutter/src/scheduler/binding.dart:1430:15)\n',
          ),
        );

        expect(classifyRecoverableFlutterError(details), isNull);
      },
    );

    test('does not classify debug hero layout assertions as recoverable', () {
      // heroes.dart:504 asserts `box.hasSize && box.size.isFinite`, which
      // short-circuits before RenderBox.size is read, so the debug message
      // never mentions the size. Debug and test runs stay loud; only the
      // release StateError is downgraded.
      final details = FlutterErrorDetails(
        exception: AssertionError(
          "'package:flutter/src/widgets/heroes.dart': Failed assertion: "
          "line 504 pos 12: 'box.hasSize && box.size.isFinite': is not true.",
        ),
        library: 'scheduler library',
        stack: StackTrace.fromString(
          '#0      _HeroFlightManifest._boundingBoxFor '
          '(package:flutter/src/widgets/heroes.dart:504:12)\n'
          '#1      HeroController._startHeroTransition '
          '(package:flutter/src/widgets/heroes.dart:1049:35)\n',
        ),
      );

      expect(classifyRecoverableFlutterError(details), isNull);
    });

    test('does not classify unrelated gesture errors as recoverable', () {
      final details = FlutterErrorDetails(
        exception: Exception('GoError: There is nothing to pop.'),
        library: 'package:go_router/src/delegate.dart',
      );

      expect(classifyRecoverableFlutterError(details), isNull);
    });

    test(
      'does not classify hardware keyboard assertion errors as recoverable',
      () {
        // Keyboard framework errors are not special-cased anywhere: they must
        // reach crash reporting through the normal chain (#4115).
        final details = FlutterErrorDetails(
          exception: AssertionError(
            'A KeyDownEvent is dispatched, but the state shows that the '
            'physical key is already pressed. HardwareKeyboard is in an '
            'inconsistent state.',
          ),
          library: 'services library',
        );

        expect(classifyRecoverableFlutterError(details), isNull);
      },
    );

    // Crashlytics issue 198b20e4 (1.0.20+727, Android) filed this as a FATAL
    // even though nothing crashed: Flutter catches the decode failure in
    // MultiFrameImageStreamCompleter._decodeNextFrameAndSchedule, reports it
    // with silent: true, and returns.
    test('classifies image decode allocation failures as recoverable', () {
      final details = FlutterErrorDetails(
        exception: Exception(
          'Could not allocate scaled bitmap for image decompression.',
        ),
        context: ErrorDescription('resolving an image frame'),
        library: 'image resource service',
      );

      expect(classifyRecoverableFlutterError(details), (
        reason: 'Recoverable image decode allocation failure',
        report: true,
      ));
    });

    // The engine hands dart:ui the decoder's own string, which
    // Codec.getNextFrame rethrows verbatim as Exception(decodeError). Matching
    // the allocation-failure family rather than the single observed wording is
    // deliberate, so a differently-worded engine message does not land back on
    // the fatal path.
    for (final message in const [
      'Could not allocate scaled bitmap for image decompression.',
      'Failed to allocate memory for the decoded frame.',
      'Unable to allocate bitmap pixels.',
    ]) {
      test('treats "$message" as a recoverable allocation failure', () {
        final details = FlutterErrorDetails(
          exception: Exception(message),
          context: ErrorDescription('resolving an image codec'),
          library: 'image resource service',
        );

        expect(classifyRecoverableFlutterError(details), (
          reason: 'Recoverable image decode allocation failure',
          report: true,
        ));
      });
    }

    test('keeps allocation failures outside the image pipeline fatal', () {
      // Same wording, different subsystem. An allocation failure is only
      // recoverable because the image pipeline degrades to a placeholder;
      // nothing here promises that for anyone else.
      final details = FlutterErrorDetails(
        exception: Exception('Could not allocate a buffer.'),
        library: 'services library',
      );

      expect(classifyRecoverableFlutterError(details), isNull);
    });

    test('keeps non-allocation image resource failures fatal', () {
      // The branch must gate on the allocation wording, not on the library
      // alone, or it would swallow every unclassified image-pipeline error.
      final details = FlutterErrorDetails(
        exception: Exception('Something else went wrong entirely.'),
        context: ErrorDescription('resolving an image frame'),
        library: 'image resource service',
      );

      expect(classifyRecoverableFlutterError(details), isNull);
    });
  });
}
