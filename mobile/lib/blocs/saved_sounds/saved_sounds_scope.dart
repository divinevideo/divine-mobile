// ABOUTME: Provides one saved sounds BLoC for the current account across all routes.
// ABOUTME: Replaces the account BLoC without remounting the app and its router.

import 'dart:async';

import 'package:creator_sync/creator_sync.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/saved_sounds/saved_sound_media_probe.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_bloc.dart';
import 'package:openvine/services/saved_sounds_service.dart';

class SavedSoundsScope extends StatefulWidget {
  const SavedSoundsScope({
    required this.service,
    required this.child,
    this.mediaProbe,
    this.syncRepositoryStream = const Stream.empty(),
    this.localFileExists,
    this.contentDeletionService,
    this.onPublishedSoundDeleted,
    super.key,
  });

  final SavedSoundsService service;
  final SavedSoundMediaProbe? mediaProbe;
  final FutureOr<bool> Function(String path)? localFileExists;

  /// Resolves the NIP-09 publisher for deleting the user's own sounds; null
  /// leaves deletion unavailable (tests that don't exercise it).
  final ContentDeletionServiceGetter? contentDeletionService;

  /// Called after a relay took a sound's deletion.
  final void Function(String soundId)? onPublishedSoundDeleted;

  /// Successive sync repository instances, including null while
  /// unavailable.
  ///
  /// This scope sits above `MaterialApp.router`, so its `BlocProvider` is
  /// kept mounted when the account changes — re-keying it would re-inflate
  /// the whole app shell during sign-in (#7051) or every time
  /// `soundSyncAvailabilityProvider` resolves (#6477/#6480). The bloc instead
  /// subscribes to this stream and re-points its dependency in place.
  /// Defaults to an empty stream for callers that don't exercise sync.
  final Stream<SoundSyncRepository?> syncRepositoryStream;

  final Widget child;

  @override
  State<SavedSoundsScope> createState() => _SavedSoundsScopeState();
}

class _SavedSoundsScopeState extends State<SavedSoundsScope> {
  late SavedSoundsBloc _bloc;

  SavedSoundsBloc _createBloc() => SavedSoundsBloc(
    service: widget.service,
    mediaProbe: widget.mediaProbe ?? ProVideoEditorSavedSoundMediaProbe(),
    syncRepositoryStream: widget.syncRepositoryStream,
    localFileExists: widget.localFileExists,
    contentDeletionService: widget.contentDeletionService,
    onPublishedSoundDeleted: widget.onPublishedSoundDeleted,
  )..add(const SavedSoundsLoadRequested());

  @override
  void initState() {
    super.initState();
    _bloc = _createBloc();
  }

  @override
  void didUpdateWidget(SavedSoundsScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service.storageKey != widget.service.storageKey) {
      unawaited(_bloc.close());
      _bloc = _createBloc();
    }
  }

  @override
  void dispose() {
    unawaited(_bloc.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This state owns disposal; changing only the provided value lets
    // consumers subscribe to the new account without losing route state.
    return BlocProvider<SavedSoundsBloc>.value(
      value: _bloc,
      child: widget.child,
    );
  }
}
