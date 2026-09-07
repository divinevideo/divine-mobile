import 'dart:async';

import 'package:meta/meta.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/mention_pattern.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:profile_repository/profile_repository.dart';

const _divineRelayHint = 'wss://relay.divine.video';
const _mentionMarker = 'mention';
const _typedRemoteLookupLimit = 5;
const _profileSearchLimit = 10;

final _linkifiedTokenRegex = RegExp(
  r'((?:[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})|(?:https?:\/\/[^\s]+|www\.[^\s]+|(?<![@\w])(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(?:\/[^\s]*)?))|#(\w+)|(?<![A-Za-z0-9])(?:nostr:)?((?:npub|nprofile|note|nevent|naddr)1[a-z0-9]+)\b|(?<![A-Fa-f0-9])([A-Fa-f0-9]{64})(?![A-Fa-f0-9])|'
  '$mentionTokenPattern',
  caseSensitive: false,
);

@immutable
class MentionBinding {
  const MentionBinding({
    required this.display,
    required this.pubkey,
    this.start,
    this.end,
  });

  final String display;
  final String pubkey;
  final int? start;
  final int? end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MentionBinding &&
          runtimeType == other.runtimeType &&
          display == other.display &&
          pubkey == other.pubkey &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(display, pubkey, start, end);
}

class MentionResolutionResult {
  const MentionResolutionResult({
    required this.canonicalText,
    required this.resolvedPubkeys,
    required this.unresolvedTokens,
  });

  final String canonicalText;
  final List<String> resolvedPubkeys;
  final List<String> unresolvedTokens;
}

class MentionResolutionService {
  MentionResolutionService({
    required ProfileRepository profileRepository,
    Duration typedResolutionTimeout = const Duration(seconds: 2),
  }) : _profileRepository = profileRepository,
       _typedResolutionTimeout = typedResolutionTimeout;

  final ProfileRepository _profileRepository;
  final Duration _typedResolutionTimeout;

  Future<MentionResolutionResult> resolveTextMentions({
    required String rawText,
    List<MentionBinding> selectedMentions = const [],
    String? currentUserPubkey,
  }) async {
    final normalizedCurrentUser = currentUserPubkey == null
        ? null
        : normalizeToHex(currentUserPubkey);
    final selectedResult = _canonicalizeSelectedMentions(
      rawText,
      selectedMentions,
    );
    final typedMentions = _extractTypedMentions(selectedResult.text);
    if (typedMentions.isEmpty) {
      return MentionResolutionResult(
        canonicalText: selectedResult.text,
        resolvedPubkeys: selectedResult.pubkeys.toList(),
        unresolvedTokens: const [],
      );
    }

    final typedResult =
        await _resolveTypedMentions(
          typedMentions,
          currentUserPubkey: normalizedCurrentUser,
        ).timeout(
          _typedResolutionTimeout,
          onTimeout: () => _TypedResolutionResult.empty(typedMentions),
        );

    final replacements = <_TextReplacement>[];
    for (final mention in typedMentions) {
      final pubkey = typedResult.pubkeyByToken[mention.lookupKey];
      if (pubkey == null) continue;
      replacements.add(
        _TextReplacement(
          start: mention.start,
          end: mention.end,
          text: _canonicalReferenceForHex(pubkey),
        ),
      );
    }

    final resolvedPubkeys = <String>{
      ...selectedResult.pubkeys,
      ...typedResult.pubkeyByToken.values,
    };

    return MentionResolutionResult(
      canonicalText: _applyReplacements(selectedResult.text, replacements),
      resolvedPubkeys: resolvedPubkeys.toList(),
      unresolvedTokens: typedResult.unresolvedTokens,
    );
  }

  List<List<String>> buildGenericMentionPTags({
    required Iterable<String> pubkeys,
    Iterable<String> collaboratorPubkeys = const [],
  }) {
    final collaboratorHex = collaboratorPubkeys
        .map(normalizeToHex)
        .whereType<String>()
        .where(NostrKeyUtils.isValidKey)
        .toSet();
    final seen = <String>{};
    final tags = <List<String>>[];

    for (final pubkey in pubkeys) {
      final hex = normalizeToHex(pubkey);
      if (hex == null || !NostrKeyUtils.isValidKey(hex)) continue;
      if (collaboratorHex.contains(hex) || !seen.add(hex)) continue;
      tags.add(['p', hex, _divineRelayHint, _mentionMarker]);
    }

    return tags;
  }

