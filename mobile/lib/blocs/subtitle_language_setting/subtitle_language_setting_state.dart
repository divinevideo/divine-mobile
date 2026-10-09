// ABOUTME: State for SubtitleLanguageSettingCubit — snapshot of the viewer's
// ABOUTME: subtitle translation target and the languages kept in the original.

import 'package:equatable/equatable.dart';

/// Load lifecycle of the subtitle-translation tiles.
enum SubtitleLanguageSettingStatus { loading, ready }

/// State for `SubtitleLanguageSettingCubit`.
class SubtitleLanguageSettingState extends Equatable {
  const SubtitleLanguageSettingState({
    this.status = SubtitleLanguageSettingStatus.loading,
    this.targetLanguage,
    this.keepOriginalLanguages = const [],
  });

  final SubtitleLanguageSettingStatus status;

  /// Language subtitles are translated into, or `null` to follow the app.
  final String? targetLanguage;

  /// Source languages shown untranslated, sorted by code.
  final List<String> keepOriginalLanguages;

  @override
  List<Object?> get props => [status, targetLanguage, keepOriginalLanguages];
}
