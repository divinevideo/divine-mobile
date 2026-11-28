import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final lines = StreamIterator(
    stdin.transform(utf8.decoder).transform(const LineSplitter()),
  );
  if (!await lines.moveNext()) exit(2);
  final request = jsonDecode(lines.current) as Map<String, dynamic>;
  final args = request['arguments'] as Map<String, dynamic>;
  var method = request['method'];
  if (args['id'] == 'fixture-block') method = 'block';
  if (args['id'] == 'fixture-encoder') method = 'native-error';
  if (args['id'] == 'fixture-unsupported') {
    method = 'native-error';
    args['fixtureError'] = 'unsupported';
  }
  void send(String event, Object? value) {
    stdout.writeln(jsonEncode({'protocol': 1, 'event': event, 'value': value}));
  }

  switch (method) {
    case 'native-error':
      send('error', args['fixtureError'] ?? 'encoder');
    case 'invalid-progress':
      send('progress', 2);
    case 'unknown-event':
      send('unrecognized', null);
    case 'invalid-utf8':
      stdout.add([255, 10]);
    case 'oversized':
      stdout.writeln('x' * 65537);
    case 'unterminated':
      stdout.write('incomplete');
      await stdout.flush();
      exit(0);
    case 'bad-version':
      stdout.writeln('{"protocol":2,"event":"result","value":null}');
    case 'second-result':
      send('result', null);
      send('result', null);
    default:
      break;
  }
  if ([
    'native-error',
    'invalid-progress',
    'unknown-event',
    'invalid-utf8',
    'oversized',
    'bad-version',
    'second-result',
  ].contains(method)) {
    while (await lines.moveNext()) {}
    await stdout.flush();
    return;
  }
  if (method == 'getMetadata' || method == 'hasAudioTrack') {
    send(
      'result',
      args.containsKey('fixtureResult')
          ? args['fixtureResult']
          : method == 'hasAudioTrack'
          ? true
          : {
              'width': 128,
              'height': 240,
              'rotation': 0,
              'duration': 1000,
              'fileSize': 12200,
              'frameRate': 20.0,
            },
    );
    while (await lines.moveNext()) {}
    await stdout.flush();
    return;
  }
  if (method == 'getThumbnails') {
    final files = <Map<String, String>>[];
    for (var i = 0; i < 2; i++) {
      final file = File('${request['workingDirectory']}/thumbnail-$i.bin');
      await file.writeAsBytes([i + 1, i + 2, i + 3]);
      files.add({'path': file.path});
    }
    send(
      'result',
      args.containsKey('fixtureResult') ? args['fixtureResult'] : files,
    );
    while (await lines.moveNext()) {}
    await stdout.flush();
    return;
  }
  if (method == 'startThumbnailStream' || method == 'startFrameStream') {
    final file = File('${request['workingDirectory']}/frame.bin');
    for (var sequence = 1; sequence <= 2; sequence++) {
      await file.writeAsBytes([sequence, sequence + 1, sequence + 2]);
      stdout.writeln(
        jsonEncode({
          'protocol': 1,
          'event': 'data',
          'sequence': sequence,
          'value': {
            'path': file.path,
            'indices': args['id'] == 'fixture-bad-indices'
                ? <int>[]
                : [sequence - 1],
            'width': args['id'] == 'fixture-bad-luma' ? 0 : 3,
            'height': 1,
            'ptsUs': sequence * 100000,
            'progress': args['id'] == 'fixture-bad-progress' ? 2 : sequence / 2,
          },
        }),
      );
      await stdout.flush();
      if (!await lines.moveNext()) exit(8);
      final ack = jsonDecode(lines.current) as Map<String, dynamic>;
      if (ack['protocol'] != 1 || ack['ack'] != sequence) exit(9);
      if (args['id'] == 'fixture-stream-block') {
        while (await lines.moveNext()) {}
        return;
      }
    }
    send('result', <Object?>[]);
    while (await lines.moveNext()) {}
    await stdout.flush();
    return;
  }
  if (method == 'events') {
    final file = File('${request['workingDirectory']}/frame.bin');
    for (var sequence = 1; sequence <= 2; sequence++) {
      await file.writeAsBytes([sequence, sequence + 1, sequence + 2]);
      stdout.writeln(
        jsonEncode({
          'protocol': 1,
          'event': 'data',
          'sequence': sequence,
          'value': {'path': file.path},
        }),
      );
      await stdout.flush();
      if (!await lines.moveNext()) exit(8);
      final ack = jsonDecode(lines.current) as Map<String, dynamic>;
      if (ack['protocol'] != 1 || ack['ack'] != sequence) exit(9);
    }
    send('result', 2);
    while (await lines.moveNext()) {}
    await stdout.flush();
    return;
  }
  if (method == 'exit') {
    stderr.writeln('synthetic-private-payload');
    exit(7);
  }
  if (method == 'malformed') {
    stdout.writeln('synthetic-private-payload');
  } else {
    send('progress', 0.25);
    if (method != 'block') {
      final file = File('${request['workingDirectory']}/output.bin');
      await file.writeAsBytes(
        args.containsKey('fixtureBytes')
            ? (args['fixtureBytes'] as List<dynamic>).cast<int>()
            : [7, 8, 9],
      );
      send(
        'result',
        args.containsKey('fixtureResult')
            ? args['fixtureResult']
            : {
                'path': file.path,
                'echo': args['text'],
                'registry': Platform.environment['GST_REGISTRY_1_0'],
                'registryFork': Platform.environment['GST_REGISTRY_FORK'],
              },
      );
      if (method == 'result-then-exit') {
        await stdout.flush();
        exit(9);
      }
    }
  }
  while (await lines.moveNext()) {}
  await stdout.flush();
}
