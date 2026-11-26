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
/// for changes, or could not be saved. A series it had already saved stays,
/// waiting to be published like any other list.
final class SeriesCreationFailed extends SeriesCreationResult {
  const SeriesCreationFailed();
}

extension _CuratedListCreation on CuratedListService {
  /// A series is an empty, public, manually ordered list carrying the series
  /// marker. It is published here, not by [_createList], so a relay rejection
  /// can remove it again.
  Future<SeriesCreationResult> _createSeries(String name) async {
    final created = await _createList(
      name: name,
      playOrder: PlayOrder.manual,
      preservedTags: const [_seriesMarker],
      publish: false,
    );
    if (created == null) return const SeriesCreationFailed();
    return _serializeListOperation(
      created.id,
      () => _publishSeries(created.id),
      cancelled: const SeriesCreationFailed(),
    );
  }

  Future<SeriesCreationResult> _publishSeries(String listId) async {
    final provisional = getListById(listId);
    if (provisional == null) return const SeriesCreationFailed();
    if (await _publishListToNostr(provisional, confirmed: true)) {
      return SeriesCreated(getListById(listId) ?? provisional);
    }
    final current = getListById(listId) ?? provisional;
    _lists.removeWhere((list) => list.authorScopedId == current.authorScopedId);
    if (await _saveLists()) return const SeriesCreationRejected();
    _restoreList(current);
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
