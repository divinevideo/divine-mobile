// ABOUTME: Tests that the curation provider re-reads editor's picks on refresh
// ABOUTME: Covers the tab-return path that left Editor's Pick blank after nav

import 'package:curation_repository/curation_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/video_events_providers.dart';

import '../helpers/test_helpers.dart';
import '../helpers/test_provider_overrides.dart';

class _MockCurationRepository extends Mock implements CurationRepository {}

/// Emits nothing, so the `videoEventsProvider` listener in `Curation.build`
/// cannot fire and add refresh calls this file's `verify` counts would see.
class _SilentVideoEvents extends VideoEvents {
  @override
  Stream<List<VideoEvent>> build() => const Stream.empty();
}

void main() {
  group('CurationProvider tab refresh', () {
    late _MockCurationRepository mockCurationRepository;
    late MockAuthService mockAuthService;

    setUp(() {
      mockCurationRepository = _MockCurationRepository();
      mockAuthService = createMockAuthService();
    });

    void stubEditorsPicks(List<VideoEvent> videos) {
      when(
        () => mockCurationRepository.getVideosForSetType(
          CurationSetType.editorsPicks,
        ),
      ).thenReturn(videos);
    }

    ProviderContainer createContainer() {
      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(mockAuthService: mockAuthService),
          curationRepositoryProvider.overrideWithValue(mockCurationRepository),
          videoEventsProvider.overrideWith(_SilentVideoEvents.new),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test(
      'refreshAll picks up editor picks the repository gained after build',
      () async {
        stubEditorsPicks([]);
        when(mockCurationRepository.refreshIfNeeded).thenReturn(null);

        final container = createContainer();
        expect(
          container.read(curationProvider).editorsPicks,
          isEmpty,
          reason: 'the repository has nothing cached yet',
        );

        final fetched = TestHelpers.createMockVideoEvents(3);
        stubEditorsPicks(fetched);

        await container.read(curationProvider.notifier).refreshAll();

        final picks = container.read(curationProvider).editorsPicks;
        expect(picks, hasLength(3));
        // VideoEvent's == compares id alone, so a plain equals() on the list
        // would pass on events that lost every other field in transit.
        expect(
          picks.map((v) => v.id).toList(),
          fetched.map((v) => v.id).toList(),
        );
        expect(
          picks.map((v) => v.title).toList(),
          fetched.map((v) => v.title).toList(),
        );
        expect(
          picks.map((v) => v.videoUrl).toList(),
          fetched.map((v) => v.videoUrl).toList(),
        );
      },
    );

    test(
      'refreshAll asks the repository to refresh before re-reading it',
      () async {
        stubEditorsPicks([]);
        when(mockCurationRepository.refreshIfNeeded).thenReturn(null);

        final container = createContainer();
        container.read(curationProvider);
        verifyNever(mockCurationRepository.refreshIfNeeded);

        await container.read(curationProvider.notifier).refreshAll();

        verifyInOrder([
          mockCurationRepository.refreshIfNeeded,
          () => mockCurationRepository.getVideosForSetType(
            CurationSetType.editorsPicks,
          ),
        ]);
      },
    );

    test(
      'a failed refresh records the error and keeps the visible picks',
      () async {
        final loaded = TestHelpers.createMockVideoEvents(2);
        stubEditorsPicks(loaded);
        when(mockCurationRepository.refreshIfNeeded).thenReturn(null);

        final container = createContainer();
        expect(container.read(curationProvider).editorsPicks, hasLength(2));

        when(
          mockCurationRepository.refreshIfNeeded,
        ).thenThrow(StateError('relay unreachable'));

        await container.read(curationProvider.notifier).refreshAll();

        final state = container.read(curationProvider);
        expect(state.error, contains('relay unreachable'));
        expect(
          state.editorsPicks,
          hasLength(2),
          reason: 'a failed refresh must not blank the tab it was refreshing',
        );
      },
    );

    test('a later successful refresh clears the stale error', () async {
      stubEditorsPicks([]);
      when(
        mockCurationRepository.refreshIfNeeded,
      ).thenThrow(StateError('relay unreachable'));

      final container = createContainer();
      await container.read(curationProvider.notifier).refreshAll();
      expect(container.read(curationProvider).error, isNotNull);

      when(mockCurationRepository.refreshIfNeeded).thenReturn(null);
      stubEditorsPicks(TestHelpers.createMockVideoEvents(1));

      await container.read(curationProvider.notifier).refreshAll();

      final state = container.read(curationProvider);
      expect(state.error, isNull);
      expect(state.editorsPicks, hasLength(1));
    });
  });
}
