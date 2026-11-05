// ABOUTME: Imports freely licensed sounds (verified CC0 packs, incompetech's CC BY
// ABOUTME: music) as Kind 1063 events: catalog, prepare, events, upload, publish.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/nip19/nip19.dart';

import 'sound_import/audio_pipeline.dart';
import 'sound_import/blossom_client.dart';
import 'sound_import/cc0_packs.dart';
import 'sound_import/import_state.dart';
import 'sound_import/incompetech.dart';
import 'sound_import/sound_candidate.dart';
import 'sound_import/sound_event_builder.dart';
import 'sound_import/sound_publisher.dart';

const _usage = '''
Imports freely licensed sounds into Divine's sound library.

  dart run tools/import_free_sounds.dart <command> --work-dir <dir> [options]

Commands, in order:
  catalog   List the candidates from the sources (no audio is downloaded).
  prepare   Download, trim, normalise and encode candidates. 20 per run
            unless --limit or --all says otherwise; resumes where it stopped.
  events    Write the unsigned Kind 1063 events to events.jsonl.
  upload    Upload the encoded files to Blossom. Needs the uploader's key in
            SOUND_IMPORT_UPLOAD_NSEC; --dry-run only asks the server.
  publish   Sign and publish the events the account has not published yet.
            Needs the publishing account's key in SOUND_IMPORT_PUBLISHER_NSEC;
            --dry-run only asks the relays.

See mobile/docs/DIVINE_SOUNDS.md for the event shape and the review steps.
''';

/// Identifies the importer to the servers it downloads from.
const _userAgent = 'DivineSoundImport/1.0 (+https://divine.video)';

Future<void> main(List<String> arguments) async {
  final parser = _parser();
  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (error) {
    stderr
      ..writeln(error.message)
      ..writeln(_usage)
      ..writeln(parser.usage);
    exitCode = 64;
    return;
  }
  final command = args.command;
  final workDir = args['work-dir'] as String?;
  if (args['help'] == true || command == null || workDir == null) {
    stdout
      ..writeln(_usage)
      ..writeln(parser.usage);
    if (command != null && workDir == null) exitCode = 64;
    return;
  }

  final work = Directory(workDir)..createSync(recursive: true);
  try {
    switch (command.name) {
      case 'catalog':
        await _catalog(work, command);
      case 'prepare':
        await _prepare(work, command);
      case 'events':
        _events(work, command);
      case 'upload':
        await _upload(work, command);
      case 'publish':
        await _publish(work, command);
    }
  } on _UsageError catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  }
}

ArgParser _parser() {
  final parser = ArgParser()
    ..addOption('work-dir', help: 'Holds the catalog, files and state.')
    ..addFlag('help', abbr: 'h', negatable: false);
  parser.addCommand('catalog')
    ..addOption(
      'source',
      allowed: ['all', 'cc0', 'incompetech'],
      defaultsTo: 'all',
    )
    ..addMultiOption(
      'pack',
      help: 'Only CC0 files whose path contains this text.',
      splitCommas: false,
    )
    ..addOption('limit', help: 'At most this many candidates per source.');
  parser.addCommand('prepare')
    ..addOption('limit', defaultsTo: '20')
    ..addFlag(
      'all',
      negatable: false,
      help: "Prepare every candidate. Only with the maintainer's go.",
    )
    ..addMultiOption(
      'only',
      help: 'Only these candidate ids.',
      splitCommas: false,
    )
    ..addOption('interval', defaultsTo: '2', help: 'Seconds between downloads.')
    ..addFlag('dry-run', negatable: false);
  parser.addCommand('events')
    ..addOption('blossom', help: 'The server the files are uploaded to.')
    ..addOption('pubkey', defaultsTo: '', help: 'Hex; the signer may set it.')
    ..addOption(
      'created-at',
      help:
          'Unix seconds for every event; defaults to now. A date in the '
          "past keeps the import out of the relays' newest pages.",
    );
  parser.addCommand('upload')
    ..addOption('blossom')
    ..addOption('interval', defaultsTo: '1')
    ..addFlag('dry-run', negatable: false)
    ..addFlag(
      'confirm-production',
      negatable: false,
      help: "Required to upload to Divine's own media servers.",
    );
  parser.addCommand('publish')
    ..addMultiOption('relay', splitCommas: false)
    ..addOption(
      'expect-pubkey',
      help: 'Hex pubkey of the publishing account; the key must match.',
    )
    ..addOption('interval', defaultsTo: '1')
    ..addFlag('dry-run', negatable: false);
  return parser;
}

