// ABOUTME: Mounts once in the widget tree to evaluate the in-app review
// ABOUTME: gate on auth settle, profile-stats load, and app foreground.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/features/app_review/app_review_coordinator_cubit.dart';
import 'package:openvine/features/app_review/app_review_profile_stats_loader.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/install_source_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/app_engagement_store.dart';
import 'package:openvine/services/app_review_prompt_service.dart';
import 'package:openvine/services/auth_service.dart' show AuthState;

/// Provides the native in-app review platform facade.
final appReviewPlatformProvider = Provider<AppReviewPlatform>(
  (ref) => InAppReviewPlatform(),
);

/// Provides the scheduler used to wait for a stable frame before prompting.
final appReviewFrameSchedulerProvider = Provider<AppReviewFrameScheduler>(
  (ref) => const WidgetsAppReviewFrameScheduler(),
);

/// Provides the [AppReviewPromptService].
final appReviewPromptServiceProvider = Provider<AppReviewPromptService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AppReviewPromptService(sharedPreferences: prefs);
});

/// Provides the [AppEngagementStore].
final appEngagementStoreProvider = Provider<AppEngagementStore>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AppEngagementStore(sharedPreferences: prefs);
});

/// Provides the review-prompt coordinator cubit.
final appReviewCoordinatorCubitProvider = Provider<AppReviewCoordinatorCubit>((
  ref,
) {
  final cubit = AppReviewCoordinatorCubit(
    service: ref.watch(appReviewPromptServiceProvider),
    analytics: ref.watch(analyticsEventSinkProvider),
    reviewPlatform: ref.watch(appReviewPlatformProvider),
    frameScheduler: ref.watch(appReviewFrameSchedulerProvider),
  );
  ref.onDispose(cubit.close);
  return cubit;
});

/// A zero-size widget that evaluates the review gate when the app returns to
/// the foreground. Mount exactly once near the root of the widget tree.
///
/// Renders nothing; its only job is to dispatch the OS-native review request
/// when all eligibility conditions in [AppReviewPromptService.shouldShow] are
/// met.
class AppReviewCoordinator extends ConsumerStatefulWidget {
  const AppReviewCoordinator({super.key, this.child});

  /// The rest of the app tree. Included so the coordinator can wrap the app
  /// without an extra nesting level.
  final Widget? child;

  @override
  ConsumerState<AppReviewCoordinator> createState() =>
      _AppReviewCoordinatorState();
}

class _AppReviewCoordinatorState extends ConsumerState<AppReviewCoordinator> {
  static const _profileStatsLoader = AppReviewProfileStatsLoader();

  bool? _wasForeground;

  @override
  Widget build(BuildContext context) {
    // Auth is watched so account swaps rebuild before the next foreground
    // trigger. Foreground transitions are the only prompt moment.
    ref.watch(currentAuthStateProvider);
    final isForeground = ref.watch(appForegroundProvider);
    final wasForeground = _wasForeground;
    _wasForeground = isForeground;
    if (wasForeground == false && isForeground) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
    }
    return widget.child ?? const SizedBox.shrink();
  }

  Future<void> _maybePrompt() async {
    if (!mounted) return;
    final authService = ref.read(authServiceProvider);
    if (authService.authState != AuthState.authenticated) return;
    final pubkey = authService.currentPublicKeyHex;
    if (pubkey == null) return;

    final engagement = ref.read(appEngagementStoreProvider);
    final service = ref.read(appReviewPromptServiceProvider);
    final installSource = ref.read(installSourceProvider);
    final localInputs = ReviewLocalEligibilityInputs(
      pubkey: pubkey,
      installSource: installSource,
      sessionCount: engagement.sessionCount,
      daysSinceFirstLaunch: engagement.daysSinceFirstLaunch(),
    );
    if (!service.shouldLoadProfileStats(localInputs)) return;

    final stats = await _loadProfileStats(pubkey);
    if (!_isActiveFor(pubkey)) return;
    await ref
        .read(appReviewCoordinatorCubitProvider)
        .evaluate(
          inputs: ReviewEligibilityInputs(
            pubkey: pubkey,
            videoCount: stats?.videoCount ?? 0,
            installSource: installSource,
            sessionCount: localInputs.sessionCount,
            daysSinceFirstLaunch: localInputs.daysSinceFirstLaunch,
          ),
          isActive: () => _isActiveFor(pubkey),
        );
  }

  bool _isActiveFor(String pubkey) {
    if (!mounted || !ref.read(appForegroundProvider)) return false;
    final authService = ref.read(authServiceProvider);
    return authService.authState == AuthState.authenticated &&
        authService.currentPublicKeyHex == pubkey;
  }

  Future<ProfileStats?> _loadProfileStats(String pubkey) async {
    final repository = ref.read(profileReadRepositoryProvider);
    if (repository == null) return null;
    return _profileStatsLoader.load(
      refresh: () async {
        await repository.fetchFreshProfile(pubkey: pubkey);
      },
      watch: () => repository.watchProfileStats(pubkey: pubkey),
    );
  }
}
