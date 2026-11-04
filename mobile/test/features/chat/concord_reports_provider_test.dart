import 'dart:async';

import 'package:concord_repository/concord_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/features/chat/concord_reports_provider.dart';
import 'package:openvine/features/chat/room_catalog_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';

class _Identity extends Fake implements KeycastNostrIdentity {
  final signing = Completer<Event?>();
  final started = Completer<Event>();
  @override
  Future<Event?> signEvent(Event event) {
    started.complete(event);
    return signing.future;
  }
}

class _Auth extends Fake implements AuthService {
  _Auth(this.currentIdentity);
  @override
  String currentPublicKeyHex = '11' * 32;
  @override
  bool isAuthenticated = true;
  @override
  final NostrIdentity currentIdentity;
}

class _Session extends Mock implements ConcordCommunitySession {}

void main() {
  group('concordReportsProvider submit', () {
    for (final change in ['switch', 'logout', 'dispose', 'catalog']) {
      test('pending report does not post after $change', () async {
        final identity = _Identity();
        final auth = _Auth(identity);
        final session = _Session();
        var ready = true;
        when(() => session.ready).thenAnswer((_) => ready);
        final container = ProviderContainer(
          overrides: [
            authServiceProvider.overrideWithValue(auth),
            concordRoomCatalogProvider.overrideWith(
              (ref) => Stream.value(ConcordRoomCatalog.real(session)),
            ),
          ],
        );
        var disposed = false;
        addTearDown(() {
          if (!disposed) container.dispose();
        });
        container.listen(concordRoomCatalogProvider, (_, _) {});
        await container.read(concordRoomCatalogProvider.future);
        final reports = container.read(concordReportsProvider)!;
        var requests = 0;
        await http.runWithClient(
          () async {
            final pending = reports.submit(
              communityId: '22' * 32,
              channelId: '33' * 32,
              rumorId: '44' * 32,
              reason: 'Spam',
            );
            final event = await identity.started.future;
            if (change == 'switch') auth.currentPublicKeyHex = '55' * 32;
            if (change == 'logout') auth.isAuthenticated = false;
            if (change == 'catalog') ready = false;
            if (change == 'dispose') {
              container.dispose();
              disposed = true;
            }
            identity.signing.complete(event);
            await expectLater(pending, throwsStateError);
          },
          () => MockClient((_) async {
            requests++;
            return http.Response('{"caseId":"must-not-submit"}', 202);
          }),
        );
        expect(requests, 0);
      });
    }

    test(
      'rechecks the account immediately before the HTTP client sends',
      () async {
        final identity = _Identity();
        final auth = _Auth(identity);
        final session = _Session();
        when(() => session.ready).thenReturn(true);
        final container = ProviderContainer(
          overrides: [
            authServiceProvider.overrideWithValue(auth),
            concordRoomCatalogProvider.overrideWith(
              (ref) => Stream.value(ConcordRoomCatalog.real(session)),
            ),
          ],
        );
        addTearDown(container.dispose);
        container.listen(concordRoomCatalogProvider, (_, _) {});
        await container.read(concordRoomCatalogProvider.future);
        final reports = container.read(concordReportsProvider)!;
        var requests = 0;
        await http.runWithClient(
          () async {
            final pending = reports.submit(
              communityId: '22' * 32,
              channelId: '33' * 32,
              rumorId: '44' * 32,
              reason: 'Spam',
            );
            identity.signing.complete(await identity.started.future);
            await expectLater(pending, throwsStateError);
          },
          () {
            // The client factory runs after the repository's pre-POST check.
            auth.currentPublicKeyHex = '55' * 32;
            return MockClient((_) async {
              requests++;
              return http.Response('{"caseId":"must-not-submit"}', 202);
            });
          },
        );
        expect(requests, 0);
      },
    );
  });
}