class _UsageError implements Exception {
  const _UsageError(this.message);

  final String message;
}

File _catalogFile(Directory work) => File('${work.path}/catalog.json');
File _eventsFile(Directory work) => File('${work.path}/events.jsonl');
ImportState _state(Directory work) =>
    ImportState.load(File('${work.path}/state.json'));

List<SoundCandidate> _loadCatalog(Directory work) {
  final file = _catalogFile(work);
  if (!file.existsSync()) {
    throw const _UsageError('No catalog yet: run the catalog command first.');
  }
  return [
    for (final json in jsonDecode(file.readAsStringSync()) as List<dynamic>)
      SoundCandidate.fromJson(json as Map<String, dynamic>),
  ];
}

Future<void> _catalog(Directory work, ArgResults args) async {
  final source = args['source'] as String;
  final limit = _intOption(args, 'limit');
  final packs = args['pack'] as List<String>;
  final client = http.Client();
  final candidates = <SoundCandidate>[];
  try {
    if (source == 'all' || source == 'cc0') {
      final commit = await _getJson(
        client,
        'https://api.github.com/repos/$cc0Repository/commits/main',
      );
      final sha = (commit! as Map<String, dynamic>)['sha'] as String;
      final tree = await _getJson(
        client,
        'https://api.github.com/repos/$cc0Repository/git/trees/$sha'
        '?recursive=1',
      );
      final files = [
        for (final entry
            in (tree! as Map<String, dynamic>)['tree'] as List<dynamic>)
          if (entry is Map<String, dynamic> && entry['type'] == 'blob')
            RepositoryFile(
              path: entry['path'] as String,
              blobSha: entry['sha'] as String,
              size: entry['size'] as int? ?? 0,
            ),
      ];
      final cc0 = cc0Candidates(files, commit: sha)
          .where(
            (candidate) =>
                packs.isEmpty ||
                packs.any((pack) => candidate.id.contains(pack)),
          )
          .toList();
      candidates.addAll(limit == null ? cc0 : cc0.take(limit));
      stdout.writeln('CC0: ${cc0.length} candidates at commit $sha');
    }
    if (source == 'all' || source == 'incompetech') {
      final pieces = await _getJson(client, incompetechPiecesUrl);
      final music = incompetechCandidates(pieces! as List<dynamic>);
      candidates.addAll(limit == null ? music : music.take(limit));
      stdout.writeln('incompetech: ${music.length} candidates');
    }
  } finally {
    client.close();
  }

  _catalogFile(work).writeAsStringSync(
    const JsonEncoder.withIndent('  ')
        .convert([for (final candidate in candidates) candidate.toJson()]),
  );
  final byKind = <String, int>{};
  for (final candidate in candidates) {
    byKind.update(candidate.kind.name, (count) => count + 1, ifAbsent: () => 1);
  }
  stdout.writeln(
    'Wrote ${candidates.length} candidates to ${_catalogFile(work).path} '
    '$byKind',
  );
}

