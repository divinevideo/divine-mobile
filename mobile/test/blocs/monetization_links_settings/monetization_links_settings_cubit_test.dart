// ABOUTME: Tests raw metadata hydration and safe support-link editing.
// ABOUTME: Covers preservation, retry, publish failures, and disposal fencing.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/monetization_links_settings/monetization_links_settings_cubit.dart';
import 'package:openvine/blocs/monetization_links_settings/monetization_links_settings_state.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

const _pubkey =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
const List<MonetizationLinkProvider> _tips = [
  MonetizationLinkProvider.cashApp,
  MonetizationLinkProvider.paypal,
  MonetizationLinkProvider.venmo,
];
const _existingLinks = [
  MonetizationLink(
    provider: MonetizationLinkProvider.cashApp,
    category: MonetizationLinkCategory.tip,
    url: r'https://cash.app/$old',
    enabled: true,
  ),
  MonetizationLink(
    provider: MonetizationLinkProvider.patreon,
    category: MonetizationLinkCategory.subscription,
    url: 'https://www.patreon.com/creator',
    enabled: true,
  ),
];

UserProfile _profile({
  List<MonetizationLink> links = const [],
  String pubkey = _pubkey,
}) => UserProfile(
  pubkey: pubkey,
  displayName: 'Creator',
  rawData: {
    'display_name': 'Creator',
    if (links.isNotEmpty)
      divineMonetizationLinksKey: [for (final link in links) link.toJson()],
  },
  createdAt: DateTime(2026),
  eventId: 'a' * 64,
);

MonetizationLinksSettingsCubit _cubit(
  ProfileRepository? repository, {
  String? pubkey = _pubkey,
  List<MonetizationLinkProvider> providers = _tips,
  MonetizationAnalyticsSink? track,
  MonetizationProfileSaved? onSaved,
}) => MonetizationLinksSettingsCubit(
  repository: repository,
  pubkey: pubkey,
  visibleProviders: providers,
  trackConfiguredLink: track ?? (_) {},
  onProfileSaved: onSaved ?? (_) {},
);

void _stubRead(_MockProfileRepository repository, UserProfile? profile) {
  when(
    () => repository.fetchFreshProfile(pubkey: _pubkey, requireRawKind0: true),
  ).thenAnswer((_) async => profile);
}

