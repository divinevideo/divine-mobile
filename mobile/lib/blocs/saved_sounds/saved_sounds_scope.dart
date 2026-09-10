// ABOUTME: Provides one saved sounds BLoC for the current account across all routes.
// ABOUTME: Replaces and closes the BLoC whenever the account storage key changes.

import 'dart:async';

import 'package:creator_sync/creator_sync.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/saved_sounds/saved_sound_media_probe.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_bloc.dart';
import 'package:openvine/services/saved_sounds_service.dart';

class SavedSoundsScope extends StatelessWidget {
  const SavedSoundsScope({
    required this.service,
    required this.child,
    this.mediaProbe,
    this.syncRepositoryStream = const Stream.empty(),
    this.localFileExists,
    super.key,
  });

  final SavedSoundsService service;
  final SavedSoundMediaProbe? mediaProbe;
  final FutureOr<bool> Function(String path)? localFileExists;

  /// Successive sync repository instances, including null while
  /// unavailable.
  ///
  /// This scope sits above `MaterialApp.router`, so its `BlocProvider` is
  /// keyed only on the account's storage key — re-keying on the repository
  /// too would re-inflate the whole app shell every time
  /// `soundSyncAvailabilityProvider` resolves (#6477/#6480). The bloc instead
  /// subscribes to this stream and re-points its dependency in place.
  /// Defaults to an empty stream for callers that don't exercise sync.
  final Stream<SoundSyncRepository?> syncRepositoryStream;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SavedSoundsBloc>(
      key: ValueKey(service.storageKey),
      lazy: false,
      create: (_) => SavedSoundsBloc(
        service: service,
        mediaProbe: mediaProbe ?? ProVideoEditorSavedSoundMediaProbe(),
        syncRepositoryStream: syncRepositoryStream,
        localFileExists: localFileExists,
      )..add(const SavedSoundsLoadRequested()),
      child: child,
    );
  }
}
