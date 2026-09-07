Status: Historical

> Historical note
> This records an abandoned video-system migration and is not current implementation guidance. `VideoCacheService` has been removed; trust the current code and focused documentation under `mobile/docs/`.

# Migration and Rollback Guide

## Overview

This guide provides comprehensive instructions for migrating from the legacy dual-list video architecture to the new TDD-driven VideoManagerService, including rollback procedures and risk mitigation strategies.

## Migration Strategy

### Current Architecture (Legacy)
```
VideoEventService (Nostr events) ──┐
                                   ├─► VideoCacheService ─► UI Components
VideoCacheService (playback) ──────┘
```

**Problems with Legacy System:**
- Index mismatches between services
- Memory leaks (3GB+ usage)
- "VideoPlayerController was disposed" crashes
- Inconsistent state management
- No error recovery

### Target Architecture (New TDD System)
```
NostrVideoBridge ─► VideoManagerService ─► UI Components
                           │
                           └─► VideoPerformanceMonitor
```

**Benefits of New System:**
- Single source of truth
- Memory bounded (<500MB)
- Circuit breaker error recovery
- Comprehensive testing (24 tests passing)
- Performance monitoring

## Pre-Migration Checklist

### 1. Environment Preparation
```bash
# Ensure all tests pass
flutter test test/unit/services/video_manager_interface_test.dart
flutter test test/integration/video_system_behavior_test.dart
flutter test test/widget/video_feed_provider_test.dart

# Verify code analysis is clean
flutter analyze

# Backup current state
git tag pre-video-migration-$(date +%Y%m%d)
git push origin pre-video-migration-$(date +%Y%m%d)
```

### 2. Feature Flag Setup
```dart
// lib/utils/feature_flags.dart
class FeatureFlags {
  static const String newVideoManager = 'new_video_manager';
  
  static bool isEnabled(String flag) {
    // In production, read from remote config
    // For gradual rollout: start with false, gradually enable
    switch (flag) {
      case newVideoManager:
        return _getRemoteConfigBool(flag) ?? false;
      default:
        return false;
    }
  }
  
  static bool _getRemoteConfigBool(String key) {
    // Firebase Remote Config or similar
    return FirebaseRemoteConfig.instance.getBool(key);
  }
}
```

### 3. Compatibility Layer
```dart
// lib/providers/video_provider_bridge.dart
class VideoProviderBridge extends ChangeNotifier {
  final bool _useNewSystem;
  final IVideoManager? _newVideoManager;
  final VideoCacheService? _legacyCacheService;
  final VideoEventService? _legacyEventService;
  
  VideoProviderBridge({bool? useNewSystem})
      : _useNewSystem = useNewSystem ?? FeatureFlags.isEnabled('new_video_manager') {
    if (_useNewSystem) {
      _initializeNewSystem();
    } else {
      _initializeLegacySystem();
    }
  }
  
  // Unified interface that delegates to appropriate system
  List<VideoEvent> get videos {
    if (_useNewSystem) {
      return _newVideoManager?.videos ?? [];
    } else {
      return _legacyEventService?.videoEvents ?? [];
    }
  }
  
  VideoPlayerController? getController(String videoId) {
    if (_useNewSystem) {
      return _newVideoManager?.getController(videoId);
    } else {
      return _legacyCacheService?.getController(videoId);
    }
  }
}
```

## Phase 1: Parallel Implementation (Week 1)

### Goal: Deploy new system alongside legacy system