void _stubSave(
  _MockProfileRepository repository,
  Future<UserProfile> Function(List<MonetizationLink>) save,
) {
  when(
    () => repository.saveProfileEvent(
      displayName: any(named: 'displayName'),
      about: any(named: 'about'),
      website: any(named: 'website'),
      picture: any(named: 'picture'),
      banner: any(named: 'banner'),
      monetizationLinks: any(named: 'monetizationLinks'),
      currentProfile: any(named: 'currentProfile'),
    ),
  ).thenAnswer(
    (invocation) => save(
      (invocation.namedArguments[#monetizationLinks]
              as Iterable<MonetizationLink>)
          .toList(),
    ),
  );
}

void _expectNoSave(_MockProfileRepository repository) {
  verifyNever(
    () => repository.saveProfileEvent(
      displayName: any(named: 'displayName'),
      about: any(named: 'about'),
      website: any(named: 'website'),
      picture: any(named: 'picture'),
      banner: any(named: 'banner'),
      monetizationLinks: any(named: 'monetizationLinks'),
      currentProfile: any(named: 'currentProfile'),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_profile());
    registerFallbackValue(<MonetizationLink>[]);
  });

  group('raw metadata hydration', () {
    for (final providers in [_tips, MonetizationLinkProvider.values]) {
      test('seeds visible fields and preserves existing links when '
          '${providers.length} providers are editable', () async {
        final repository = _MockProfileRepository();
        _stubRead(repository, _profile(links: _existingLinks));
        final saved = <UserProfile>[];
        _stubSave(repository, (links) async => _profile(links: links));
        final cubit = _cubit(
          repository,
          providers: providers,
          onSaved: saved.add,
        );
        addTearDown(cubit.close);
        await cubit.load();

        expect(
          cubit.state.valueFor(MonetizationLinkProvider.cashApp),
          r'https://cash.app/$old',
        );
        cubit.setValue(MonetizationLinkProvider.cashApp, r'$updated');
        await cubit.save();
        expect(
          saved.single.monetizationLinks,
          containsAll([
            const MonetizationLink(
              provider: MonetizationLinkProvider.cashApp,
              category: MonetizationLinkCategory.tip,
              url: r'https://cash.app/$updated',
              enabled: true,
            ),
            _existingLinks[1],
          ]),
        );
      });
    }

    test('blocks edits and save until the strict read succeeds', () async {
      final repository = _MockProfileRepository();
      final pending = Completer<UserProfile?>();
      when(
        () => repository.fetchFreshProfile(
          pubkey: _pubkey,
          requireRawKind0: true,
        ),
      ).thenAnswer((_) => pending.future);
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      final load = cubit.load();
      cubit.setEnabled(MonetizationLinkProvider.cashApp, true);
      cubit.setValue(MonetizationLinkProvider.cashApp, r'$draft');
      await cubit.save();
      expect(cubit.state.canSave, isFalse);
      expect(cubit.state.valueFor(MonetizationLinkProvider.cashApp), isEmpty);
      expect(cubit.state.isEnabled(MonetizationLinkProvider.cashApp), isFalse);
      _expectNoSave(repository);
      pending.complete(_profile(links: _existingLinks));
      await load;
      expect(cubit.state.canSave, isTrue);
      expect(
        cubit.state.valueFor(MonetizationLinkProvider.cashApp),
        r'https://cash.app/$old',
      );
    });

    test('null raw read fails closed and can retry successfully', () async {
      final repository = _MockProfileRepository();
      _stubRead(repository, null);
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      expect(
        cubit.state.loadStatus,
        MonetizationLinksSettingsLoadStatus.failure,
      );
      cubit.setEnabled(MonetizationLinkProvider.cashApp, true);
      await cubit.save();
      expect(cubit.state.canSave, isFalse);
      _expectNoSave(repository);
      _stubRead(repository, _profile(links: _existingLinks));
      await cubit.load();
      expect(cubit.state.canSave, isTrue);
    });

    test('a failed raw request remains safely retryable', () async {
      final repository = _MockProfileRepository();
      when(
        () => repository.fetchFreshProfile(
          pubkey: _pubkey,
          requireRawKind0: true,
        ),
      ).thenThrow(Exception('network unavailable'));
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      expect(
        cubit.state.loadStatus,
        MonetizationLinksSettingsLoadStatus.failure,
      );
      await cubit.save();
      _expectNoSave(repository);
      _stubRead(repository, _profile());
      await cubit.load();
      expect(cubit.state.canSave, isTrue);
    });

    test('a read for the wrong account cannot seed publishing', () async {
      final repository = _MockProfileRepository();
      _stubRead(repository, _profile(pubkey: 'b' * 64));
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.save();
      expect(cubit.state.canSave, isFalse);
      _expectNoSave(repository);
    });

    test('reloading a ready editor preserves its unsaved draft', () async {
      final repository = _MockProfileRepository();
      _stubRead(repository, _profile(links: _existingLinks));
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      cubit.setValue(MonetizationLinkProvider.cashApp, r'$draft');
      await cubit.load();
      expect(cubit.state.valueFor(MonetizationLinkProvider.cashApp), r'$draft');
    });

    test('missing account or repository cannot publish', () async {
      final repository = _MockProfileRepository();
      for (final cubit in [_cubit(null), _cubit(repository, pubkey: null)]) {
        await cubit.load();
        await cubit.save();
        expect(cubit.state.canSave, isFalse);
        await cubit.close();
      }
      _expectNoSave(repository);
    });
  });

  group('validation and publishing', () {
    for (final (input, reason) in [
      ('', MonetizationLinkInputInvalidReason.empty),
      ('https://paypal.me/x', MonetizationLinkInputInvalidReason.wrongProvider),
    ]) {
      test('validates enabled input: $reason', () async {
        final repository = _MockProfileRepository();
        _stubRead(repository, _profile());
        final cubit = _cubit(repository);
        addTearDown(cubit.close);
        await cubit.load();
        cubit.setEnabled(MonetizationLinkProvider.cashApp, true);
        cubit.setValue(MonetizationLinkProvider.cashApp, input);
        await cubit.save();
        expect(cubit.state.errorFor(MonetizationLinkProvider.cashApp), reason);
        _expectNoSave(repository);
      });
    }

    test('publish failure keeps the draft for retry', () async {
      final repository = _MockProfileRepository();
      _stubRead(repository, _profile());
      _stubSave(
        repository,
        (_) async => throw const NoRelaysConnectedException('no relays'),
      );
      final tracked = <MonetizationLink>[];
      final saved = <UserProfile>[];
      final cubit = _cubit(repository, track: tracked.add, onSaved: saved.add);
      addTearDown(cubit.close);
      await cubit.load();
      cubit.setEnabled(MonetizationLinkProvider.cashApp, true);
      cubit.setValue(MonetizationLinkProvider.cashApp, r'$draft');
      await cubit.save();
      expect(
        cubit.state.failure,
        MonetizationLinksSettingsSaveFailure.noRelays,
      );
      expect(cubit.state.valueFor(MonetizationLinkProvider.cashApp), r'$draft');
      expect(cubit.state.canSave, isTrue);
      expect(saved, isEmpty);
      expect(tracked, isEmpty);
      _stubSave(repository, (links) async => _profile(links: links));
      await cubit.save();
      expect(cubit.state.status, MonetizationLinksSettingsSaveStatus.success);
      expect(saved, hasLength(1));
      expect(tracked.single.url, r'https://cash.app/$draft');
    });
  });

  group('disposal fencing', () {
    test('read completion after close cannot hydrate the editor', () async {
      final repository = _MockProfileRepository();
      final pending = Completer<UserProfile?>();
      when(
        () => repository.fetchFreshProfile(
          pubkey: _pubkey,
          requireRawKind0: true,
        ),
      ).thenAnswer((_) => pending.future);
      final cubit = _cubit(repository);
      final load = cubit.load();
      await cubit.close();
      pending.complete(_profile(links: _existingLinks));
      await load;
      expect(cubit.state.canSave, isFalse);
      expect(cubit.state.currentProfile, isNull);
    });

    test(
      'save completion after close cannot call back or track links',
      () async {
        final repository = _MockProfileRepository();
        _stubRead(repository, _profile(links: _existingLinks));
        final pending = Completer<UserProfile>();
        _stubSave(repository, (_) => pending.future);
        final saved = <UserProfile>[];
        final tracked = <MonetizationLink>[];
        final cubit = _cubit(
          repository,
          onSaved: saved.add,
          track: tracked.add,
        );
        await cubit.load();
        final save = cubit.save();
        cubit.setValue(MonetizationLinkProvider.cashApp, r'$ignored');
        expect(
          cubit.state.valueFor(MonetizationLinkProvider.cashApp),
          r'https://cash.app/$old',
        );
        await cubit.close();
        pending.complete(_profile());
        await save;
        expect(saved, isEmpty);
        expect(tracked, isEmpty);
      },
    );
  });
}