Future<void> _prepare(Directory work, ArgResults args) async {
  final catalog = _loadCatalog(work);
  final state = _state(work);
  final only = (args['only'] as List<String>).toSet();
  final limit = args['all'] == true ? null : _intOption(args, 'limit');
  final interval = Duration(
    milliseconds: (double.parse(args['interval'] as String) * 1000).round(),
  );
  final pending = [
    for (final candidate in catalog)
      if ((only.isEmpty || only.contains(candidate.id)) &&
          _needsPreparing(state.records[candidate.id]))
        candidate,
  ];
  final batch = limit == null ? pending : pending.take(limit).toList();

  if (args['dry-run'] == true) {
    final bytes = batch.fold<int>(
      0,
      (sum, candidate) => sum + (candidate.expectedBytes ?? 0),
    );
    stdout.writeln(
      'Would prepare ${batch.length} of ${pending.length} pending candidates'
      '${bytes > 0 ? ', at least ${_megabytes(bytes)} to download' : ''}.',
    );
    for (final candidate in batch.take(50)) {
      stdout.writeln('  ${candidate.id}  "${candidate.title}"');
    }
    return;
  }

  final sources = Directory('${work.path}/src')..createSync(recursive: true);
  final outputs = Directory('${work.path}/out')..createSync(recursive: true);
  final pipeline = AudioPipeline();
  final client = http.Client();
  var lastDownload = DateTime.fromMillisecondsSinceEpoch(0);
  try {
    for (final (index, candidate) in batch.indexed) {
      stdout.write('[${index + 1}/${batch.length}] ${candidate.id} ... ');
      final sourceFile = File(
        '${sources.path}/${_hashText(candidate.id)}'
        '${_extensionOf(candidate.downloadUrl)}',
      );
      try {
        if (!sourceFile.existsSync()) {
          final wait = interval - DateTime.now().difference(lastDownload);
          if (wait > Duration.zero) await Future<void>.delayed(wait);
          lastDownload = DateTime.now();
          await _download(client, candidate.downloadUrl, sourceFile);
        }
        final sourceSha = await _sha256Of(sourceFile);
        final original = state.preparedFromSource(sourceSha);
        if (original != null && original != candidate.id) {
          state.records[candidate.id] = ImportRecord(
            status: ImportStatus.duplicate,
            sourceSha256: sourceSha,
            duplicateOf: original,
          );
          state.save();
          stdout.writeln('duplicate of $original');
          continue;
        }

        final encoded = File('${outputs.path}/encoding.m4a');
        final outcome = await pipeline.prepare(
          input: sourceFile,
          output: encoded,
          kind: candidate.kind,
          title: candidate.title,
          artist: candidate.creatorName,
          comment: soundCreditContent(
            candidate,
            changes: const [],
          ).replaceAll('\n', ' / '),
        );
        switch (outcome) {
          case RejectedAudio(:final reason):
            state.records[candidate.id] = ImportRecord(
              status: ImportStatus.rejected,
              sourceSha256: sourceSha,
              reason: reason,
            );
            stdout.writeln('rejected: $reason');
          case PreparedAudio():
            final outputSha = await _sha256Of(encoded);
            final output = File('${outputs.path}/$outputSha.m4a');
            encoded.renameSync(output.path);
            state.records[candidate.id] = ImportRecord(
              status: ImportStatus.prepared,
              sourceSha256: sourceSha,
              outputSha256: outputSha,
              outputBytes: output.lengthSync(),
              durationSeconds: outcome.durationSeconds,
              gainDb: outcome.gainDb,
              changes: outcome.changes,
            );
            stdout.writeln(
              '${outcome.durationSeconds.toStringAsFixed(2)} s, '
              '${outcome.gainDb.toStringAsFixed(1)} dB',
            );
        }
      } on Exception catch (error) {
        state.records[candidate.id] = ImportRecord(
          status: ImportStatus.failed,
          reason: '$error',
        );
        stdout.writeln('failed: $error');
      }
      state.save();
    }
  } finally {
    client.close();
  }
  _printSummary(state);
}

bool _needsPreparing(ImportRecord? record) =>
    record == null || record.status == ImportStatus.failed;

void _events(Directory work, ArgResults args) {
  final blossom = args['blossom'] as String?;
  if (blossom == null) throw const _UsageError('--blossom is required.');
  final pubkey = args['pubkey'] as String;
  if (pubkey.isNotEmpty && !RegExp(r'^[0-9a-f]{64}$').hasMatch(pubkey)) {
    throw const _UsageError('--pubkey must be 64 lowercase hex characters.');
  }
  final state = _state(work);
  final createdAt =
      _intOption(args, 'created-at') ??
      DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final written = <String>{};
  final lines = <String>[];
  for (final candidate in _loadCatalog(work)) {
    final record = state.records[candidate.id];
    if (record?.status != ImportStatus.prepared) continue;
    if (!written.add(record!.outputSha256!)) continue;
    lines.add(
      jsonEncode(
        buildUnsignedSoundEvent(
          candidate: candidate,
          record: record,
          blossomBase: blossom,
          createdAt: createdAt,
          pubkey: pubkey,
        ),
      ),
    );
  }
  _eventsFile(work).writeAsStringSync(lines.map((line) => '$line\n').join());
  stdout.writeln(
    'Wrote ${lines.length} unsigned events to ${_eventsFile(work).path}',
  );
}