### 1. Deploy New System Components
```dart
// lib/main.dart - Add new providers alongside existing ones
Widget build(BuildContext context) {
  return MultiProvider(
    providers: [
      // Legacy providers (keep existing)
      ChangeNotifierProvider(create: (_) => VideoEventService(...)),
      ChangeNotifierProvider(create: (_) => VideoCacheService(...)),
      ChangeNotifierProvider(create: (_) => VideoFeedProvider(...)),
      
      // New system providers (add without removing legacy)
      ChangeNotifierProvider(create: (_) => VideoManagerService()),
      ChangeNotifierProxyProvider<VideoManagerService, VideoPerformanceMonitor>(
        create: (context) => VideoPerformanceMonitor(
          videoManager: context.read<VideoManagerService>(),
        ),
        update: (context, videoManager, monitor) => monitor,
      ),
      ChangeNotifierProvider(create: (_) => NostrVideoBridge(...)),
      
      // Bridge provider for gradual migration
      ChangeNotifierProvider(create: (_) => VideoProviderBridge()),
    ],
    child: MyApp(),
  );
}
```

### 2. A/B Testing Setup
```dart
// lib/services/ab_testing_service.dart
class ABTestingService {
  static const String videoSystemTest = 'video_system_v2';
  
  static bool shouldUseNewVideoSystem(String userId) {
    // Gradual rollout based on user ID hash
    final hash = userId.hashCode.abs();
    final bucket = hash % 100;
    
    // Week 1: 0% (testing only)
    // Week 2: 10%
    // Week 3: 25%
    // Week 4: 50%
    // Week 5: 100%
    final rolloutPercentage = _getCurrentRolloutPercentage();
    
    return bucket < rolloutPercentage;
  }
  
  static int _getCurrentRolloutPercentage() {
    // Read from remote config with fallback
    return FirebaseRemoteConfig.instance.getInt('video_system_rollout') ?? 0;
  }
}
```

### 3. Monitoring Setup
```dart
// lib/services/migration_monitor.dart
class MigrationMonitor {
  static void trackSystemUsage(bool isNewSystem, String operation, {
    bool? success,
    Duration? duration,
    String? errorMessage,
  }) {
    final systemName = isNewSystem ? 'new_video_system' : 'legacy_video_system';
    
    Analytics.track('video_system_operation', {
      'system': systemName,
      'operation': operation,
      'success': success,
      'duration_ms': duration?.inMilliseconds,
      'error': errorMessage,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  static void trackMigrationMetrics() {
    Timer.periodic(Duration(minutes: 5), (_) {
      final legacyMemory = _getLegacySystemMemory();
      final newMemory = _getNewSystemMemory();
      
      Analytics.track('migration_metrics', {
        'legacy_memory_mb': legacyMemory,
        'new_memory_mb': newMemory,
        'memory_improvement': legacyMemory - newMemory,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
  }
}
```

## Phase 2: Gradual Migration (Weeks 2-4)

### Week 2: 10% Rollout
```dart
// Update remote config
FirebaseRemoteConfig.instance.setDefaults({
  'video_system_rollout': 10, // 10% of users
  'new_video_manager': true,
});
```

### Week 3: 25% Rollout
```dart
// Monitor key metrics before increasing rollout
class MigrationHealthCheck {
  static bool isHealthyForRollout() {
    final metrics = _getLastHourMetrics();
    
    return metrics.crashRate < 0.01 &&        // <1% crash rate
           metrics.memoryUsage < 600 &&       // <600MB average
           metrics.loadFailureRate < 0.05 &&  // <5% load failures
           metrics.userEngagement > 0.95;     // >95% of baseline engagement
  }
  
  static void checkRolloutHealth() {
    if (!isHealthyForRollout()) {
      // Automatically halt rollout
      FirebaseRemoteConfig.instance.setDefaults({
        'video_system_rollout': 0, // Halt rollout
      });
      
      // Alert operations team
      _sendRolloutAlert('Rollout halted due to health check failure');
    }
  }
}
```

### Week 4: 50% Rollout
```dart
// Enhanced monitoring for higher traffic
class HighVolumeMonitoring {
  static void startIntensiveMonitoring() {
    // Increase monitoring frequency
    Timer.periodic(Duration(minutes: 1), (_) {
      _checkSystemHealth();
      _checkMemoryUsage();
      _checkErrorRates();
    });
  }
  
  static void _checkSystemHealth() {
    final newSystemUsers = _getActiveUsersCount(isNewSystem: true);
    final legacySystemUsers = _getActiveUsersCount(isNewSystem: false);
    
    Analytics.track('system_health_check', {
      'new_system_users': newSystemUsers,
      'legacy_system_users': legacySystemUsers,
      'total_users': newSystemUsers + legacySystemUsers,
      'new_system_percentage': (newSystemUsers / (newSystemUsers + legacySystemUsers)) * 100,
    });
  }
}
```

