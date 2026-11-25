"""Check the fixture's HTTP contract before using it as a player oracle."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from native_playback_harness import MAIN, flutter_command


class HttpFixtureTest(unittest.TestCase):
    def test_ranges_head_and_errors_complete_with_correct_bytes(self):
        flutter_command()  # Fail if this is not the repository's pinned SDK.
        dart = shutil.which('dart')
        self.assertIsNotNone(dart)
        respond = MAIN[MAIN.index('Future<int> respond('):MAIN.index('Future<void> main()')]
        program = r"""
import 'dart:async';
import 'dart:io';
RESPOND
Future<void> main() async {
  final data = List.generate(128, (index) => index);
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final handlers = <Future<void>>[];
  var sent = 0;
  final subscription = server.listen((request) {
    handlers.add(respond(request, data).then((bytes) { sent += bytes; }));
  });
  final client = HttpClient();
  try {
    for (final scenario in [
      ('GET', 'bytes=0-31', 206, 0, 32),
      ('HEAD', 'bytes=0-31', 206, 0, 0),
      ('GET', 'bytes=-16', 206, 112, 16),
      ('GET', 'bytes=127-999', 206, 127, 1),
      ('GET', 'bytes=999-', 416, 0, 0),
      ('GET', 'bytes=invalid', 416, 0, 0),
      ('POST', 'bytes=0-31', 405, 0, 0),
    ]) {
      final request = await client.openUrl(scenario.$1,
          Uri.parse('http://127.0.0.1:${server.port}/synthetic.mp4'));
      request.headers.set(HttpHeaders.rangeHeader, scenario.$2);
      final response = await request.close().timeout(const Duration(seconds: 5));
      final body = await response.expand((chunk) => chunk).toList()
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != scenario.$3 || body.length != scenario.$5) {
        throw StateError('HTTP fixture returned ${response.statusCode}/${body.length} '
            'instead of ${scenario.$3}/${scenario.$5}');
      }
      if (body.indexed.any((entry) => entry.$2 != data[scenario.$4 + entry.$1])) {
        throw StateError('HTTP fixture returned the wrong byte range');
      }
    }
  } finally {
    client.close(force: true);
    await server.close(force: true);
    await subscription.cancel();
    await Future.wait(handlers);
  }
  if (sent != 49) throw StateError('Unjoined or incorrect response byte count');
  stdout.writeln('HTTP_FIXTURE_PASS');
}
""".replace('RESPOND', respond)
        with tempfile.TemporaryDirectory(prefix='divine-http-fixture-') as temporary:
            source = Path(temporary) / 'server.dart'
            source.write_text(program, encoding='utf-8')
            result = subprocess.run([dart, str(source)], cwd=temporary,
                                    capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('HTTP_FIXTURE_PASS', result.stdout)


if __name__ == '__main__':
    unittest.main()
