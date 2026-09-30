// ABOUTME: Cubit for managing the app's display locale
// ABOUTME: Reads/writes via LocalePreferenceService, emits Locale? state

import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/services/locale_preference_service.dart';

part 'locale_state.dart';

/// Prepares the strings of the UI language for [locale], or of the device
/// language when [locale] is null, before the app switches to it.
typedef LocalePreloader = Future<void> Function(Locale? locale);

/// Manages the app's display locale.
///
/// Emits [LocaleState] with a [Locale] when the user has chosen a specific
/// language, or `null` when following the device default.
class LocaleCubit extends Cubit<LocaleState>
    with CloseGuardedEmit<LocaleState> {
  /// Creates a [LocaleCubit] backed by [localePreferenceService].
  ///
  /// [preloadLocale] runs before a new locale is emitted. On the web it
  /// downloads that language, so context-less code reading strings after the
  /// switch gets the new language rather than the English fallback.
  LocaleCubit({
    required LocalePreferenceService localePreferenceService,
    LocalePreloader? preloadLocale,
  }) : _service = localePreferenceService,
       _preloadLocale = preloadLocale ?? _noPreload,
       super(const LocaleState()) {
    _loadSavedLocale();
  }

  final LocalePreferenceService _service;
  final LocalePreloader _preloadLocale;

  static Future<void> _noPreload(Locale? locale) async {
    // Intentional no-op: without a preloader the locale is emitted straight
    // away, which is all a native build needs.
  }

  void _loadSavedLocale() {
    final saved = _service.getLocale();
    if (saved != null) {
      emit(LocaleState(locale: Locale(saved)));
    }
  }

  /// Sets the app locale to [localeCode] (e.g. `'es'`, `'tr'`).
  Future<void> setLocale(String localeCode) async {
    final locale = Locale(localeCode);
    await _service.setLocale(localeCode);
    await _preloadLocale(locale);
    emitIfOpen(LocaleState(locale: locale));
  }

  /// Clears the custom locale, reverting to device default.
  Future<void> clearLocale() async {
    await _service.clearLocale();
    await _preloadLocale(null);
    emitIfOpen(const LocaleState());
  }
}