## Phase 3: Full Migration (Week 5)

### 1. Complete Rollout
```dart
// Final rollout to 100%
FirebaseRemoteConfig.instance.setDefaults({
  'video_system_rollout': 100,
  'legacy_system_enabled': false, // Disable legacy system
});
```

### 2. Legacy System Cleanup
```dart
// lib/services/legacy_cleanup_service.dart
class LegacyCleanupService {
  static Future<void> migrateLegacyData() async {
    final legacyEvents = await _getLegacyVideoEvents();
    final newVideoManager = GetIt.instance<IVideoManager>();
    
    for (final event in legacyEvents) {
      try {
        await newVideoManager.addVideoEvent(event);
      } catch (e) {
        // Log migration errors but don't fail completely
        debugPrint('Failed to migrate event ${event.id}: $e');
      }
    }
  }
  
  static Future<void> cleanupLegacyServices() async {
    // Safely dispose legacy services
    final legacyEventService = GetIt.instance<VideoEventService>();
    final legacyCacheService = GetIt.instance<VideoCacheService>();
    
    await legacyEventService.dispose();
    await legacyCacheService.dispose();
    
    // Remove from dependency injection
    GetIt.instance.unregister<VideoEventService>();
    GetIt.instance.unregister<VideoCacheService>();
  }
}
```

## Rollback Procedures

### Emergency Rollback (Immediate)

#### Triggers for Emergency Rollback:
- Crash rate >5% above baseline
- Memory usage >1.5GB average
- Video load failure rate >20%
- User engagement drop >30%

#### Emergency Rollback Steps:
```dart
// 1. Immediate feature flag disable
FirebaseRemoteConfig.instance.setDefaults({
  'video_system_rollout': 0,
  'new_video_manager': false,
  'legacy_system_enabled': true,
});

// 2. Force app restart for all users
class EmergencyRollback {
  static void executeEmergencyRollback() {
    // Disable new system immediately
    FeatureFlags.overrideFlag('new_video_manager', false);
    
    // Clear any corrupted state
    _clearVideoManagerState();
    
    // Restart video services
    _restartVideoServices();
    
    // Alert operations team
    _sendEmergencyAlert('Emergency rollback executed');
  }
}
```

### Planned Rollback

#### 1. Gradual Rollback
```dart
// Reduce rollout percentage gradually
final rollbackSteps = [50, 25, 10, 0]; // Rollback over 4 hours

for (final percentage in rollbackSteps) {
  FirebaseRemoteConfig.instance.setDefaults({
    'video_system_rollout': percentage,
  });
  
  // Wait 1 hour between steps
  await Future.delayed(Duration(hours: 1));
  
  // Monitor health at each step
  if (_isSystemHealthy()) {
    break; // Stop rollback if health improves
  }
}
```

#### 2. Data Preservation
```dart
class RollbackDataPreservation {
  static Future<void> preserveNewSystemData() async {
    final videoManager = GetIt.instance<IVideoManager>();
    final debugInfo = videoManager.getDebugInfo();
    
    // Export new system state for analysis
    final exportData = {
      'timestamp': DateTime.now().toIso8601String(),
      'videos': videoManager.videos.map((v) => v.toJson()).toList(),
      'debug_info': debugInfo,
      'performance_stats': _getPerformanceStats(),
    };
    
    await _saveToBackup('rollback_data_${DateTime.now().millisecondsSinceEpoch}.json', exportData);
  }
  
  static Future<void> restoreLegacyState() async {
    // Restore legacy service state
    final legacyBackup = await _loadLegacyBackup();
    if (legacyBackup != null) {
      await _restoreLegacyServices(legacyBackup);
    }
  }
}
```

