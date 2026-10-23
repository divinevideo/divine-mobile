// ABOUTME: Screen-scoped Cubit for profile monetization links settings.
// ABOUTME: Owns validation, hidden-link preservation, save lifecycle, and analytics.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/monetization_links_settings/monetization_links_settings_state.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

typedef MonetizationAnalyticsSink = void Function(MonetizationLink link);

typedef MonetizationProfileSaved = FutureOr<void> Function(UserProfile profile);

class MonetizationLinksSettingsCubit
    extends Cubit<MonetizationLinksSettingsState> {
  MonetizationLinksSettingsCubit({
    required ProfileRepository? repository,
    required String? pubkey,
    required List<MonetizationLinkProvider> visibleProviders,
    required MonetizationAnalyticsSink trackConfiguredLink,
    required MonetizationProfileSaved onProfileSaved,
  }) : _pubkey = pubkey,
       _repository = repository,
       _trackConfiguredLink = trackConfiguredLink,
       _onProfileSaved = onProfileSaved,
       super(
         MonetizationLinksSettingsState(
           currentProfile: null,
           visibleProviders: visibleProviders,
         ),
       );

  final String? _pubkey;
  final ProfileRepository? _repository;
  final MonetizationAnalyticsSink _trackConfiguredLink;
  final MonetizationProfileSaved _onProfileSaved;

  /// Only a strict raw Kind 0 read can seed this replacement metadata editor.
  /// Cached REST projections may omit both visible and hidden support links.
  Future<void> load() async {
    if (isClosed || state.isLoading || state.isReady) return;
    final repository = _repository;
    final pubkey = _pubkey;
    if (repository == null || pubkey == null) return;
    emit(
      state.copyWith(loadStatus: MonetizationLinksSettingsLoadStatus.loading),
    );
    try {
      final profile = await repository.fetchFreshProfile(
        pubkey: pubkey,
        requireRawKind0: true,
      );
      if (isClosed) return;
      if (profile == null || profile.pubkey != pubkey) {
        emit(
          state.copyWith(
            loadStatus: MonetizationLinksSettingsLoadStatus.failure,
          ),
        );
        return;
      }
      emit(
        _stateFromProfile(
          currentProfile: profile,
          visibleProviders: state.visibleProviders,
        ),
      );
    } catch (error, stackTrace) {
      if (isClosed) return;
      addError(error, stackTrace);
      emit(
        state.copyWith(
          loadStatus: MonetizationLinksSettingsLoadStatus.failure,
        ),
      );
    }
  }

  void setEnabled(MonetizationLinkProvider provider, bool value) {
    if (isClosed || !state.canEdit) return;
    emit(
      state.copyWith(
        enabled: {...state.enabled, provider: value},
        errors: _withoutProvider(state.errors, provider),
        status: MonetizationLinksSettingsSaveStatus.idle,
        clearFailure: true,
        clearSavedProfile: true,
      ),
    );
  }

  void setValue(MonetizationLinkProvider provider, String value) {
    if (isClosed || !state.canEdit) return;
    emit(
      state.copyWith(
        values: {...state.values, provider: value},
        errors: _withoutProvider(state.errors, provider),
        status: MonetizationLinksSettingsSaveStatus.idle,
        clearFailure: true,
        clearSavedProfile: true,
      ),
    );
  }

  Future<void> save() async {
    final currentProfile = state.currentProfile;
    final repository = _repository;
    if (isClosed ||
        !state.canSave ||
        currentProfile == null ||
        repository == null) {
      return;
    }

    final visibleProviderSet = state.visibleProviders.toSet();
    final visibleLinks = <MonetizationLink>[];
    final errors =
        <MonetizationLinkProvider, MonetizationLinkInputInvalidReason>{};

    for (final provider in state.visibleProviders) {
      final input = state.valueFor(provider);
      if (!state.isEnabled(provider)) continue;
      final result = normalizeMonetizationLinkInput(
        provider: provider,
        input: input,
        enabled: true,
      );
      switch (result) {
        case MonetizationLinkInputValid(:final link):
          visibleLinks.add(link);
        case MonetizationLinkInputInvalid(:final reason):
          errors[provider] = reason;
      }
    }

    if (errors.isNotEmpty) {
      emit(
        state.copyWith(
          errors: errors,
          status: MonetizationLinksSettingsSaveStatus.idle,
          clearFailure: true,
          clearSavedProfile: true,
        ),
      );
      return;
    }

    final links = [
      ...currentProfile.monetizationLinks.where(
        (link) => !visibleProviderSet.contains(link.provider),
      ),
      ...visibleLinks,
    ];

    emit(
      state.copyWith(
        status: MonetizationLinksSettingsSaveStatus.saving,
        errors: const {},
        clearFailure: true,
        clearSavedProfile: true,
      ),
    );

    try {
      Log.info(
        'Saving monetization links: count=${links.length}',
        name: 'MonetizationLinksSettingsCubit',
        category: LogCategory.system,
      );
      final saved = await repository.saveProfileEvent(
        displayName: currentProfile.displayName ?? currentProfile.name ?? '',
        about: currentProfile.about,
        website: currentProfile.website,
        picture: currentProfile.picture,
        banner: currentProfile.banner,
        currentProfile: currentProfile,
        monetizationLinks: links,
      );
      if (isClosed) return;
      await _onProfileSaved(saved);
      if (isClosed) return;
      Log.info(
        'Saved monetization links: count=${saved.enabledMonetizationLinks.length}',
        name: 'MonetizationLinksSettingsCubit',
        category: LogCategory.system,
      );
      visibleLinks.forEach(_trackConfiguredLink);
      emit(
        _stateFromProfile(
          currentProfile: saved,
          visibleProviders: state.visibleProviders,
        ).copyWith(
          status: MonetizationLinksSettingsSaveStatus.success,
          savedProfile: saved,
          savedVisibleLinks: visibleLinks,
          clearFailure: true,
        ),
      );
    } on NoRelaysConnectedException catch (error, stackTrace) {
      _emitFailure(
        error,
        stackTrace,
        MonetizationLinksSettingsSaveFailure.noRelays,
      );
    } on ProfilePublishFailedException catch (error, stackTrace) {
      _emitFailure(
        error,
        stackTrace,
        MonetizationLinksSettingsSaveFailure.publishFailed,
      );
    }
  }

  void _emitFailure(
    Object error,
    StackTrace stackTrace,
    MonetizationLinksSettingsSaveFailure failure,
  ) {
    if (isClosed) return;
    addError(error, stackTrace);
    emit(
      state.copyWith(
        status: MonetizationLinksSettingsSaveStatus.failure,
        failure: failure,
        clearSavedProfile: true,
      ),
    );
  }

  static MonetizationLinksSettingsState _stateFromProfile({
    required UserProfile? currentProfile,
    required List<MonetizationLinkProvider> visibleProviders,
  }) {
    final byProvider = {
      for (final link
          in currentProfile?.monetizationLinks ?? const <MonetizationLink>[])
        link.provider: link,
    };
    return MonetizationLinksSettingsState(
      currentProfile: currentProfile,
      visibleProviders: visibleProviders,
      loadStatus: MonetizationLinksSettingsLoadStatus.ready,
      values: {
        for (final provider in MonetizationLinkProvider.values)
          provider: byProvider[provider]?.url ?? '',
      },
      enabled: {
        for (final provider in MonetizationLinkProvider.values)
          provider: byProvider[provider]?.enabled ?? false,
      },
    );
  }

  static Map<MonetizationLinkProvider, MonetizationLinkInputInvalidReason>
  _withoutProvider(
    Map<MonetizationLinkProvider, MonetizationLinkInputInvalidReason> errors,
    MonetizationLinkProvider provider,
  ) {
    if (!errors.containsKey(provider)) return errors;
    return {...errors}..remove(provider);
  }
}
