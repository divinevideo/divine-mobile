// ABOUTME: Account isolation and durable cleanup for official announcement state.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/notifications/services/announcement_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repository extends Mock implements AnnouncementsRepository {}

void main() {
  const alice =
      '31ef21a624ab5576f14705fdbb56bead914b20154baf8a47d7c28c8103718b04';
  const bob =
      '9cedf5a0f75ba9be6541bf2b83c663c695431d548512ed9b42bf891a904d7b28';
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  group('readSeen, writeSeen, and clearOwner', () {
    test(
      'seen IDs and catalogs belong to their complete account key',
      () async {
        final a = SharedPreferencesAnnouncementStore(
          prefs: prefs,
          owner: alice,
        );
        final b = SharedPreferencesAnnouncementStore(prefs: prefs, owner: bob);
        await a.writeSeen(['announcement:first']);
        await a.writeCatalog('catalog-a');
        expect(await a.readSeen(), ['announcement:first']);
        expect(await b.readSeen(), isEmpty);
        expect(await b.readCatalog(), isNull);
        expect(prefs.getKeys().every((key) => key.contains(alice)), isTrue);
      },
    );
    test(
      'cleanup drains outgoing writes before deleting only that owner',
      () async {
        final a = SharedPreferencesAnnouncementStore(
          prefs: prefs,
          owner: alice,
        );
        final b = SharedPreferencesAnnouncementStore(prefs: prefs, owner: bob);
        await a.writeSeen(['announcement:old']);
        await b.writeSeen(['announcement:b']);
        final repository = _Repository();
        final finishing = Completer<void>();
        when(repository.close).thenAnswer((_) async {
          await finishing.future;
          await a.writeSeen(['announcement:late']);
        });
        final sessions = AnnouncementSessions();
        sessions.register(alice, repository);
        final cleanup = sessions.clearOwner(prefs, alice);
        expect(await a.readSeen(), ['announcement:old']);
        finishing.complete();
        await cleanup;
        expect(await a.readSeen(), isEmpty);
        expect(await b.readSeen(), ['announcement:b']);
        verify(repository.close).called(1);
      },
    );
  });
}
