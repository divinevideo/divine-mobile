// Run explicitly on a desktop host with the native libmpv runtime installed.
import 'dart:io';

import 'package:divine_camera/src/desktop/desktop_video_file_inspector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

import '../../helpers/fixtures.dart';

void main() {
  setUpAll(() {
    final library = Platform.environment['DIVINE_NATIVE_LIBMPV'];
    if (library != null) MediaKit.ensureInitialized(libmpv: library);
  });
  group('native capture file inspection', () {
    for (final hasAudio in [false, true]) {
      test('reads encoded portrait dimensions and audio=$hasAudio', () async {
        final inspector = DesktopVideoFileInspector();
        final metadata = await inspector.inspect(
          (await fixtureFile(
            'desktop_${hasAudio ? 'audio' : 'silent'}_portrait.mp4',
          )).path,
        );

        // The native demuxer can include one 1024-sample AAC priming packet.
        expect(
          metadata.duration.inMicroseconds,
          inInclusiveRange(1000000, 1022000),
        );
        expect(metadata.width, 128);
        expect(metadata.height, 240);
        expect(metadata.hasAudio, hasAudio);
      });
    }
  });
}
