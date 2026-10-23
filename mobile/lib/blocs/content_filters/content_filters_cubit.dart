// ABOUTME: Screen-scoped Cubit for the content filters screen.
// ABOUTME: Loads per-category filter preferences and the age-verification gate,
// ABOUTME: and persists per-label preference changes via ContentFilterService.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/content_filters/content_filters_state.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/content_filter_service.dart';

/// Cubit backing `ContentFiltersScreen`.
///
/// Initializes the filter + age-verification services, snapshots every
/// [ContentLabel]'s preference into state, and writes preference changes back
/// through [ContentFilterService] (which itself enforces the adult-category age
/// gate, so the persisted value is re-read after each write).
class ContentFiltersCubit extends Cubit<ContentFiltersState>
    with CloseGuardedEmit<ContentFiltersState> {
  ContentFiltersCubit({
    required ContentFilterService contentFilterService,
    required AgeVerificationService ageVerificationService,
  }) : _contentFilterService = contentFilterService,
       _ageVerificationService = ageVerificationService,
       super(const ContentFiltersState()) {
    _contentFilterService.addListener(_refresh);
  }

  void _refresh() => emitIfOpen(
    state.copyWith(
      preferences: {
        for (final label in ContentLabel.values)
          label: _contentFilterService.getPreference(label),
      },
    ),
  );

  @override
  Future<void> close() {
    _contentFilterService.removeListener(_refresh);
    return super.close();
  }

  final ContentFilterService _contentFilterService;
  final AgeVerificationService _ageVerificationService;

  Future<void> load() async {
    emitIfOpen(state.copyWith(status: ContentFiltersStatus.loading));
    await _contentFilterService.initialize();
    await _ageVerificationService.initialize();
    emitIfOpen(
      state.copyWith(
        status: ContentFiltersStatus.ready,
        isAgeVerified: _ageVerificationService.isAdultContentVerified,
        preferences: {
          for (final label in ContentLabel.values)
            label: _contentFilterService.getPreference(label),
        },
      ),
    );
  }

  /// Persists [preference] for [label], then re-reads the stored value (the
  /// service may reject adult-category changes via the age gate) and emits it.
  Future<void> setPreference(
    ContentLabel label,
    ContentFilterPreference preference,
  ) async {
    await _contentFilterService.setPreference(label, preference);
    emitIfOpen(
      state.copyWith(
        preferences: {
          ...state.preferences,
          label: _contentFilterService.getPreference(label),
        },
      ),
    );
  }
}
