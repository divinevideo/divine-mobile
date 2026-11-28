// ABOUTME: Creates owned curated lists and series. A list stays on the device
// ABOUTME: when no relay takes it; a series is kept only once one accepts it.

part of '../curated_list_service.dart';

/// The tag that marks a curated list as a series (#8105).
const _seriesMarker = ['series', 'true'];

/// What [CuratedListService.createSeries] did.
sealed class SeriesCreationResult {
  const SeriesCreationResult();
}

/// A relay accepted the new [series], and it is saved on this device.
final class SeriesCreated extends SeriesCreationResult {
  const SeriesCreated(this.series);

  final CuratedList series;
}

/// No account is signed in, so nothing was created.
final class SeriesCreationUnauthenticated extends SeriesCreationResult {
  const SeriesCreationUnauthenticated();
}

/// The series could not be signed, or no relay confirmed it. No local row
/// was created for the send.
final class SeriesCreationRejected extends SeriesCreationResult {
  const SeriesCreationRejected();
}

/// The cache was unavailable, the account changed, or a relay accepted the
/// series but this device could not save it. Relay sync can recover an
/// accepted series.
final class SeriesCreationFailed extends SeriesCreationResult {
  const SeriesCreationFailed();
}

extension _CuratedListCreation on CuratedListService {
  /// A series is an empty, public, manually ordered list carrying the series
  /// marker. Its random coordinate can be published without reading relays
  /// first or replacing a list created on another device at the same time.
  Future<SeriesCreationResult> _createSeries(String name) async {
    final owner = _relayGateway.currentAuthenticatedPubkey();
    if (owner == null) return const SeriesCreationFailed();
    final listId = const Uuid().v4();
    return _serializeListOperation(
      // The new series' authorScopedId, which its later operations queue on.
      '$owner:$listId',
      () => _createAndPublishSeries(name, owner: owner, listId: listId),
      cancelled: const SeriesCreationFailed(),
    );
  }

  Future<SeriesCreationResult> _createAndPublishSeries(
    String name, {
    required String owner,
    required String listId,
  }) async {
    if (!isReadyForMutations || !_isCurrent(owner)) {
      return const SeriesCreationFailed();
    }
    final now = clock.now();
    final series = CuratedList(
      id: listId,
      name: name,
      videoEventIds: const [],
      pubkey: owner,
      createdAt: now,
      updatedAt: now,
      playOrder: PlayOrder.manual,
      preservedTags: const [_seriesMarker],
    );
    if (!_relayEvidence.allows(series)) return const SeriesCreationFailed();

    final Event? event;
    try {
      event = await _relayGateway.signList(
        series,
        ownerPubkey: owner,
        createdAt: () => _publishClock.next(ownerPubkey: owner, listId: listId),
      );
      if (!isReadyForMutations ||
          !_isCurrent(owner) ||
          !_relayEvidence.allows(series)) {
        return const SeriesCreationFailed();
      }
      if (event == null) return const SeriesCreationRejected();
      final outcome = await _nostrService.publishEventAwaitOk(event);
      if (!_isCurrent(owner)) return const SeriesCreationFailed();
      if (!outcome.acceptedByAny) return const SeriesCreationRejected();
    } on Object catch (error) {
      Log.warning(
        'Series publication failed (${error.runtimeType})',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return _isCurrent(owner)
          ? const SeriesCreationRejected()
          : const SeriesCreationFailed();
    }

    if (!isReadyForMutations || !_isCurrent(owner)) {
      return const SeriesCreationFailed();
    }
    // Only confirmed rows enter the cache. Relay sync may already have
    // observed this event, so preserve any version it has merged.
    if (getListById(series.authorScopedId) == null) {
      final signedAt = event.createdAtDateTime;
      _lists.add(
        series.copyWith(
          nostrEventId: event.id,
          updatedAt: signedAt.isAfter(now) ? signedAt : now,
        ),
      );
    }
    if (!await _saveLists() || !_isCurrent(owner)) {
      return const SeriesCreationFailed();
    }
    final saved = getListById(series.authorScopedId);
    if (saved == null || !saved.isSeries || saved.nostrEventId == null) {
      return const SeriesCreationFailed();
    }
    return SeriesCreated(saved);
  }

  Future<CuratedList?> _createList({
    required String name,
    bool duringInitialization = false,
    String? id,
    String? description,
    String? imageUrl,
    bool isPublic = true,
    List<String> tags = const [],
    bool isCollaborative = false,
    List<String> allowedCollaborators = const [],
    String? thumbnailEventId,
    PlayOrder playOrder = PlayOrder.chronological,
  }) async {
    try {
      if (!hasValidCuratedListVisibility(isPublic, isCollaborative)) {
        Log.warning(
          'Cannot create a private collaborative list - private items are '
          'encrypted to the owner only',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return null;
      }

      if (!isCurrentSession || recoveryNeedsRepair) return null;
      final now = clock.now();
      final listId = id ?? _cacheIndex.nextLocalId(now);
      final ownerPubkey = _relayGateway.currentAuthenticatedPubkey();

      final newList = CuratedList(
        id: listId,
        name: name,
        description: description,
        imageUrl: imageUrl,
        videoEventIds: const [],
        pubkey: ownerPubkey,
        createdAt: now,
        updatedAt: now,
        isPublic: isPublic,
        tags: tags,
        isCollaborative: isCollaborative,
        allowedCollaborators: allowedCollaborators,
        thumbnailEventId: thumbnailEventId,
        playOrder: playOrder,
      );

      if (!_defaultAuthority.authorizeCreation(newList)) return null;
      if (ownerPubkey != null) {
        if (_cacheStore.wasListDeleted(ownerPubkey, listId) &&
            !await _recovery.retirePermissions(ownerPubkey, listId)) {
          return null;
        }
        await _cacheStore.forgetListDeletion(ownerPubkey, listId);
      }

      _lists.add(newList);
      if (!await _saveLists()) {
        _lists.remove(newList);
        notifyListeners();
        if (duringInitialization) {
          throw const CuratedCacheWriteException(
            CuratedCacheWriteStatus.storageRejected,
          );
        }
        return null;
      }

      if (_authService.isAuthenticated) {
        if (duringInitialization) {
          await _publishListToNostr(
            newList,
            confirmed: true,
            duringInitialization: true,
          );
        } else {
          await _serializeListOperation(listId, () async {
            final current = getListById(listId);
            if (current == null || current.nostrEventId != null) return;
            await _publishListToNostr(current, confirmed: true);
          });
        }
      }

      Log.info(
        'Created new curated list: $name ($listId)',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      return isCurrentSession ? getListById(listId) ?? newList : null;
    } catch (e) {
      Log.error(
        'Failed to create curated list: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      if (duringInitialization) rethrow;
      return null;
    }
  }
}
