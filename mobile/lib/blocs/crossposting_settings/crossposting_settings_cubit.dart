// ABOUTME: Orchestrates repository-backed crossposting settings actions
// ABOUTME: Serializes operations and validates native OAuth callbacks

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/features/oauth/app_oauth_callback.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/repositories/crossposting_repository.dart';
import 'package:openvine/services/crossposting_api_client.dart';

part 'crossposting_settings_state.dart';

/// Opens an OAuth authorization URL and returns its HTTPS callback.
///
/// A `null` callback means the user closed or cancelled the browser session.
typedef CrosspostingOAuthLauncher = Future<Uri?> Function(Uri authorizationUrl);

/// Creates an unguessable value that correlates a browser callback to one
/// in-flight connect attempt.
typedef CrosspostingNonceGenerator = String Function();

String generateCrosspostingOAuthNonce() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

class CrosspostingSettingsCubit extends Cubit<CrosspostingSettingsState>
    with CloseGuardedEmit<CrosspostingSettingsState> {
  CrosspostingSettingsCubit({
    required CrosspostingRepository repository,
    required CrosspostingOAuthLauncher launchOAuth,
    CrosspostingNonceGenerator nonceGenerator = generateCrosspostingOAuthNonce,
    Duration oauthCallbackTimeout = const Duration(minutes: 3),
  }) : _repository = repository,
       _launchOAuth = launchOAuth,
       _nonceGenerator = nonceGenerator,
       _oauthCallbackTimeout = oauthCallbackTimeout,
       super(CrosspostingSettingsState());

  static final Uri callbackBaseUrl = Uri(
    scheme: appOAuthCallbackScheme,
    host: appOAuthCallbackHost,
    path: appOAuthCallbackPath,
  );

  final CrosspostingRepository _repository;
  final CrosspostingOAuthLauncher _launchOAuth;
  final CrosspostingNonceGenerator _nonceGenerator;

  /// Bound on the wait for an OAuth browser session's callback.
  ///
  /// On Android devices where app-link verification fails (a signing cert
  /// missing from assetlinks.json, OEM verification disabled), the callback
  /// URL opens in the browser and the session never completes. The timeout
  /// turns that silent hang into an explicit error. Three minutes is
  /// generous for a real consent round trip, including account creation.
  final Duration _oauthCallbackTimeout;

  /// Loads settings unless another load, refresh, or mutation already owns the
  /// operation gate.
  Future<void> load() {
    if (!_tryAcquireOperation()) return Future<void>.value();
    return _load(showLoading: true);
  }

  /// Refreshes settings unless another load, refresh, or mutation is running.
  Future<void> refresh() {
    if (!_tryAcquireOperation()) return Future<void>.value();
    return _load(
      showLoading: state.status != CrosspostingSettingsStatus.loaded,
    );
  }

  Future<void> _load({required bool showLoading}) async {
    try {
      if (showLoading &&
          !emitIfOpen(
            state.copyWith(
              status: CrosspostingSettingsStatus.loading,
              clearError: true,
              clearOutcome: true,
            ),
          )) {
        return;
      }
      if (!showLoading &&
          !emitIfOpen(
            state.copyWith(
              pendingAction: CrosspostingPlatformAction.refreshing,
              clearError: true,
              clearOutcome: true,
            ),
          )) {
        return;
      }

      final entries = await _repository.loadSettings();
      if (isClosed) return;
      emitIfOpen(
        state.copyWith(
          status: CrosspostingSettingsStatus.loaded,
          entries: entries,
          clearError: true,
          clearPending: true,
        ),
      );
    } catch (error, stackTrace) {
      _reportError(
        error,
        stackTrace,
        status: showLoading ? CrosspostingSettingsStatus.failure : null,
      );
    }
  }

  Future<void> connect(CrosspostingPlatform platform) {
    if (!_tryAcquireOperation()) return Future<void>.value();
    return _connect(platform);
  }

  Future<void> _connect(CrosspostingPlatform platform) async {
    _beginAction(CrosspostingPlatformAction.connecting, platform);
    try {
      final nonce = _nonceGenerator();
      if (nonce.isEmpty) {
        throw Reportable(
          StateError('Crossposting OAuth nonce must not be empty'),
          context: '_connect',
        );
      }
      final returnUrl = callbackBaseUrl.replace(
        queryParameters: {'app_state': nonce},
      );
      final start = await _repository.startConnection(
        platform,
        returnUrl: returnUrl,
      );
      if (isClosed) return;

      Uri? callback;
      try {
        callback = await _launchOAuth(
          start.authorizationUrl,
        ).timeout(_oauthCallbackTimeout);
      } on TimeoutException {
        // The browser session produced no callback: on Android without
        // verified app links the redirect dies in the browser and the
        // session hangs. The connection may still have completed
        // server-side, so refresh before telling the user we stopped
        // listening.
        final entries = await _repository.loadSettings();
        if (isClosed) return;
        _emitActionError(
          CrosspostingSettingsError.callbackTimeout,
          entries: entries,
        );
        return;
      }
      if (isClosed) return;

      CrosspostingOAuthOutcome? outcome;
      Object? callbackError;
      if (callback != null) {
        try {
          outcome = _parseCallback(
            callback,
            expectedPlatform: platform,
            expectedNonce: nonce,
          );
        } catch (error, stackTrace) {
          callbackError = error;
          if (isClosed) return;
          addError(error, stackTrace);
        }
      }

      final entries = await _repository.loadSettings();
      if (isClosed) return;
      if (callbackError != null) {
        _emitActionError(CrosspostingSettingsError.generic, entries: entries);
        return;
      }

      if (callback == null) {
        emitIfOpen(
          state.copyWith(
            entries: entries,
            clearPending: true,
            clearError: true,
            clearOutcome: true,
          ),
        );
        return;
      }

      emitIfOpen(
        state.copyWith(
          entries: entries,
          outcome: outcome,
          outcomePlatform: platform,
          outcomeAttempt: state.outcomeAttempt + 1,
          clearPending: true,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  Future<void> disconnect(CrosspostingPlatform platform) {
    if (!_tryAcquireOperation()) return Future<void>.value();
    return _disconnect(platform);
  }

  Future<void> _disconnect(CrosspostingPlatform platform) async {
    try {
      final connection = _entryFor(platform)?.connection;
      if (connection == null) return;

      _beginAction(CrosspostingPlatformAction.disconnecting, platform);
      try {
        await _repository.disconnect(platform, connection.id);
      } on CrosspostingApiException catch (error, stackTrace) {
        if (error.kind != CrosspostingApiErrorKind.notConnected) rethrow;
        if (isClosed) return;
        addError(error, stackTrace);
      }
      if (isClosed) return;
      emitIfOpen(
        state.copyWith(
          entries: [
            for (final entry in state.entries)
              if (entry.platform == platform)
                CrosspostingPlatformSettings(
                  platform: entry.platform,
                  supportsAutomatic: entry.supportsAutomatic,
                  mode: CrosspostingMode.disabled,
                )
              else
                entry,
          ],
        ),
      );

      final entries = await _repository.loadSettings();
      if (isClosed) return;
      emitIfOpen(
        state.copyWith(entries: entries, clearPending: true, clearError: true),
      );
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  Future<void> setMode(CrosspostingPlatform platform, CrosspostingMode mode) {
    if (!_tryAcquireOperation()) return Future<void>.value();
    return _setMode(platform, mode);
  }

  Future<void> _setMode(
    CrosspostingPlatform platform,
    CrosspostingMode mode,
  ) async {
    if (_entryFor(platform) == null) return;

    final previousEntries = state.entries;
    _beginAction(
      CrosspostingPlatformAction.savingMode,
      platform,
      entries: [
        for (final entry in state.entries)
          if (entry.platform == platform) entry.copyWith(mode: mode) else entry,
      ],
    );

    try {
      await _repository.setMode(platform, mode);
      if (isClosed) return;
      emitIfOpen(state.copyWith(clearPending: true, clearError: true));
    } on CrosspostingApiException catch (error, stackTrace) {
      if (isClosed) return;
      addError(error, stackTrace);
      if (error.kind == CrosspostingApiErrorKind.notConnected) {
        try {
          final entries = await _repository.loadSettings();
          if (isClosed) return;
          _emitActionError(
            CrosspostingSettingsError.notConnected,
            entries: entries,
          );
        } catch (reloadError, reloadStackTrace) {
          if (isClosed) return;
          addError(reloadError, reloadStackTrace);
          _emitActionError(
            CrosspostingSettingsError.generic,
            entries: previousEntries,
          );
        }
        return;
      }
      _emitActionError(
        CrosspostingSettingsError.generic,
        entries: previousEntries,
      );
    } catch (error, stackTrace) {
      if (isClosed) return;
      addError(error, stackTrace);
      _emitActionError(
        CrosspostingSettingsError.generic,
        entries: previousEntries,
      );
    }
  }

  void acknowledgeError() {
    if (isClosed || state.error == null) return;
    emitIfOpen(state.copyWith(clearError: true));
  }

  void acknowledgeOutcome() {
    if (isClosed || state.outcome == null) return;
    emitIfOpen(state.copyWith(clearOutcome: true));
  }

  bool _tryAcquireOperation() {
    return !isClosed &&
        state.status != CrosspostingSettingsStatus.loading &&
        state.pendingAction == null;
  }

  void _beginAction(
    CrosspostingPlatformAction action,
    CrosspostingPlatform platform, {
    List<CrosspostingPlatformSettings>? entries,
  }) {
    if (isClosed) return;
    emitIfOpen(
      state.copyWith(
        entries: entries,
        pendingAction: action,
        pendingPlatform: platform,
        clearError: true,
        clearOutcome: true,
      ),
    );
  }

  void _reportError(
    Object error,
    StackTrace stackTrace, {
    CrosspostingSettingsStatus? status,
  }) {
    if (isClosed) return;
    addError(error, stackTrace);
    if (isClosed) return;
    emitIfOpen(
      state.copyWith(
        status: status,
        error: CrosspostingSettingsError.generic,
        errorAttempt: state.errorAttempt + 1,
        clearPending: true,
        clearOutcome: true,
      ),
    );
  }

  void _emitActionError(
    CrosspostingSettingsError error, {
    List<CrosspostingPlatformSettings>? entries,
  }) {
    if (isClosed) return;
    emitIfOpen(
      state.copyWith(
        entries: entries,
        error: error,
        errorAttempt: state.errorAttempt + 1,
        clearPending: true,
        clearOutcome: true,
      ),
    );
  }

  CrosspostingPlatformSettings? _entryFor(CrosspostingPlatform platform) {
    for (final entry in state.entries) {
      if (entry.platform == platform) return entry;
    }
    return null;
  }

  CrosspostingOAuthOutcome _parseCallback(
    Uri callback, {
    required CrosspostingPlatform expectedPlatform,
    required String expectedNonce,
  }) {
    if (callback.scheme != callbackBaseUrl.scheme ||
        callback.host != callbackBaseUrl.host ||
        callback.path != callbackBaseUrl.path ||
        callback.hasPort ||
        callback.userInfo.isNotEmpty) {
      throw const FormatException('Unexpected crossposting callback URL');
    }

    final platformValues = callback.queryParametersAll['platform'];
    final connectionValues = callback.queryParametersAll['connection'];
    final reasonValues = callback.queryParametersAll['reason'];
    final nonceValues = callback.queryParametersAll['app_state'];
    if (platformValues?.length != 1 ||
        connectionValues?.length != 1 ||
        nonceValues?.length != 1 ||
        nonceValues!.single != expectedNonce ||
        (reasonValues != null && reasonValues.length != 1)) {
      throw const FormatException('Invalid crossposting callback parameters');
    }

    final platform = CrosspostingPlatform.fromWireName(platformValues!.single);
    if (platform == null || platform != expectedPlatform) {
      throw const FormatException('Unexpected crossposting callback platform');
    }

    switch (connectionValues!.single) {
      case 'connected':
        return CrosspostingOAuthOutcome.connected;
      case 'failed':
        return reasonValues?.single == 'provider_denied'
            ? CrosspostingOAuthOutcome.denied
            : CrosspostingOAuthOutcome.failed;
      default:
        throw const FormatException('Unexpected crossposting callback result');
    }
  }
}
