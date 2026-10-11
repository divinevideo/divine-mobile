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
            'foo',
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
      final r = parseTagsPickerInput(text: 'foo!, bar?', previousText: '');
      expect(r.completed, ['foo!', 'bar?']);
      expect(r.remainder, '');
    });
    test('treats line breaks, tabs, Unicode spaces and # as separators', () {
      final r = parseTagsPickerInput(
        text: '#vines\n#vine\tvinevideo\u00a0funny#comedy',
        previousText: '',
      );
      expect(r.completed, ['vines', 'vine', 'vinevideo', 'funny', 'comedy']);
      expect(r.remainder, '');
    });

    test('commits an over-long pasted word so the bloc can reject it', () {
      final long = 'a' * (HashtagExtractor.maxHashtagLength + 1);
      final r = parseTagsPickerInput(text: long, previousText: '');
      expect(r.completed, [long]);
      expect(r.remainder, isEmpty);
    });

    test('keeps a word of exactly the maximum length in the field', () {
      final word = 'a' * HashtagExtractor.maxHashtagLength;
      final r = parseTagsPickerInput(text: word, previousText: '');
      expect(r.completed, isEmpty);
      expect(r.remainder, word);
    });
  });

  group('$TagsPickerBloc hashtag limits', () {
    late _MockHashtagRepository repo;

    setUp(() {
      repo = _MockHashtagRepository();
    });

    TagsPickerBloc createBloc({Set<String> initial = const <String>{}}) =>
        TagsPickerBloc(hashtagRepository: repo, initialTags: initial);

    final tooLong = 'a' * (HashtagExtractor.maxHashtagLength + 1);
    final maxLength = 'b' * HashtagExtractor.maxHashtagLength;
    final ten = [for (var i = 0; i < 10; i++) 'tag$i'];

    group('TagsPickerTagsAdded', () {
      blocTest<TagsPickerBloc, TagsPickerState>(
        'stores tags in lowercase',
        build: createBloc,
        act: (b) => b.add(const TagsPickerTagsAdded(['FunnyDivines'])),
        expect: () => [
          isA<TagsPickerState>().having((s) => s.selectedTags, 'selectedTags', {
            'funnydivines',
          }),
        ],
      );

      blocTest<TagsPickerBloc, TagsPickerState>(
        'rejects a tag over the length limit instead of truncating it',
        build: createBloc,
        act: (b) => b.add(TagsPickerTagsAdded(['ok', tooLong])),
        expect: () => [
          isA<TagsPickerState>()
              .having((s) => s.selectedTags, 'selectedTags', {'ok'})
              .having((s) => s.notice, 'notice', TagsPickerNotice.tagTooLong),
        ],
      );

      blocTest<TagsPickerBloc, TagsPickerState>(
        'accepts a tag of exactly the maximum length',
        build: createBloc,
        act: (b) => b.add(TagsPickerTagsAdded([maxLength])),
        expect: () => [
          isA<TagsPickerState>()
              .having((s) => s.selectedTags, 'selectedTags', {maxLength})
              .having((s) => s.notice, 'notice', TagsPickerNotice.none),
        ],
      );

      blocTest<TagsPickerBloc, TagsPickerState>(
        'adds at most ${HashtagExtractor.maxHashtagsPerVideo} tags',
        build: createBloc,
        act: (b) => b.add(TagsPickerTagsAdded([...ten, 'eleven'])),
        expect: () => [
          isA<TagsPickerState>()
              .having((s) => s.selectedTags, 'selectedTags', ten.toSet())
              .having((s) => s.isAtTagLimit, 'isAtTagLimit', isTrue),
        ],
      );

      blocTest<TagsPickerBloc, TagsPickerState>(
        'ignores further tags once the limit is reached',
        build: () => createBloc(initial: ten.toSet()),
        act: (b) => b.add(const TagsPickerTagsAdded(['eleven'])),
        expect: () => const <TagsPickerState>[],
      );
    });

    group('TagsPickerSuggestionSelected', () {
      blocTest<TagsPickerBloc, TagsPickerState>(
        'is ignored once the limit is reached',
        build: () => createBloc(initial: ten.toSet()),
        act: (b) => b.add(const TagsPickerSuggestionSelected('eleven')),
        expect: () => const <TagsPickerState>[],
      );
    });

    group('TagsPickerTagRemoved', () {
      blocTest<TagsPickerBloc, TagsPickerState>(
        'clears a too-long notice',
        build: createBloc,
        seed: () => const TagsPickerState(
          selectedTags: {'foo'},
          notice: TagsPickerNotice.tagTooLong,
        ),
        act: (b) => b.add(const TagsPickerTagRemoved('foo')),
        expect: () => [
          isA<TagsPickerState>().having(
            (s) => s.notice,
            'notice',
            TagsPickerNotice.none,
          ),
        ],
      );
    });

    group('initial tags', () {
      test('are normalized like committed tags', () async {
        final bloc = createBloc(
          initial: {
            'FunnyDivines',
            tooLong,
            ...ten.map((t) => t.toUpperCase()),
          },
        );
        expect(bloc.state.selectedTags, hasLength(10));
        expect(bloc.state.selectedTags, contains('funnydivines'));
        expect(bloc.state.selectedTags, isNot(contains(tooLong)));
        await bloc.close();
      });
    });

    group('suggestions', () {
      test('are lowercased, deduplicated and exclude over-long tags', () {
        final state = TagsPickerState(
          query: 'fun',
          searchResults: ['FunnyDivines', 'funnydivines', tooLong, 'funny'],
          status: TagsPickerStatus.success,
        );
        expect(state.suggestions, ['funnydivines', 'funny']);
      });
    });

    group('canAddQuery', () {
      test('is false once the limit is reached', () {
        final state = TagsPickerState(
          query: 'eleven',
          selectedTags: ten.toSet(),
        );
        expect(state.canAddQuery, isFalse);
      });

      test('is false for a query over the length limit', () {
        final state = TagsPickerState(query: tooLong);
        expect(state.canAddQuery, isFalse);
      });
    });
  });
}