Future<void> _upload(Directory work, ArgResults args) async {
  final server = args['blossom'] as String?;
  if (server == null) throw const _UsageError('--blossom is required.');
  final dryRun = args['dry-run'] == true;
  if (!dryRun &&
      productionBlossomHosts.contains(Uri.parse(server).host) &&
      args['confirm-production'] != true) {
    throw const _UsageError(
      "Uploading to Divine's media servers needs --confirm-production.",
    );
  }
  final key = dryRun ? null : _privateKeyFrom('SOUND_IMPORT_UPLOAD_NSEC');
  final interval = Duration(
    milliseconds: (double.parse(args['interval'] as String) * 1000).round(),
  );

  final state = _state(work);
  final blossom = BlossomClient(server: server);
  var present = 0;
  var uploaded = 0;
  var missing = 0;
  try {
    final seen = <String>{};
    for (final record in state.records.values) {
      final sha = record.outputSha256;
      if (record.status != ImportStatus.prepared || sha == null) continue;
      if (!seen.add(sha)) continue;
      if (record.uploadedTo.contains(blossom.server)) {
        present++;
        continue;
      }
      if (await blossom.has(sha)) {
        record.uploadedTo.add(blossom.server);
        state.save();
        present++;
        continue;
      }
      if (key == null) {
        missing++;
        continue;
      }
      await blossom.upload(
        File('${work.path}/out/$sha.m4a'),
        sha256: sha,
        mimeType: preparedMimeType,
        privateKeyHex: key,
      );
      record.uploadedTo.add(blossom.server);
      state.save();
      uploaded++;
      await Future<void>.delayed(interval);
    }
  } finally {
    blossom.close();
  }
  stdout.writeln(
    '${blossom.server}: $present already there, $uploaded uploaded'
    '${dryRun ? ', $missing would be uploaded' : ''}.',
  );
}

Future<void> _publish(Directory work, ArgResults args) async {
  final relays = args['relay'] as List<String>;
  final expected = args['expect-pubkey'] as String?;
  if (relays.isEmpty) throw const _UsageError('Name at least one --relay.');
  if (expected == null || !RegExp(r'^[0-9a-f]{64}$').hasMatch(expected)) {
    throw const _UsageError('--expect-pubkey must be 64 lowercase hex.');
  }
  final dryRun = args['dry-run'] == true;
  final key = dryRun ? null : _privateKeyFrom('SOUND_IMPORT_PUBLISHER_NSEC');
  if (key != null && getPublicKey(key) != expected) {
    throw const _UsageError(
      'SOUND_IMPORT_PUBLISHER_NSEC does not belong to --expect-pubkey.',
    );
  }

  final file = _eventsFile(work);
  if (!file.existsSync()) {
    throw const _UsageError('No events yet: run the events command first.');
  }
  final unsigned = [
    for (final line in file.readAsLinesSync())
      if (line.trim().isNotEmpty) jsonDecode(line) as Map<String, dynamic>,
  ];
  final state = _state(work);
  final uploaded = {
    for (final record in state.records.values)
      if (record.outputSha256 != null && record.uploadedTo.isNotEmpty)
        record.outputSha256!,
  };
  final interval = Duration(
    milliseconds: (double.parse(args['interval'] as String) * 1000).round(),
  );
  final hashes = [
    for (final event in unsigned)
      ...fileHashesOf(event['tags'] as List<dynamic>),
  ];

  final signedFile = File('${work.path}/signed.json');
  final signedBySha = signedFile.existsSync()
      ? (jsonDecode(signedFile.readAsStringSync()) as Map<String, dynamic>)
            .cast<String, Map<String, dynamic>>()
      : <String, Map<String, dynamic>>{};

  for (final url in relays) {
    final relay = await RelayConnection.open(url);
    try {
      final existing = await publishedHashes(
        relay,
        pubkey: expected,
        sha256s: hashes,
      );
      var published = 0;
      var skipped = 0;
      var notUploaded = 0;
      for (final event in unsigned) {
        final sha = fileHashesOf(event['tags'] as List<dynamic>).firstOrNull;
        if (sha == null || existing.contains(sha)) {
          skipped++;
          continue;
        }
        if (!uploaded.contains(sha)) {
          notUploaded++;
          continue;
        }
        if (key == null) {
          published++;
          continue;
        }
        // Signed once and kept, so every relay, and every later run, gets
        // the same event rather than a second copy with another id.
        final signed = signedBySha[sha] ??= signUnsigned(
          event,
          pubkey: expected,
          privateKeyHex: key,
        );
        signedFile.writeAsStringSync(jsonEncode(signedBySha));
        final refusal = await relay.publish(signed);
        if (refusal != null) {
          stderr.writeln('$url refused the event for $sha: $refusal');
          continue;
        }
        for (final record in state.records.values) {
          if (record.outputSha256 == sha) {
            record.publishedEventId = signed['id'] as String;
          }
        }
        state.save();
        published++;
        await Future<void>.delayed(interval);
      }
      stdout.writeln(
        '$url: ${dryRun ? 'would publish' : 'published'} $published, '
        '$skipped already there, $notUploaded not uploaded yet.',
      );
    } finally {
      await relay.close();
    }
  }
}