## Risk Mitigation

### 1. Automated Health Checks
```dart
class AutomatedHealthChecks {
  static void startContinuousMonitoring() {
    Timer.periodic(Duration(minutes: 2), (_) {
      final health = _checkSystemHealth();
      
      if (health.riskLevel == RiskLevel.critical) {
        _executeEmergencyRollback();
      } else if (health.riskLevel == RiskLevel.high) {
        _pauseRollout();
        _alertOperationsTeam(health);
      }
    });
  }
  
  static SystemHealth _checkSystemHealth() {
    return SystemHealth(
      crashRate: _getCrashRate(),
      memoryUsage: _getAverageMemoryUsage(),
      loadFailureRate: _getLoadFailureRate(),
      userEngagement: _getUserEngagement(),
      responseTime: _getAverageResponseTime(),
    );
  }
}
```

### 2. Circuit Breaker for Migration
```dart
class MigrationCircuitBreaker {
  static int _failureCount = 0;
  static DateTime? _lastFailure;
  static bool _circuitOpen = false;
  
  static bool shouldAllowMigration() {
    if (_circuitOpen) {
      // Circuit is open, check if enough time has passed
      if (_lastFailure != null && 
          DateTime.now().difference(_lastFailure!) > Duration(minutes: 30)) {
        _circuitOpen = false;
        _failureCount = 0;
      } else {
        return false; // Circuit still open
      }
    }
    
    return true;
  }
  
  static void recordFailure() {
    _failureCount++;
    _lastFailure = DateTime.now();
    
    if (_failureCount >= 5) {
      _circuitOpen = true;
      _pauseMigration();
    }
  }
}
```

### 3. Canary Testing
```dart
class CanaryTesting {
  static bool isCanaryUser(String userId) {
    // Select specific test users for early access
    final canaryUsers = [
      'internal-tester-1',
      'internal-tester-2',
      'beta-user-group',
    ];
    
    return canaryUsers.contains(userId) || 
           _isInternalUser(userId);
  }
  
  static void trackCanaryMetrics(String userId, Map<String, dynamic> metrics) {
    Analytics.track('canary_user_metrics', {
      'user_id': userId,
      'metrics': metrics,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
```

## Data Migration

### 1. Legacy Data Export
```dart
class LegacyDataExporter {
  static Future<Map<String, dynamic>> exportLegacyData() async {
    final eventService = GetIt.instance<VideoEventService>();
    final cacheService = GetIt.instance<VideoCacheService>();
    
    return {
      'video_events': eventService.videoEvents.map((e) => e.toJson()).toList(),
      'cached_videos': cacheService.getCachedVideoIds(),
      'user_preferences': await _exportUserPreferences(),
      'playback_history': await _exportPlaybackHistory(),
      'export_timestamp': DateTime.now().toIso8601String(),
    };
  }
}
```

### 2. Data Validation
```dart
class DataMigrationValidator {
  static Future<bool> validateMigration() async {
    final legacyData = await LegacyDataExporter.exportLegacyData();
    final newSystemData = await _exportNewSystemData();
    
    // Validate video count
    final legacyVideoCount = legacyData['video_events'].length;
    final newVideoCount = newSystemData['videos'].length;
    
    if ((legacyVideoCount - newVideoCount).abs() > 5) {
      debugPrint('Video count mismatch: Legacy=$legacyVideoCount, New=$newVideoCount');
      return false;
    }
    
    // Validate critical videos are present
    final criticalVideos = await _getCriticalVideoIds();
    for (final videoId in criticalVideos) {
      if (!_isVideoInNewSystem(videoId)) {
        debugPrint('Critical video missing: $videoId');
        return false;
      }
    }
    
    return true;
  }
}
```

## Post-Migration Tasks

