// ABOUTME: Tests for TagsPickerBloc — sanitize/dedup/search behavior.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/tags_picker/tags_picker_bloc.dart';

class _MockHashtagRepository extends Mock implements HashtagRepository {}

void main() {
  group(TagsPickerBloc, () {
    late _MockHashtagRepository repo;

    setUp(() {
      repo = _MockHashtagRepository();
      when(
        () => repo.searchHashtags(
          query: any(named: 'query'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => []);
    });

    TagsPickerBloc createBloc({Set<String> initial = const <String>{}}) =>
        TagsPickerBloc(hashtagRepository: repo, initialTags: initial);

    test('initial state contains the initialTags and is idle', () async {
      final bloc = createBloc(initial: {'foo', 'bar'});
      expect(bloc.state.selectedTags, {'foo', 'bar'});
      expect(bloc.state.status, TagsPickerStatus.initial);
      expect(bloc.state.query, isEmpty);
      expect(bloc.state.searchResults, isEmpty);
      expect(bloc.state.suggestions, isEmpty);
      await bloc.close();
    });

    group('TagsPickerTagsAdded', () {
      blocTest<TagsPickerBloc, TagsPickerState>(
        'sanitizes tokens (strips non-alphanumeric)',
        build: createBloc,
        act: (b) => b.add(const TagsPickerTagsAdded(['#foo!', 'bar-baz'])),
        expect: () => [
          isA<TagsPickerState>().having((s) => s.selectedTags, 'selectedTags', {
            'foo',
            'barbaz',
          }),
        ],
      );

      blocTest<TagsPickerBloc, TagsPickerState>(
        'is case-insensitive deduping against existing tags',
        build: () => createBloc(initial: {'Foo'}),
        act: (b) => b.add(const TagsPickerTagsAdded(['FOO', 'bar'])),
        expect: () => [
          isA<TagsPickerState>().having((s) => s.selectedTags, 'selectedTags', {
            'Foo',
            'bar',
          }),
        ],
      );

      blocTest<TagsPickerBloc, TagsPickerState>(
        'emits nothing when all tokens are empty or duplicates',
        build: () => createBloc(initial: {'foo'}),
        act: (b) => b.add(const TagsPickerTagsAdded(['', '   ', 'foo'])),
        expect: () => const <TagsPickerState>[],
      );

      blocTest<TagsPickerBloc, TagsPickerState>(
        'commits all tokens from a pasted batch',
        build: createBloc,
        act: (b) => b.add(const TagsPickerTagsAdded(['foo', 'bar', 'baz'])),
        expect: () => [
          isA<TagsPickerState>().having((s) => s.selectedTags, 'selectedTags', {
            'foo',
            'bar',
            'baz',
          }),
        ],
      );

      blocTest<TagsPickerBloc, TagsPickerState>(
        'filters suggestions against newly-added tags',
        build: createBloc,
        seed: () => const TagsPickerState(
          query: 'foo',
          searchResults: ['foo', 'foobar', 'other'],
          status: TagsPickerStatus.success,
        ),
        act: (b) => b.add(const TagsPickerTagsAdded(['foo'])),
        expect: () => [
          isA<TagsPickerState>()
              .having((s) => s.selectedTags, 'selectedTags', {'foo'})
              .having((s) => s.suggestions, 'suggestions', ['foobar', 'other']),
        ],
      );
    });

    group('TagsPickerSuggestionSelected', () {
      blocTest<TagsPickerBloc, TagsPickerState>(
        'preserves the active query while filtering visible suggestions',
        build: createBloc,
        seed: () => const TagsPickerState(
          query: 'mus',
          searchResults: ['music', 'musician'],
          status: TagsPickerStatus.success,
        ),
        act: (b) => b.add(const TagsPickerSuggestionSelected('music')),
        expect: () => [
          isA<TagsPickerState>()
              .having((s) => s.selectedTags, 'selectedTags', {'music'})
              .having((s) => s.query, 'query', 'mus')
              .having((s) => s.searchResults, 'searchResults', [
                'music',
                'musician',
              ])
              .having((s) => s.suggestions, 'suggestions', ['musician']),
        ],
      );
    });

    group('TagsPickerTagRemoved', () {
      blocTest<TagsPickerBloc, TagsPickerState>(
        'removes a previously selected tag',
        build: () => createBloc(initial: {'foo', 'bar'}),
        act: (b) => b.add(const TagsPickerTagRemoved('foo')),
        expect: () => [
          isA<TagsPickerState>().having((s) => s.selectedTags, 'selectedTags', {
            'bar',
          }),
        ],
      );

      blocTest<TagsPickerBloc, TagsPickerState>(
        'restores a removed suggestion while keeping the active search',
        build: createBloc,
        seed: () => const TagsPickerState(
          selectedTags: {'music'},
          query: 'mus',
          searchResults: ['music', 'musician'],
          status: TagsPickerStatus.success,
        ),
        act: (b) => b.add(const TagsPickerTagRemoved('music')),
        expect: () => [
          isA<TagsPickerState>()
              .having((s) => s.selectedTags, 'selectedTags', <String>{})
              .having((s) => s.query, 'query', 'mus')
              .having((s) => s.suggestions, 'suggestions', [
                'music',
                'musician',
              ]),
        ],
      );

      blocTest<TagsPickerBloc, TagsPickerState>(
        'is a no-op for an unknown tag',
        build: () => createBloc(initial: {'foo'}),
        act: (b) => b.add(const TagsPickerTagRemoved('xxx')),
        expect: () => const <TagsPickerState>[],
      );
    });

    group('TagsPickerQueryChanged', () {
      // Matches searchDebounceDuration (300ms) plus buffer.
      const debounce = Duration(milliseconds: 400);

      blocTest<TagsPickerBloc, TagsPickerState>(
        'emits [searching, success] with filtered suggestions',
        setUp: () {
          when(
            () => repo.searchHashtags(query: 'mus'),
          ).thenAnswer((_) async => ['music', 'musician']);
        },
        build: () => createBloc(initial: {'Music'}),
        act: (b) => b.add(const TagsPickerQueryChanged('mus')),
        wait: debounce,
        expect: () => [
          isA<TagsPickerState>()
              .having((s) => s.status, 'status', TagsPickerStatus.searching)
              .having((s) => s.query, 'query', 'mus'),
          isA<TagsPickerState>()
              .having((s) => s.status, 'status', TagsPickerStatus.success)
              .having((s) => s.searchResults, 'searchResults', [
                'music',
                'musician',
              ])
              .having((s) => s.suggestions, 'suggestions', ['musician']),
        ],
        verify: (_) {
          verify(() => repo.searchHashtags(query: 'mus')).called(1);
        },
      );

      blocTest<TagsPickerBloc, TagsPickerState>(
        'resets to initial when query is whitespace',
        build: createBloc,
        seed: () => const TagsPickerState(
          query: 'old',
          searchResults: ['old'],
          status: TagsPickerStatus.success,
        ),
        act: (b) => b.add(const TagsPickerQueryChanged('   ')),
        wait: debounce,
        expect: () => [const TagsPickerState()],
        verify: (_) {
          verifyNever(() => repo.searchHashtags(query: any(named: 'query')));
        },
      );

      blocTest<TagsPickerBloc, TagsPickerState>(
        'clears search state immediately on TagsPickerSearchCleared',
        build: createBloc,
        seed: () => const TagsPickerState(
          query: 'old',
          searchResults: ['old'],
          status: TagsPickerStatus.success,
        ),
        act: (b) => b.add(const TagsPickerSearchCleared()),
        expect: () => [const TagsPickerState()],
      );
    });

    group('canAddQuery', () {
      test('false when sanitized query is empty', () {
        const state = TagsPickerState(query: '  ###  ');
        expect(state.canAddQuery, isFalse);
      });

      test('false when query already in selectedTags (case-insensitive)', () {
        const state = TagsPickerState(query: 'FOO', selectedTags: {'foo'});
        expect(state.canAddQuery, isFalse);
      });

      test('true when sanitized query is new', () {
        const state = TagsPickerState(query: 'foo!');
        expect(state.canAddQuery, isTrue);
        expect(state.sanitizedQuery, 'foo');
      });
    });
  });

  group('parseTagsPickerInput', () {
    test('no separator → empty completed and full remainder', () {
      final r = parseTagsPickerInput(text: 'foo', previousText: 'fo');
      expect(r.completed, isEmpty);
      expect(r.remainder, 'foo');
    });

    test(
      'typed trailing separator commits leading token, keeps empty rest',
      () {
        final r = parseTagsPickerInput(text: 'foo ', previousText: 'foo');
        expect(r.completed, ['foo']);
        expect(r.remainder, '');
      },
    );

    test('typed token after separator keeps it as remainder', () {
      final r = parseTagsPickerInput(text: 'foo bar', previousText: 'foo ba');
      expect(r.completed, ['foo']);
      expect(r.remainder, 'bar');
    });

    test('paste of multiple tokens commits all (no remainder kept)', () {
      final r = parseTagsPickerInput(text: 'foo, bar, baz', previousText: '');
      expect(r.completed, ['foo', 'bar', 'baz']);
      expect(r.remainder, '');
    });

    test('paste with trailing separator still commits all tokens', () {
      final r = parseTagsPickerInput(text: 'foo bar baz ', previousText: '');
      expect(r.completed, ['foo', 'bar', 'baz']);
      expect(r.remainder, '');
    });

    test('comma-only separator works the same as space', () {
      final r = parseTagsPickerInput(text: 'foo,bar', previousText: 'foo,ba');
      expect(r.completed, ['foo']);
      expect(r.remainder, 'bar');
    });

    test('typed branch filters empty tokens from consecutive separators', () {
      // User typed a second comma — `foo,,` produces ['foo', '', ''] which
      // must collapse to just the leading token, with an empty remainder.
      final r = parseTagsPickerInput(text: 'foo,,', previousText: 'foo,');
      expect(r.completed, ['foo']);
      expect(r.remainder, '');
    });

    test('paste with mixed separators (comma + space) commits all tokens', () {
      final r = parseTagsPickerInput(
        text: 'foo, bar,baz qux',
        previousText: '',
      );
      expect(r.completed, ['foo', 'bar', 'baz', 'qux']);
      expect(r.remainder, '');
    });

    test('parser is sanitize-agnostic — passes tokens through verbatim', () {
      // Sanitization is the bloc's job (TagsPickerTagsAdded). The parser
      // must not silently drop tokens that contain non-alphanumeric chars,
      // otherwise the bloc never sees them and can't normalize them.
      final r = parseTagsPickerInput(text: '#foo, #bar', previousText: '');
      expect(r.completed, ['#foo', '#bar']);
      expect(r.remainder, '');
    });
  });
}