/// The hex private key in the environment variable [name].
String _privateKeyFrom(String name) {
  final raw = Platform.environment[name]?.trim() ?? '';
  if (raw.isEmpty) {
    throw _UsageError('Set $name to the key, or use --dry-run.');
  }
  return raw.startsWith('nsec1') ? Nip19.decode(raw) : raw;
}

Future<Object?> _getJson(http.Client client, String url) async {
  final response = await client.get(
    Uri.parse(url),
    headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
  );
  if (response.statusCode != 200) {
    throw HttpException('GET $url answered ${response.statusCode}');
  }
  return jsonDecode(utf8.decode(response.bodyBytes));
}

/// Downloads [url] to [file], retrying a busy server with growing pauses.
Future<void> _download(http.Client client, String url, File file) async {
  for (var attempt = 1; ; attempt++) {
    final response = await client.get(
      Uri.parse(url),
      headers: {'User-Agent': _userAgent},
    );
    if (response.statusCode == 200) {
      final partial = File('${file.path}.part')
        ..writeAsBytesSync(response.bodyBytes);
      partial.renameSync(file.path);
      return;
    }
    final retryable = response.statusCode == 429 || response.statusCode >= 500;
    if (!retryable || attempt == 4) {
      throw HttpException('GET $url answered ${response.statusCode}');
    }
    await Future<void>.delayed(Duration(seconds: 5 * attempt * attempt));
  }
}

Future<String> _sha256Of(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

String _hashText(String text) => sha256.convert(utf8.encode(text)).toString();

String _extensionOf(String url) {
  final path = Uri.parse(url).path;
  final name = path.substring(path.lastIndexOf('/') + 1);
  final dot = name.lastIndexOf('.');
  return dot == -1 ? '' : name.substring(dot).toLowerCase();
}

int? _intOption(ArgResults args, String name) {
  final value = args[name] as String?;
  if (value == null) return null;
  final parsed = int.tryParse(value);
  if (parsed == null || parsed < 0) {
    throw _UsageError('--$name must be a whole number.');
  }
  return parsed;
}

String _megabytes(int bytes) => '${(bytes / 1e6).toStringAsFixed(1)} MB';

void _printSummary(ImportState state) {
  final counts = <ImportStatus, int>{};
  for (final record in state.records.values) {
    counts.update(record.status, (count) => count + 1, ifAbsent: () => 1);
  }
  stdout.writeln({
    for (final MapEntry(:key, :value) in counts.entries) key.name: value,
  });
}
