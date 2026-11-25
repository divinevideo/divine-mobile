// ABOUTME: Tests the detector behind check_replaceable_base_reads.sh (#11317).
// ABOUTME: Pins which publish shapes count and what a base read clears.

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports, scripts are outside the application library.
import '../../scripts/lib/replaceable_publish_detector.dart';

/// A kind table in its own file, the way `EventKind` lives in `nostr_sdk`.
const _eventKindSource = '''
class EventKind {
  static const int contactList = 3;
}
''';

List<String> _keys(List<ReplaceablePublishViolation> violations) => [
  for (final violation in violations) '${violation.path}\t${violation.kind}',
];

void main() {
  group('findReplaceablePublishViolations', () {
    group('publish sites', () {
      test('flags a literal replaceable kind with its publish line', () {
        final violations = findReplaceablePublishViolations({
          'lib/mute_list.dart': '''
Future<void> publish(Signer signer) async {
  await signer.createAndSignEvent(kind: 10000, content: '', tags: const []);
}
''',
        });

        expect(_keys(violations), ['lib/mute_list.dart\t10000']);
        expect(violations.single.lines, [2]);
      });

      test('flags an Event construction by its second positional argument', () {
        final violations = findReplaceablePublishViolations({
          'lib/relay_list.dart': '''
Event build(String pubkey) => Event(pubkey, 10002, const [], '');
''',
        });

        expect(_keys(violations), ['lib/relay_list.dart\t10002']);
      });

      test('flags an Event built with new', () {
        final violations = findReplaceablePublishViolations({
          'lib/relay_list.dart': '''
Event build(String pubkey) => new Event(pubkey, 10002, const [], '');
''',
        });

        expect(_keys(violations), ['lib/relay_list.dart\t10002']);
      });

      test('treats a call through a signer typedef as a publish site', () {
        final violations = findReplaceablePublishViolations({
          'packages/badges/lib/badges.dart': '''
typedef BadgeEventSigner = Future<Event?> Function({
  required int kind,
  required String content,
  required List<List<String>> tags,
});

class Badges {
  Badges(this._signEvent);
  final BadgeEventSigner _signEvent;

  Future<void> save() => _signEvent(kind: 30009, content: '', tags: const []);
}
''',
        });

        expect(_keys(violations), ['packages/badges/lib/badges.dart\t30009']);
      });

      test('charges a sendContactList call to the calling file', () {
        final violations = findReplaceablePublishViolations({
          'packages/client/lib/client.dart': '''
class NostrClient {
  Future<Event?> sendContactList(ContactList contacts, String content) =>
      publishEvent(Event(publicKey, 3, contacts.toJson(), content));
}
''',
          'packages/follows/lib/follows.dart': '''
Future<void> broadcast(NostrClient client) =>
    client.sendContactList(ContactList(), '');
''',
        });

        expect(_keys(violations), ['packages/follows/lib/follows.dart\t3']);
      });

      test('ignores publish shapes inside comments and strings', () {
        final violations = findReplaceablePublishViolations({
          'lib/docs.dart': '''
// signer.createAndSignEvent(kind: 10000, content: '', tags: []);
/// Replaces the list: `Event(pubkey, 3, tags, '')`.
const example = "createAndSignEvent(kind: 30000) and Event(pubkey, 0, [], '')";
''',
        });

        expect(violations, isEmpty);
      });

      test('ignores the embedded-app bridge, whose kind is runtime data', () {
        final violations = findReplaceablePublishViolations({
          'packages/nostr_app_bridge_repository/lib/src/nostr_app_bridge_service.dart':
              '''
Future<void> handle(Signer signer) async {
  await signer.createAndSignEvent(kind: 10002, content: '', tags: const []);
}
''',
        });

        expect(violations, isEmpty);
      });
    });

    group('kind resolution', () {
      test('ignores a kind that is not replaceable', () {
        final violations = findReplaceablePublishViolations({
          'lib/like.dart': '''
Future<void> like(Signer signer) =>
    signer.createAndSignEvent(kind: 7, content: '+', tags: const []);
''',
        });

        expect(violations, isEmpty);
      });

      test('resolves a kind constant declared in another file', () {
        final violations = findReplaceablePublishViolations({
          'packages/nostr_sdk/lib/event_kind.dart': _eventKindSource,
          'lib/contacts.dart': '''
Future<void> publish(Signer signer) => signer.createAndSignEvent(
  kind: EventKind.contactList,
  content: '',
  tags: const [],
);
''',
        });

        expect(_keys(violations), ['lib/contacts.dart\t3']);
      });

      test('reports a kind it cannot resolve as ?', () {
        final violations = findReplaceablePublishViolations({
          'lib/resign.dart': '''
Future<void> resign(Signer signer, Event event) => signer.createAndSignEvent(
  kind: event.kind,
  content: event.content,
  tags: event.tags,
);
''',
        });

        expect(_keys(violations), ['lib/resign.dart\t?']);
      });

      test(
        'skips a kind forwarded from a parameter of the enclosing method',
        () {
          final violations = findReplaceablePublishViolations({
            'lib/signer_adapter.dart': '''
class SignerAdapter {
  SignerAdapter(this._auth);
  final AuthService _auth;

  Future<Event?> createAndSignEvent({required int kind}) =>
      _auth.createAndSignEvent(kind: kind, content: '', tags: const []);
}
''',
          });

          expect(violations, isEmpty);
        },
      );

      test('follows a forwarded kind to the same-file call that fixes it', () {
        final violations = findReplaceablePublishViolations({
          'packages/badges/lib/badges.dart': '''
class Badges {
  Badges(this._auth);
  final AuthService _auth;

  Future<Event?> _signAndPublish({required int kind}) =>
      _auth.createAndSignEvent(kind: kind, content: '', tags: const []);

  Future<void> saveProfileBadges() => _signAndPublish(kind: 10008);
}
''',
        });

        expect(_keys(violations), ['packages/badges/lib/badges.dart\t10008']);
        expect(violations.single.lines, [8]);
      });

      test('resolves a kind a known call returns', () {
        final violations = findReplaceablePublishViolations({
          'lib/video.dart': '''
Future<void> publish(Signer signer) => signer.createAndSignEvent(
  kind: NIP71VideoKinds.getPreferredAddressableKind(),
  content: '',
  tags: const [],
);
''',
        });

        expect(_keys(violations), ['lib/video.dart\t34236']);
      });

      test('resolves the kind of a payload a known codec call built', () {
        final violations = findReplaceablePublishViolations({
          'lib/people_list.dart': '''
Event build(String owner, UserList list) {
  final payload = Nip51PeopleListCodec.encode(list);
  return Event(owner, payload.kind, payload.tags, payload.content);
}
''',
        });

        expect(_keys(violations), ['lib/people_list.dart\t30000']);
      });

      test(
        'does not resolve a loop variable through a same-named constant',
        () {
          final violations = findReplaceablePublishViolations({
            'lib/lists.dart': '''
class Lists {
  static const int kind = 1;

  Future<void> republish(Signer signer, List<int> kinds) async {
    for (final kind in kinds) {
      await signer.createAndSignEvent(kind: kind, content: '', tags: const []);
    }
  }
}
''',
          });

          expect(_keys(violations), ['lib/lists.dart\t?']);
        },
      );

      test('reports a kind forwarded through a closure as ?', () {
        final violations = findReplaceablePublishViolations({
          'lib/lists.dart': '''
Future<void> republish(AuthService auth, List<int> kinds) => Future.wait(
  kinds.map(
    (kind) => auth.createAndSignEvent(kind: kind, content: '', tags: const []),
  ),
);
''',
        });

        expect(_keys(violations), ['lib/lists.dart\t?']);
      });

      test('reports a public forwarder as ? and by its default kind', () {
        final violations = findReplaceablePublishViolations({
          'lib/lists.dart': '''
Future<void> publishList(AuthService auth, {int kind = 10000}) =>
    auth.createAndSignEvent(kind: kind, content: '', tags: const []);
''',
        });

        expect(
          _keys(violations),
          unorderedEquals(['lib/lists.dart\t10000', 'lib/lists.dart\t?']),
        );
      });

      test('reports a local assigned after its declaration as ?', () {
        final violations = findReplaceablePublishViolations({
          'lib/lists.dart': '''
Future<void> publish(AuthService auth, {required bool mute}) {
  var kind = 1;
  if (mute) kind = 10000;
  return auth.createAndSignEvent(kind: kind, content: '', tags: const []);
}
''',
        });

        expect(_keys(violations), ['lib/lists.dart\t?']);
      });

      test('does not resolve a pattern-bound name through a constant', () {
        final violations = findReplaceablePublishViolations({
          'lib/lists.dart': '''
class Lists {
  static const int kind = 1;

  Future<void> publish(AuthService auth, (int, String) picked) {
    final (kind, content) = picked;
    return auth.createAndSignEvent(kind: kind, content: content, tags: const []);
  }
}
''',
        });

        expect(_keys(violations), ['lib/lists.dart\t?']);
      });

      test('resolves a local declared in a switch case', () {
        final violations = findReplaceablePublishViolations({
          'lib/lists.dart': '''
const kind = 1;

Future<void> publish(AuthService auth, int choice) async {
  switch (choice) {
    case 0:
      const kind = 10000;
      await auth.createAndSignEvent(kind: kind, content: '', tags: const []);
  }
}
''',
        });

        expect(_keys(violations), ['lib/lists.dart\t10000']);
      });
    });

    group('readCurrentVersion', () {
      test('clears a publish whose file reads the same kind', () {
        final violations = findReplaceablePublishViolations({
          'lib/mute_list.dart': '''
Future<void> publish(NostrClient client, Signer signer, String pubkey) async {
  await client.readCurrentVersion(kind: 10000, pubkey: pubkey);
  await signer.createAndSignEvent(kind: 10000, content: '', tags: const []);
}
''',
        });

        expect(violations, isEmpty);
      });

      test('keeps a publish whose file reads a different kind', () {
        final violations = findReplaceablePublishViolations({
          'lib/mute_list.dart': '''
Future<void> publish(NostrClient client, Signer signer, String pubkey) async {
  await client.readCurrentVersion(kind: 10002, pubkey: pubkey);
  await signer.createAndSignEvent(kind: 10000, content: '', tags: const []);
}
''',
        });

        expect(_keys(violations), ['lib/mute_list.dart\t10000']);
      });
    });

    group('newestVideoRevision', () {
      const republishOwnKind = '''
Future<void> republish(Signer signer, VideoEvent video) async {
  final latest = await newestVideoRevision(read, video, logName: 'x');
  await signer.createAndSignEvent(
    kind: latest!.kind,
    content: '',
    tags: const [],
  );
}
''';

      test('clears a Kind 34236 publish in the same file', () {
        final violations = findReplaceablePublishViolations({
          'lib/video_edit.dart': '''
Future<void> republish(Signer signer, VideoEvent video) async {
  await newestVideoRevision(read, video, logName: 'x');
  await signer.createAndSignEvent(kind: 34236, content: '', tags: const []);
}
''',
        });

        expect(violations, isEmpty);
      });

      test('clears a Kind 34235 publish in the same file', () {
        final violations = findReplaceablePublishViolations({
          'lib/video_edit.dart': '''
Future<void> republish(Signer signer, VideoEvent video) async {
  await newestVideoRevision(read, video, logName: 'x');
  await signer.createAndSignEvent(kind: 34235, content: '', tags: const []);
}
''',
        });

        expect(violations, isEmpty);
      });

      test('clears a publish of the unresolved kind the video carries', () {
        final violations = findReplaceablePublishViolations({
          'lib/video_edit.dart': republishOwnKind,
        });

        expect(violations, isEmpty);
      });

      test('reports the same publishes without the call', () {
        final violations = findReplaceablePublishViolations({
          'lib/video_edit.dart': '''
Future<void> republish(Signer signer, Event latest) async {
  await signer.createAndSignEvent(kind: 34236, content: '', tags: const []);
  await signer.createAndSignEvent(
    kind: latest.kind,
    content: '',
    tags: const [],
  );
}
''',
        });

        expect(_keys(violations), [
          'lib/video_edit.dart\t34236',
          'lib/video_edit.dart\t?',
        ]);
      });

      for (final kind in [10002, 30000]) {
        test('does not clear a Kind $kind publish in the same file', () {
          final violations = findReplaceablePublishViolations({
            'lib/video_edit.dart':
                '''
Future<void> republish(Signer signer, VideoEvent video) async {
  await newestVideoRevision(read, video, logName: 'x');
  await signer.createAndSignEvent(kind: 34236, content: '', tags: const []);
  await signer.createAndSignEvent(kind: $kind, content: '', tags: const []);
}
''',
          });

          expect(_keys(violations), ['lib/video_edit.dart\t$kind']);
        });
      }
    });
  });
}
