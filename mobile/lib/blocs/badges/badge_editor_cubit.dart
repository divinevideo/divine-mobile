// ABOUTME: Cubit backing the create/edit badge form: field state, Blossom
// ABOUTME: artwork upload, and publishing the NIP-58 badge definition.

import 'dart:typed_data';

import 'package:badge_repository/badge_repository.dart';
import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';

part 'badge_editor_state.dart';

/// Drives the badge editor for both creating a new badge and editing one.
///
/// Editing keeps the definition's `d` identifier, which is what makes the
/// published event replace the existing badge instead of adding a second one.
class BadgeEditorCubit extends Cubit<BadgeEditorState>
    with CloseGuardedEmit<BadgeEditorState> {
  /// Creates the cubit.
  ///
  /// [coordinate] is null when creating a badge and set when editing one.
  BadgeEditorCubit({
    required BadgeRepository repository,
    required BlossomUploadService uploadService,
    required String? pubkey,
    BadgeCoordinate? coordinate,
  }) : _repository = repository,
       _uploadService = uploadService,
       _pubkey = pubkey,
       _coordinate = coordinate,
       super(BadgeEditorState(isEditing: coordinate != null));

  final BadgeRepository _repository;
  final BlossomUploadService _uploadService;
  final String? _pubkey;
  final BadgeCoordinate? _coordinate;

  /// Prefills the form when editing; otherwise opens an empty form.
  Future<void> load() async {
    final coordinate = _coordinate;
    if (coordinate == null) {
      emit(state.copyWith(status: BadgeEditorStatus.ready));
      return _loadTakenIdentifiers();
    }

    emit(state.copyWith(status: BadgeEditorStatus.loading));
    try {
      final detail = await _repository.loadBadgeDetail(coordinate);
      final definition = detail.definition;
      if (definition == null) {
        emitIfOpen(state.copyWith(status: BadgeEditorStatus.loadFailure));
        return;
      }
      emitIfOpen(
        state.copyWith(
          status: BadgeEditorStatus.ready,
          name: definition.name ?? '',
          identifier: definition.dTag,
          description: definition.description ?? '',
          imageUrl: definition.imageUrl ?? '',
          thumbnailUrl: definition.thumbnails.isEmpty
              ? ''
              : definition.thumbnails.first,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(status: BadgeEditorStatus.loadFailure));
    }
  }

  /// Loads the identifiers already in use, so a new badge cannot silently
  /// replace an existing one.
  ///
  /// A failure here is not fatal and deliberately does not surface: without
  /// the list the editor just cannot warn, and refusing to create a badge
  /// because a relay was unreachable would be the worse outcome.
  Future<void> _loadTakenIdentifiers() async {
    try {
      final takenIdentifiers = await _repository.loadCreatedIdentifiers();
      // Read state only now: the user may have typed while the lookup ran.
      emitIfOpen(state.copyWith(takenIdentifiers: takenIdentifiers));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  /// Updates the badge name, deriving the identifier alongside it.
  ///
  /// The identifier only tracks the name while creating a badge and while the
  /// user has not typed their own: an existing badge's identifier is part of
  /// its address and must not move.
  void nameChanged(String name) {
    final shouldDerive = !state.isEditing && !state.identifierEdited;
    emit(
      state.copyWith(
        name: name,
        identifier: shouldDerive
            ? deriveBadgeIdentifier(name)
            : state.identifier,
      ),
    );
  }

  /// Updates the identifier and stops deriving it from the name.
  void identifierChanged(String identifier) {
    emit(state.copyWith(identifier: identifier, identifierEdited: true));
  }

  /// Updates the description.
  void descriptionChanged(String description) {
    emit(state.copyWith(description: description));
  }

  /// Uploads badge artwork to Blossom and stages the resulting URL.
  Future<void> uploadArtwork({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    final pubkey = _pubkey;
    if (pubkey == null || pubkey.isEmpty) {
      emit(state.copyWith(artworkStatus: BadgeArtworkStatus.failure));
      return;
    }

    emit(state.copyWith(artworkStatus: BadgeArtworkStatus.uploading));
    BlossomUploadResult result;
    try {
      result = await _uploadService.uploadImageBytes(
        bytes: bytes,
        nostrPubkey: pubkey,
        filename: filename,
        mimeType: mimeType,
      );
    } catch (error, stackTrace) {
      // Classification: Network/IO — not reportable. Surfaced as a failure
      // status the editor renders inline.
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(artworkStatus: BadgeArtworkStatus.failure));
      return;
    }

    final url = result.url;
    if (!result.success || url == null || url.isEmpty) {
      emitIfOpen(state.copyWith(artworkStatus: BadgeArtworkStatus.failure));
      return;
    }

    emitIfOpen(
      state.copyWith(
        artworkStatus: BadgeArtworkStatus.idle,
        imageUrl: url,
        // A staged image replaces any web-authored custom thumbnail, which
        // would otherwise keep showing the old artwork in list views.
        thumbnailUrl: '',
      ),
    );
  }

  /// Drops the staged artwork.
  void artworkCleared() {
    emit(
      state.copyWith(
        imageUrl: '',
        thumbnailUrl: '',
        artworkStatus: BadgeArtworkStatus.idle,
      ),
    );
  }

  /// Publishes the badge definition.
  ///
  /// An incomplete form does not publish; it records the attempt so the view
  /// can point at what is still missing.
  Future<void> save() async {
    if (state.status == BadgeEditorStatus.saving) return;
    if (!state.isValid) {
      emit(state.copyWith(submitAttempted: true));
      return;
    }

    emit(state.copyWith(status: BadgeEditorStatus.saving));
    try {
      final definition = await _repository.saveDefinition(
        BadgeDefinitionDraft(
          identifier: state.identifier,
          name: state.name,
          description: state.description,
          imageUrl: state.imageUrl,
          thumbnailUrl: state.thumbnailUrl,
        ),
      );
      emitIfOpen(
        state.copyWith(
          status: BadgeEditorStatus.saved,
          savedCoordinate: BadgeCoordinate(
            pubkey: definition.event.pubkey,
            identifier: definition.dTag,
          ),
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(status: BadgeEditorStatus.saveFailure));
    }
  }
}
