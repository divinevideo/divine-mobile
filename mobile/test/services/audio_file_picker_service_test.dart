import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/audio_picker_extensions.dart';
import 'package:openvine/services/audio_file_picker_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(AudioFilePickerService, () {
    const channel = MethodChannel('divine/audio_file_picker');
    late List<MethodCall> calls;

    void stubChannel(String? reply) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return reply;
          });
    }

    setUp(() => calls = []);

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    group('pickAudioFile on Android', () {
      setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);

      test('opens the native picker and returns its cached copy', () async {
        stubChannel('/cache/audio_picks/Song.mp3');

        final file = await const AudioFilePickerService(
          fileOpener: _failingOpener,
        ).pickAudioFile(typeGroupLabel: 'Audio');

        expect(calls, hasLength(1));
        expect(calls.single.method, equals('pickAudioFile'));
        expect(
          calls.single.arguments,
          equals({
            'mimeTypes': ['audio/*'],
            'extensions': audioPickerExtensions,
            'initialUri': androidAudioPickerInitialUri,
          }),
        );
        expect(file?.path, equals('/cache/audio_picks/Song.mp3'));
        // Callers read the type and title from the name.
        expect(file?.name, equals('Song.mp3'));
      });

      test('returns null when the user cancels', () async {
        stubChannel(null);

        final file = await const AudioFilePickerService(
          fileOpener: _failingOpener,
        ).pickAudioFile(typeGroupLabel: 'Audio');

        expect(calls, hasLength(1));
        expect(file, isNull);
      });
    });

    group('pickAudioFile off Android', () {
      test('uses file_selector and leaves the native channel alone', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        stubChannel('/never/used.mp3');
        List<XTypeGroup>? requestedGroups;

        final file =
            await AudioFilePickerService(
              fileOpener: ({acceptedTypeGroups = const []}) async {
                requestedGroups = acceptedTypeGroups;
                return XFile('/tmp/Song.m4a');
              },
            ).pickAudioFile(
              typeGroupLabel: 'Audio',
            );

        expect(calls, isEmpty);
        expect(file?.path, equals('/tmp/Song.m4a'));
        expect(requestedGroups?.single.label, equals('Audio'));
        expect(
          requestedGroups?.single.uniformTypeIdentifiers,
          equals(['public.audio']),
        );
      });
    });
  });
}

Future<XFile?> _failingOpener({
  List<XTypeGroup> acceptedTypeGroups = const [],
}) => throw StateError('file_selector must not be used on Android');