  _SelectedMentionResult _canonicalizeSelectedMentions(
    String rawText,
    List<MentionBinding> selectedMentions,
  ) {
    var text = rawText;
    final pubkeys = <String>{};
    final replacementsByRange = <String, _TextReplacement>{};
    final pubkeyByRange = <String, String>{};
    final occupiedRanges = <_MentionTokenRange>[];

    // Later bindings represent newer user selections. Process newest first so
    // a re-selected token replaces stale bindings for the same visible range.
    for (final binding in selectedMentions.reversed) {
      final hex = normalizeToHex(binding.pubkey);
      if (hex == null || !NostrKeyUtils.isValidKey(hex)) continue;

      final range = _currentSelectedTokenRange(
        rawText,
        binding,
        occupiedRanges,
      );
      if (range == null) {
        continue;
      }

      final rangeKey = '${range.start}:${range.end}';
      replacementsByRange[rangeKey] = _TextReplacement(
        start: range.start,
        end: range.end,
        text: _canonicalReferenceForHex(hex),
      );
      pubkeyByRange[rangeKey] = hex;
      occupiedRanges.add(range);
    }

    text = _applyReplacements(text, replacementsByRange.values.toList());
    pubkeys.addAll(pubkeyByRange.values);

    return _SelectedMentionResult(text: text, pubkeys: pubkeys);
  }

  Future<_TypedResolutionResult> _resolveTypedMentions(
    List<_TypedMention> mentions, {
    required String? currentUserPubkey,
  }) async {
    // Deduplicate case-insensitively while preserving separators in the key.
    // Profiles may legitimately own both `og-ab` and `ogab`, so collapsing
    // both to the separator-stripped comparison form would tag the wrong one.
    final queryByToken = <String, String>{};
    for (final mention in mentions) {
      queryByToken.putIfAbsent(mention.lookupKey, () => mention.token);
    }

    final pubkeyByToken = <String, String>{};
    final unresolvedTokens = <String>[];
    var remoteLookups = 0;

    for (final MapEntry(key: token, value: query) in queryByToken.entries) {
      String? resolved;
      try {
        final localCandidates = await _profileRepository.searchUsersLocally(
          query: query,
          limit: _profileSearchLimit,
        );
        resolved = _exactSingleMatch(query, localCandidates);

        if (resolved == null && remoteLookups < _typedRemoteLookupLimit) {
          remoteLookups += 1;
          final apiCandidates = await _profileRepository.searchUsersFromApi(
            query: query,
            limit: _profileSearchLimit,
          );
          resolved = _exactSingleMatch(query, apiCandidates);
        }
      } on Exception {
        resolved = null;
      }

      if (resolved == currentUserPubkey) resolved = null;

      if (resolved == null) {
        unresolvedTokens.add(token);
      } else {
        pubkeyByToken[token] = resolved;
      }
    }

    return _TypedResolutionResult(
      pubkeyByToken: pubkeyByToken,
      unresolvedTokens: unresolvedTokens,
    );
  }

  String? _exactSingleMatch(String token, List<UserProfile> profiles) {
    final matches = <String>{};
    for (final profile in profiles) {
      final hex = normalizeToHex(profile.pubkey);
      if (hex == null || !NostrKeyUtils.isValidKey(hex)) continue;
      if (_profileMatchesToken(token, profile, hex)) {
        matches.add(hex);
      }
    }
    return matches.length == 1 ? matches.single : null;
  }

  bool _profileMatchesToken(String token, UserProfile profile, String hex) {
    final normalizedToken = _normalizeMentionValue(token);
    if (normalizedToken.isEmpty) return false;

    final values = <String?>[
      profile.name,
      profile.displayName,
      profile.divineUsername,
      profile.shortDisplayNip05,
      profile.displayNip05,
      profile.nip05,
      hex,
      NostrKeyUtils.encodePubKey(hex),
    ];

    return values
        .whereType<String>()
        .map(_normalizeMentionValue)
        .any((value) => value == normalizedToken);
  }
}

