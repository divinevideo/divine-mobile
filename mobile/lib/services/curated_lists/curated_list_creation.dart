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

/// The series could not be signed, or no relay accepted it. It was removed
/// from this device again.
final class SeriesCreationRejected extends SeriesCreationResult {
  const SeriesCreationRejected();
}

/// This device could not finish creating the series: its lists were not ready
/// for changes or could not be saved, the account changed, or a relay accepted
/// the series but this device could not record that. A series it had already
/// saved stays, and is published again like any other list.
final class SeriesCreationFailed extends SeriesCreationResult {
  const SeriesCreationFailed();
}

extension _CuratedListCreation on CuratedListService {
  /// A series is an empty, public, manually ordered list carrying the series
  /// marker. It is created and published in one operation on its own
  /// coordinate: no relay can hold that coordinate yet, so nothing is read
  /// first, and the background backfill cannot publish the series before
  /// this does.
  Future<SeriesCreationResult> _createSeries(String name) async {
    final owner = _relayGateway.currentAuthenticatedPubkey();
    if (owner == null) return const SeriesCreationFailed();
    final listId = _cacheIndex.nextLocalId(clock.now());
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
    final created = await _createList(
      id: listId,
      name: name,
      playOrder: PlayOrder.manual,
      preservedTags: const [_seriesMarker],
      publish: false,
    );
    if (created == null) return const SeriesCreationFailed();
    var relayAccepted = false;
    if (await _publishListToNostr(
      created,
      confirmed: true,
      onRelayAccepted: () => relayAccepted = true,
    )) {
      return SeriesCreated(getListById(created.authorScopedId) ?? created);
    }
    // A relay holds an accepted series, so it stays for the backfill to
    // record. After an account change its row is no longer this session's.
    if (relayAccepted || !_isCurrent(owner)) {
      return const SeriesCreationFailed();
    }
    final current = getListById(created.authorScopedId) ?? created;
    _lists.removeWhere((list) => list.authorScopedId == current.authorScopedId);
    if (await _saveLists()) return const SeriesCreationRejected();
    if (_isCurrent(owner) &&
        _prefs.getString(CuratedListService.listsStorageKey) != null &&
        getListById(current.authorScopedId) == null) {
      _restoreList(current);
    }
    return const SeriesCreationFailed();
  }

  /// With [publish] false the list is only saved on this device, and the
  /// caller publishes it.
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
    List<List<String>> preservedTags = const [],
    bool publish = true,
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
        preservedTags: preservedTags,
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

      if (publish && _authService.isAuthenticated) {
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