### 1. Legacy Code Removal
```dart
// After successful migration (2-4 weeks after 100% rollout)
class LegacyCodeCleanup {
  static Future<void> removeLegacyCode() async {
    // 1. Remove legacy service files
    final filesToRemove = [
      'lib/services/video_event_service.dart',
      'lib/services/video_cache_service.dart',
      'lib/providers/video_feed_provider.dart',
    ];
    
    // 2. Remove legacy dependencies from pubspec.yaml
    // 3. Remove legacy test files
    // 4. Update documentation
    
    // 5. Create cleanup commit
    await _createCleanupCommit();
  }
}
```

### 2. Performance Validation
```dart
class PostMigrationValidation {
  static Future<void> validatePerformanceImprovements() async {
    final stats = await _collectPerformanceStats(Duration(days: 7));
    
    final improvements = {
      'memory_reduction': _calculateMemoryReduction(stats),
      'crash_rate_improvement': _calculateCrashRateImprovement(stats),
      'load_time_improvement': _calculateLoadTimeImprovement(stats),
      'user_engagement_change': _calculateEngagementChange(stats),
    };
    
    Analytics.track('migration_success_metrics', improvements);
    
    if (improvements['memory_reduction'] < 0.5) {
      debugPrint('Warning: Memory reduction less than expected');
    }
  }
}
```

## Testing Strategy

### Pre-Migration Testing
```bash
# 1. Run comprehensive test suite
flutter test test/unit/
flutter test test/integration/
flutter test test/widget/

# 2. Performance testing
flutter test test/integration/performance_test.dart

# 3. Memory leak testing
flutter test test/integration/memory_leak_test.dart

# 4. Load testing
flutter test test/integration/load_testing.dart
```

### During Migration Testing
```dart
class MigrationTesting {
  static void runMigrationTests() {
    // A/B test validation
    _validateABTestSetup();
    
    // Feature flag validation
    _validateFeatureFlags();
    
    // Rollback mechanism validation
    _validateRollbackMechanism();
    
    // Data consistency validation
    _validateDataConsistency();
  }
}
```

## Communication Plan

### Stakeholder Updates
```
Week 1: "New video system deployed alongside legacy system for testing"
Week 2: "10% rollout started - monitoring metrics closely"
Week 3: "25% rollout - positive performance improvements observed"
Week 4: "50% rollout - memory usage reduced by 70%"
Week 5: "100% rollout complete - migration successful"
Week 6: "Legacy system cleanup initiated"
```

### User Communication
- No user-visible changes expected
- Performance improvements will be transparent
- Alert users only if rollback is needed

## Rollback Decision Matrix

| Metric | Green | Yellow | Red | Action |
|--------|-------|--------|-----|--------|
| Crash Rate | <1% | 1-3% | >3% | Red: Emergency rollback |
| Memory Usage | <500MB | 500-800MB | >800MB | Red: Emergency rollback |
| Load Failure Rate | <5% | 5-15% | >15% | Red: Emergency rollback |
| User Engagement | >95% | 90-95% | <90% | Red: Planned rollback |
| Response Time | <2s | 2-5s | >5s | Yellow: Pause rollout |

## Success Criteria

### Migration Success Metrics
- [ ] Memory usage reduced by >70% (3GB → <500MB)
- [ ] Crash rate remains within 1% of baseline
- [ ] Video load success rate >95%
- [ ] User engagement maintained >95% of baseline
- [ ] All automated tests passing
- [ ] Zero data loss during migration
- [ ] Rollback capability validated and working

### Long-term Success Metrics
- [ ] System stability >99.9% uptime
- [ ] Performance improvements sustained over 30 days
- [ ] Developer velocity improved with cleaner architecture
- [ ] Reduced support tickets related to video issues
- [ ] Successful legacy code removal

## Conclusion

This migration plan provides a comprehensive, risk-mitigated approach to transitioning from the legacy video system to the new TDD-driven architecture. The phased rollout with automated health checks and rollback capabilities ensures minimal risk while delivering significant performance improvements.