List<_TypedMention> _extractTypedMentions(String text) {
  final mentions = <_TypedMention>[];
  for (final match in _linkifiedTokenRegex.allMatches(text)) {
    final token = match.group(5);
    if (token == null) continue;
    mentions.add(
      _TypedMention(
        token: token,
        start: match.start,
        end: match.end,
        lookupKey: token.toLowerCase(),
        normalizedToken: _normalizeMentionValue(token),
      ),
    );
  }
  return mentions
      .where((mention) => mention.normalizedToken.isNotEmpty)
      .toList();
}

_MentionTokenRange? _currentSelectedTokenRange(
  String text,
  MentionBinding binding,
  List<_MentionTokenRange> occupiedRanges,
) {
  final start = binding.start;
  final end = binding.end;
  if (start != null &&
      end != null &&
      start >= 0 &&
      end <= text.length &&
      start < end &&
      _rangeMatchesSelectedToken(text, start, end, binding.display)) {
    final range = _MentionTokenRange(start: start, end: end);
    if (!_rangeOverlapsAny(range, occupiedRanges)) return range;
  }

  return _findSelectedTokenRange(
    text,
    binding.display,
    occupiedRanges: occupiedRanges,
  );
}

bool _rangeMatchesSelectedToken(
  String text,
  int start,
  int end,
  String display,
) {
  final selectedText = text.substring(start, end);
  final token = display.startsWith('@') ? display : '@$display';
  return selectedText == token || selectedText == display;
}

_MentionTokenRange? _findSelectedTokenRange(
  String text,
  String display, {
  required List<_MentionTokenRange> occupiedRanges,
}) {
  final token = display.startsWith('@') ? display : '@$display';
  var searchStart = 0;
  while (searchStart < text.length) {
    final index = text.indexOf(token, searchStart);
    if (index < 0) return null;

    final range = _MentionTokenRange(start: index, end: index + token.length);
    if (!_rangeOverlapsAny(range, occupiedRanges)) return range;
    searchStart = index + token.length;
  }

  return null;
}

bool _rangeOverlapsAny(
  _MentionTokenRange range,
  List<_MentionTokenRange> occupiedRanges,
) {
  return occupiedRanges.any(
    (occupied) => range.start < occupied.end && occupied.start < range.end,
  );
}

String _applyReplacements(String text, List<_TextReplacement> replacements) {
  if (replacements.isEmpty) return text;
  final sorted = [...replacements]..sort((a, b) => b.start.compareTo(a.start));
  var next = text;
  for (final replacement in sorted) {
    if (replacement.start < 0 ||
        replacement.end > next.length ||
        replacement.start >= replacement.end) {
      continue;
    }
    next = next.replaceRange(
      replacement.start,
      replacement.end,
      replacement.text,
    );
  }
  return next;
}

String _canonicalReferenceForHex(String pubkey) {
  return 'nostr:${NostrKeyUtils.encodePubKey(pubkey)}';
}

String _normalizeMentionValue(String value) {
  final trimmed = value.trim().toLowerCase();
  final withoutPrefix = trimmed.startsWith('@')
      ? trimmed.substring(1)
      : trimmed;
  return withoutPrefix.replaceAll(RegExp('[^a-z0-9]'), '');
}

class _SelectedMentionResult {
  const _SelectedMentionResult({required this.text, required this.pubkeys});

  final String text;
  final Set<String> pubkeys;
}

class _MentionTokenRange {
  const _MentionTokenRange({required this.start, required this.end});

  final int start;
  final int end;
}

class _TypedResolutionResult {
  const _TypedResolutionResult({
    required this.pubkeyByToken,
    required this.unresolvedTokens,
  });

  factory _TypedResolutionResult.empty(List<_TypedMention> mentions) {
    final unresolved = <String>[];
    for (final mention in mentions) {
      if (!unresolved.contains(mention.lookupKey)) {
        unresolved.add(mention.lookupKey);
      }
    }
    return _TypedResolutionResult(
      pubkeyByToken: const {},
      unresolvedTokens: unresolved,
    );
  }

  final Map<String, String> pubkeyByToken;
  final List<String> unresolvedTokens;
}

class _TypedMention {
  const _TypedMention({
    required this.token,
    required this.start,
    required this.end,
    required this.lookupKey,
    required this.normalizedToken,
  });

  final String token;
  final int start;
  final int end;
  final String lookupKey;
  final String normalizedToken;
}

class _TextReplacement {
  const _TextReplacement({
    required this.start,
    required this.end,
    required this.text,
  });

  final int start;
  final int end;
  final String text;
}
