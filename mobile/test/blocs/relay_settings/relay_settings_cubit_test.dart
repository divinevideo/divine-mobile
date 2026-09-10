// ABOUTME: Unit tests for RelaySettingsCubit — load snapshot, capability
// ABOUTME: fetch lifecycle, addRelay validation (scheme + insecure),
// ABOUTME: removeRelay, restoreDefaultRelay, retryConnection.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/relay_settings/relay_settings_cubit.dart';
import 'package:openvine/blocs/relay_settings/relay_settings_state.dart';
import 'package:openvine/repositories/relay_list_repository.dart';
import 'package:openvine/services/relay_capability_service.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockRelayCapabilityService extends Mock
    implements RelayCapabilityService {}

class _MockRelayListRepository extends Mock implements RelayListRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

void main() {
  setUpAll(() {
    registerFallbackValue(RelayAddSource.automatic);
    registerFallbackValue(RelayRemoveSource.user);
  });

  group(RelaySettingsCubit, () {
    late _MockNostrClient nostr;
    late _MockRelayListRepository relayListRepository;
    late _MockRelayCapabilityService capabilities;
    late _MockVideoEventService videos;

    setUp(() {
      nostr = _MockNostrClient();
      relayListRepository = _MockRelayListRepository();
      capabilities = _MockRelayCapabilityService();
      videos = _MockVideoEventService();
      when(() => nostr.configuredRelays).thenReturn(const []);
      when(() => nostr.connectedRelayCount).thenReturn(0);
      when(
        () => nostr.addRelay(any(), source: any(named: 'source')),
      ).thenAnswer((_) async => true);
      when(
        () => nostr.removeRelay(any(), source: any(named: 'source')),
      ).thenAnswer((_) async => true);
      when(
        relayListRepository.publishConfiguredRelayList,
      ).thenAnswer((_) async => const RelayListPublishResult.published());
      when(nostr.forceReconnectAll).thenAnswer(
        (_) async => ForceReconnectOutcome.completed,
      );
      when(videos.resetAndResubscribeAll).thenAnswer((_) async {});
    });

    RelaySettingsCubit buildCubit() => RelaySettingsCubit(
      nostrClient: nostr,
      relayListRepository: relayListRepository,
      relayCapabilityService: capabilities,
      videoEventService: videos,
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'load snapshots configured relays',
      setUp: () {
        when(
          () => nostr.configuredRelays,
        ).thenReturn(['wss://a.example', 'wss://b.example']);
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        const RelaySettingsState(
          relays: ['wss://a.example', 'wss://b.example'],
        ),
      ],
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'fetchCapabilities emits loading then fetched',
      setUp: () {
        when(
          () => capabilities.getRelayCapabilities('wss://a.example'),
        ).thenAnswer(
          (_) async => RelayCapabilities(
            relayUrl: 'wss://a.example',
            supportedNips: const [1, 11],
            rawData: const {},
          ),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.fetchCapabilities('wss://a.example'),
      // `RelayCapabilities` doesn't extend Equatable, so use matchers
      // instead of concrete equality on the second emit.
      expect: () => [
        const RelaySettingsState(
          capabilities: {
            'wss://a.example': RelayCapabilityEntry(loading: true),
          },
        ),
        isA<RelaySettingsState>().having(
          (s) => s.capabilities['wss://a.example'],
          'fetched entry',
          isA<RelayCapabilityEntry>()
              .having((e) => e.loading, 'loading', isFalse)
              .having((e) => e.fetched, 'fetched', isTrue)
              .having((e) => e.capabilities?.supportedNips, 'supportedNips', [
                1,
                11,
              ]),
        ),
      ],
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'fetchCapabilities short-circuits on second call',
      seed: () => const RelaySettingsState(
        capabilities: {'wss://a.example': RelayCapabilityEntry(fetched: true)},
      ),
      build: buildCubit,
      act: (cubit) => cubit.fetchCapabilities('wss://a.example'),
      expect: () => const <RelaySettingsState>[],
      verify: (_) {
        verifyNever(() => capabilities.getRelayCapabilities(any()));
      },
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'fetchCapabilities surfaces service errors via addError + fetched=true',
      setUp: () {
        when(
          () => capabilities.getRelayCapabilities('wss://b.example'),
        ).thenThrow(StateError('nip-11 timed out'));
      },
      build: buildCubit,
      act: (cubit) => cubit.fetchCapabilities('wss://b.example'),
      expect: () => [
        const RelaySettingsState(
          capabilities: {
            'wss://b.example': RelayCapabilityEntry(loading: true),
          },
        ),
        const RelaySettingsState(
          capabilities: {
            'wss://b.example': RelayCapabilityEntry(fetched: true),
          },
        ),
      ],
      errors: () => [isA<StateError>()],
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'addRelay rejects empty and non-ws schemes as invalidUrl',
      build: buildCubit,
      act: (cubit) async {
        expect(await cubit.addRelay(''), AddRelayOutcome.invalidUrl);
        expect(
          await cubit.addRelay('https://example.com'),
          AddRelayOutcome.invalidUrl,
        );
        expect(await cubit.addRelay('not a url'), AddRelayOutcome.invalidUrl);
      },
      expect: () => const <RelaySettingsState>[],
      verify: (_) {
        verifyNever(() => nostr.addRelay(any(), source: any(named: 'source')));
      },
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'addRelay accepts wss:// and re-snapshots relays',
      setUp: () {
        when(() => nostr.configuredRelays).thenReturn(['wss://added.example']);
      },
      build: buildCubit,
      act: (cubit) async {
        final outcome = await cubit.addRelay('wss://added.example');
        expect(outcome, AddRelayOutcome.added);
      },
      expect: () => [
        const RelaySettingsState(relays: ['wss://added.example']),
      ],
      verify: (_) {
        verify(
          () => nostr.addRelay(
            'wss://added.example',
            source: RelayAddSource.user,
          ),
        ).called(1);
        verify(relayListRepository.publishConfiguredRelayList).called(1);
      },
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'addRelay returns failed when service returns false',
      setUp: () {
        when(
          () => nostr.addRelay(any(), source: any(named: 'source')),
        ).thenAnswer((_) async => false);
      },
      build: buildCubit,
      act: (cubit) async {
        final outcome = await cubit.addRelay('wss://noop.example');
        expect(outcome, AddRelayOutcome.failed);
      },
      expect: () => [const RelaySettingsState()],
      verify: (_) {
        verifyNever(relayListRepository.publishConfiguredRelayList);
      },
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'addRelay refreshes when relay is saved but connection is pending',
      setUp: () {
        when(
          () => nostr.addRelay(any(), source: any(named: 'source')),
        ).thenAnswer((_) async => false);
        when(
          () => nostr.configuredRelays,
        ).thenReturn(['wss://pending.example']);
      },
      build: buildCubit,
      act: (cubit) async {
        final outcome = await cubit.addRelay('wss://pending.example');
        expect(outcome, AddRelayOutcome.addedConnectionPending);
      },
      expect: () => [
        const RelaySettingsState(relays: ['wss://pending.example']),
      ],
      verify: (_) {
        verify(relayListRepository.publishConfiguredRelayList).called(1);
      },
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'addRelay returns local-only when publish fails after local save',
      setUp: () {
        when(() => nostr.configuredRelays).thenReturn(['wss://added.example']);
        when(relayListRepository.publishConfiguredRelayList).thenAnswer(
          (_) async => RelayListPublishResult.failed(
            StateError('no indexer accepted'),
            StackTrace.current,
          ),
        );
      },
      build: buildCubit,
      act: (cubit) async {
        final outcome = await cubit.addRelay('wss://added.example');
        expect(outcome, AddRelayOutcome.addedLocalOnly);
      },
      expect: () => [
        const RelaySettingsState(relays: ['wss://added.example']),
      ],
      errors: () => [isA<StateError>()],
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'addRelay surfaces service throw via addError + failed outcome',
      setUp: () {
        when(
          () => nostr.addRelay(any(), source: any(named: 'source')),
        ).thenThrow(StateError('boom'));
      },
      build: buildCubit,
      act: (cubit) async {
        expect(
          await cubit.addRelay('wss://throws.example'),
          AddRelayOutcome.failed,
        );
      },
      expect: () => const <RelaySettingsState>[],
      errors: () => [isA<StateError>()],
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'removeRelay re-snapshots on success',
      seed: () => const RelaySettingsState(
        relays: ['wss://a.example', 'wss://b.example'],
      ),
      setUp: () {
        when(() => nostr.configuredRelays).thenReturn(['wss://a.example']);
      },
      build: buildCubit,
      act: (cubit) async {
        final outcome = await cubit.removeRelay('wss://b.example');
        expect(outcome, RemoveRelayOutcome.removed);
      },
      expect: () => [
        const RelaySettingsState(relays: ['wss://a.example']),
      ],
      verify: (_) {
        verify(
          () => nostr.removeRelay(
            'wss://b.example',
            source: RelayRemoveSource.user,
          ),
        ).called(1);
        verify(relayListRepository.publishConfiguredRelayList).called(1);
      },
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'removeRelay returns failed when service returns false',
      setUp: () {
        when(
          () => nostr.removeRelay(any(), source: any(named: 'source')),
        ).thenAnswer((_) async => false);
        when(() => nostr.configuredRelays).thenReturn(['wss://a.example']);
      },
      build: buildCubit,
      act: (cubit) async {
        expect(
          await cubit.removeRelay('wss://a.example'),
          RemoveRelayOutcome.failed,
        );
      },
      expect: () => [
        const RelaySettingsState(relays: ['wss://a.example']),
      ],
      verify: (_) {
        verifyNever(relayListRepository.publishConfiguredRelayList);
      },
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'removeRelay refreshes and reports removed when relay is already gone',
      seed: () => const RelaySettingsState(relays: ['wss://stale.example']),
      setUp: () {
        when(
          () => nostr.removeRelay(any(), source: any(named: 'source')),
        ).thenAnswer((_) async => false);
        when(() => nostr.configuredRelays).thenReturn(const []);
      },
      build: buildCubit,
      act: (cubit) async {
        expect(
          await cubit.removeRelay('wss://stale.example'),
          RemoveRelayOutcome.removed,
        );
      },
      expect: () => [const RelaySettingsState()],
      verify: (_) {
        verify(relayListRepository.publishConfiguredRelayList).called(1);
      },
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'removeRelay returns local-only when publish fails after local removal',
      seed: () => const RelaySettingsState(relays: ['wss://gone.example']),
      setUp: () {
        when(() => nostr.configuredRelays).thenReturn(const []);
        when(relayListRepository.publishConfiguredRelayList).thenAnswer(
          (_) async => RelayListPublishResult.failed(
            StateError('no indexer accepted'),
            StackTrace.current,
          ),
        );
      },
      build: buildCubit,
      act: (cubit) async {
        expect(
          await cubit.removeRelay('wss://gone.example'),
          RemoveRelayOutcome.removedLocalOnly,
        );
      },
      expect: () => [const RelaySettingsState()],
      errors: () => [isA<StateError>()],
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      "restoreDefaultRelay restores the client's environment default relay",
      setUp: () {
        when(
          () => nostr.defaultRelayUrl,
        ).thenReturn('wss://relay.staging.divine.video');
        when(() => nostr.configuredRelays).thenReturn(['wss://default']);
      },
      build: buildCubit,
      act: (cubit) async {
        expect(
          await cubit.restoreDefaultRelay(),
          RestoreDefaultRelayOutcome.restored,
        );
      },
      verify: (_) {
        verify(
          () => nostr.addRelay(
            'wss://relay.staging.divine.video',
            source: RelayAddSource.user,
          ),
        ).called(1);
        verify(relayListRepository.publishConfiguredRelayList).called(1);
      },
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'restoreDefaultRelay refreshes when relay is configured but not connected',
      setUp: () {
        when(
          () => nostr.defaultRelayUrl,
        ).thenReturn('wss://relay.staging.divine.video');
        when(
          () => nostr.addRelay(
            'wss://relay.staging.divine.video',
            source: RelayAddSource.user,
          ),
        ).thenAnswer((_) async => false);
        when(
          () => nostr.configuredRelays,
        ).thenReturn(['wss://relay.staging.divine.video']);
      },
      build: buildCubit,
      act: (cubit) async {
        expect(
          await cubit.restoreDefaultRelay(),
          RestoreDefaultRelayOutcome.restoredConnectionPending,
        );
      },
      expect: () => [
        const RelaySettingsState(relays: ['wss://relay.staging.divine.video']),
      ],
      verify: (_) {
        verify(
          () => nostr.addRelay(
            'wss://relay.staging.divine.video',
            source: RelayAddSource.user,
          ),
        ).called(1);
        verify(relayListRepository.publishConfiguredRelayList).called(1);
      },
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'restoreDefaultRelay returns local-only when publish fails after restore',
      setUp: () {
        when(
          () => nostr.defaultRelayUrl,
        ).thenReturn('wss://relay.staging.divine.video');
        when(
          () => nostr.configuredRelays,
        ).thenReturn(['wss://relay.staging.divine.video']);
        when(relayListRepository.publishConfiguredRelayList).thenAnswer(
          (_) async => RelayListPublishResult.failed(
            StateError('no indexer accepted'),
            StackTrace.current,
          ),
        );
      },
      build: buildCubit,
      act: (cubit) async {
        expect(
          await cubit.restoreDefaultRelay(),
          RestoreDefaultRelayOutcome.restoredLocalOnly,
        );
      },
      expect: () => [
        const RelaySettingsState(relays: ['wss://relay.staging.divine.video']),
      ],
      errors: () => [isA<StateError>()],
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'retryConnection emits connected with count when relays reconnect',
      setUp: () {
        when(() => nostr.connectedRelayCount).thenReturn(2);
      },
      build: buildCubit,
      act: (cubit) async {
        final outcome = await cubit.retryConnection();
        expect(outcome.kind, RetryConnectionOutcomeKind.connected);
        expect(outcome.connectedCount, 2);
      },
      expect: () => const <RelaySettingsState>[],
      verify: (_) {
        verify(nostr.forceReconnectAll).called(1);
        verify(videos.resetAndResubscribeAll).called(1);
      },
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'retryConnection emits notConnected when count is zero',
      build: buildCubit,
      act: (cubit) async {
        final outcome = await cubit.retryConnection();
        expect(outcome.kind, RetryConnectionOutcomeKind.notConnected);
      },
      verify: (_) {
        verifyNever(videos.resetAndResubscribeAll);
      },
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'retryConnection reports stillConnecting, not notConnected, when the '
      'reconnect had not finished',
      setUp: () {
        // The shared cycle keeps dialling past the deadline. Zero connected
        // relays here means "no answer yet", and calling it a failure told the
        // user the retry failed while it was still succeeding.
        when(nostr.forceReconnectAll).thenAnswer(
          (_) async => ForceReconnectOutcome.stillDialling,
        );
      },
      build: buildCubit,
      act: (cubit) async {
        final outcome = await cubit.retryConnection();
        expect(outcome.kind, RetryConnectionOutcomeKind.stillConnecting);
      },
      verify: (_) {
        verifyNever(videos.resetAndResubscribeAll);
      },
    );

    blocTest<RelaySettingsCubit, RelaySettingsState>(
      'retryConnection emits failed and addError on service throw',
      setUp: () {
        when(nostr.forceReconnectAll).thenThrow(StateError('nope'));
      },
      build: buildCubit,
      act: (cubit) async {
        final outcome = await cubit.retryConnection();
        expect(outcome.kind, RetryConnectionOutcomeKind.failed);
      },
      errors: () => [isA<StateError>()],
    );
  });
}
