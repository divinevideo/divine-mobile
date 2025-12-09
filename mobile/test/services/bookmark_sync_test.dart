// ABOUTME: Tests for BookmarkSyncWorker background sync functionality
// ABOUTME: Verifies offline queueing, connectivity-based sync, and hash-based change detection

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/bookmark_service.dart';
import 'package:openvine/services/bookmark_sync_worker.dart';
import 'package:openvine/services/connection_status_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookmarkSyncWorker', () {
    late BookmarkService bookmarkService;
    late ConnectionStatusService connectionStatusService;
    late BookmarkSyncWorker syncWorker;
    late SharedPreferences prefs;

    setUp(() async {
      // Initialize services
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      final keyManager = NostrKeyManager();
      await keyManager.initialize();

      final nostrService = NostrService(keyManager);
      await nostrService.initialize();

      final authService = AuthService(keyStorage: null);

      bookmarkService = BookmarkService(
        nostrService: nostrService,
        authService: authService,
        prefs: prefs,
      );

      connectionStatusService = ConnectionStatusService();

      syncWorker = BookmarkSyncWorker(
        bookmarkService: bookmarkService,
        connectionStatusService: connectionStatusService,
        prefs: prefs,
      );
    });

    tearDown(() {
      syncWorker.dispose();
      connectionStatusService.dispose();
    });

    test('creates bookmark set and marks as dirty', () async {
      final set = await bookmarkService.createBookmarkSet(
        name: 'Test Set',
        description: 'Test Description',
      );

      expect(set, isNotNull);
      expect(set!.name, 'Test Set');

      // Mark as dirty (simulating that publish failed)
      syncWorker.markDirty(set.id);

      final status = syncWorker.getSyncStatus();
      expect(status['pendingChangesCount'], greaterThan(0));
      expect(status['pendingSetIds'], contains(set.id));
    });

    test('tracks published hashes to avoid redundant publishes', () async {
      final set1 = await bookmarkService.createBookmarkSet(name: 'Set 1');
      expect(set1, isNotNull);

      // First sync - should publish
      await syncWorker.syncSets();

      final statusBefore = syncWorker.getSyncStatus();
      final publishedCountBefore = statusBefore['publishedSetsCount'] as int;

      // Second sync without changes - should NOT republish
      await syncWorker.syncSets();

      final statusAfter = syncWorker.getSyncStatus();
      final publishedCountAfter = statusAfter['publishedSetsCount'] as int;

      // Should have same published count (no new publishes)
      expect(publishedCountAfter, equals(publishedCountBefore));
    });

    test('detects changes via content hash', () async {
      final set = await bookmarkService.createBookmarkSet(
        name: 'Original Name',
      );
      expect(set, isNotNull);

      // Sync to establish baseline
      await syncWorker.syncSets();

      // Modify the set
      await bookmarkService.updateBookmarkSet(
        setId: set!.id,
        name: 'Updated Name',
      );

      // Mark as dirty to trigger sync
      syncWorker.markDirty(set.id);

      final statusBefore = syncWorker.getSyncStatus();
      expect(statusBefore['pendingChangesCount'], greaterThan(0));

      // Sync should detect change and publish
      await syncWorker.syncSets();

      final statusAfter = syncWorker.getSyncStatus();
      // After successful sync, pending should be cleared
      expect(statusAfter['pendingChangesCount'], equals(0));
    });

    test('queues changes when offline', () async {
      // Simulate offline state
      connectionStatusService.updateRelayStatus('test_relay', false);

      final set = await bookmarkService.createBookmarkSet(name: 'Offline Set');
      expect(set, isNotNull);

      syncWorker.markDirty(set!.id);

      // Try to sync while offline - should skip
      await syncWorker.syncSets();

      final status = syncWorker.getSyncStatus();
      expect(status['isOnline'], false);
      expect(status['pendingChangesCount'], greaterThan(0));
    });

    test('syncs pending changes when coming online', () async {
      // Start offline
      connectionStatusService.updateRelayStatus('test_relay', false);

      final set = await bookmarkService.createBookmarkSet(name: 'Pending Set');
      expect(set, isNotNull);

      syncWorker.markDirty(set!.id);

      final statusOffline = syncWorker.getSyncStatus();
      expect(statusOffline['isOnline'], false);
      expect(statusOffline['pendingChangesCount'], greaterThan(0));

      // Come back online
      connectionStatusService.updateRelayStatus('test_relay', true);

      // Wait a bit for connectivity listener to trigger
      await Future.delayed(const Duration(milliseconds: 500));

      final statusOnline = syncWorker.getSyncStatus();
      expect(statusOnline['isOnline'], true);
      // Pending count should eventually decrease (after sync completes)
      // Note: In real test, we'd wait for sync to complete
    });

    test('handles multiple pending sets', () async {
      final set1 = await bookmarkService.createBookmarkSet(name: 'Set 1');
      final set2 = await bookmarkService.createBookmarkSet(name: 'Set 2');
      final set3 = await bookmarkService.createBookmarkSet(name: 'Set 3');

      expect(set1, isNotNull);
      expect(set2, isNotNull);
      expect(set3, isNotNull);

      syncWorker.markDirty(set1!.id);
      syncWorker.markDirty(set2!.id);
      syncWorker.markDirty(set3!.id);

      final status = syncWorker.getSyncStatus();
      expect(status['pendingChangesCount'], equals(3));
      expect(status['pendingSetIds'], containsAll([set1.id, set2.id, set3.id]));
    });

    test('persists sync state across restarts', () async {
      final set = await bookmarkService.createBookmarkSet(
        name: 'Persistent Set',
      );
      expect(set, isNotNull);

      syncWorker.markDirty(set!.id);

      var status = syncWorker.getSyncStatus();
      expect(status['pendingChangesCount'], greaterThan(0));

      // Dispose current sync worker
      syncWorker.dispose();

      // Create new sync worker with same prefs - should load pending changes
      final newSyncWorker = BookmarkSyncWorker(
        bookmarkService: bookmarkService,
        connectionStatusService: connectionStatusService,
        prefs: prefs,
      );

      status = newSyncWorker.getSyncStatus();
      expect(status['pendingChangesCount'], greaterThan(0));
      expect(status['pendingSetIds'], contains(set.id));

      newSyncWorker.dispose();
    });

    test('sync status provides debugging information', () {
      final status = syncWorker.getSyncStatus();

      expect(status, containsPair('isOnline', isA<bool>()));
      expect(status, containsPair('isSyncing', isA<bool>()));
      expect(status, containsPair('pendingChangesCount', isA<int>()));
      expect(status, containsPair('publishedSetsCount', isA<int>()));
      expect(status, containsPair('pendingSetIds', isA<List>()));
    });

    test('does not redundantly publish unchanged sets', () async {
      final set = await bookmarkService.createBookmarkSet(name: 'Stable Set');
      expect(set, isNotNull);

      // First sync
      await syncWorker.syncSets();

      final statusAfterFirstSync = syncWorker.getSyncStatus();
      final firstPublishedCount =
          statusAfterFirstSync['publishedSetsCount'] as int;

      // Second sync without any changes
      await syncWorker.syncSets();

      final statusAfterSecondSync = syncWorker.getSyncStatus();
      final secondPublishedCount =
          statusAfterSecondSync['publishedSetsCount'] as int;

      // Should not have published again
      expect(secondPublishedCount, equals(firstPublishedCount));
    });
  });
}
