// ABOUTME: App-wide repository, bloc and listener composition above MaterialApp
// ABOUTME: Lifted out of _DivineAppState.build() so the tree is its own unit (#3337)

import 'dart:async';

import 'package:app_update_repository/app_update_repository.dart';
import 'package:app_version_client/app_version_client.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/app_update/app_update.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/blocs/camera_permission/camera_permission_bloc.dart';
import 'package:openvine/blocs/codec_heavy_surface/codec_heavy_surface_cubit.dart';
import 'package:openvine/blocs/email_verification/email_verification_cubit.dart';
import 'package:openvine/blocs/locale/locale_cubit.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_scope.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/features/appearance/providers/appearance_providers.dart';
import 'package:openvine/features/people_lists/curated_lists_gate.dart';
import 'package:openvine/features/people_lists/people_lists.dart';
import 'package:openvine/l10n/current_app_l10n.dart';
import 'package:openvine/l10n/email_verification_error_l10n.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/creator_sync_provider.dart';
import 'package:openvine/providers/install_source_provider.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/collaborator_invite_service.dart';
import 'package:openvine/services/locale_preference_service.dart';
import 'package:openvine/services/mention_resolution_service.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';
import 'package:openvine/startup/upload_failure_listener.dart';
import 'package:openvine/widgets/app_lifecycle_handler.dart';
import 'package:openvine/widgets/app_shell_badge_scope.dart';
import 'package:openvine/widgets/geo_blocking_gate.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permissions_service/permissions_service.dart';

/// Provides every app-wide repository, bloc and global listener, then renders
/// [child] beneath them.
///
/// [child] is the [MaterialApp]: the locale and appearance cubits it reads are
/// provided by this tree, so the app cannot be constructed above it.
class AppCompositionRoot extends ConsumerWidget {
  const AppCompositionRoot({
    required this.packageInfo,
    required this.child,
    super.key,
  });

  final PackageInfo packageInfo;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /// Creates the publish service with callbacks wired to this notifier.
    Future<VideoPublishService> createPublishService({
      required OnProgressChanged onProgress,
    }) async {
      final profileRepository = ref.read(profileRepositoryProvider);
      return VideoPublishService(
        uploadManager: ref.read(uploadManagerProvider),
        authService: ref.read(authServiceProvider),
        videoEventPublisher: ref.read(videoEventPublisherProvider),
        blossomService: ref.read(blossomUploadServiceProvider),
        draftService: ref.read(draftStorageServiceProvider),
        mentionResolutionService: profileRepository == null
            ? null
            : MentionResolutionService(profileRepository: profileRepository),
        collaboratorInviteService: CollaboratorInviteService(
          dmRepository: ref.read(dmRepositoryProvider),
          l10n: currentAppL10n(ref.read(sharedPreferencesProvider)),
        ),
        performanceMonitor: ref.read(performanceMonitoringServiceProvider),
        onProgressChanged:
            ({required String draftId, required double progress}) {
              onProgress(draftId: draftId, progress: progress);
            },
      );
    }

    final oauthClient = ref.watch(oauthClientProvider);
    final authService = ref.watch(authServiceProvider);

    // Wrap with geo-blocking check first, then lifecycle handler
    // The two app-shell badge cubits + their repository-sync listeners live
    // in AppShellBadgeScope so this tree and its test pump the exact same eager
    // (`lazy: false`) wiring that stops the #6115 re-entrant create.
    return SavedSoundsScope(
      service: ref.watch(savedSoundsServiceProvider),
      // A stream, not a watched value: SavedSoundsScope sits above
      // MaterialApp.router, so keying its BlocProvider on the resolved
      // repository would re-inflate the whole app shell every time it
      // resolves (#6477/#6480). The bloc subscribes and re-points itself.
      syncRepositoryStream: ref.read(soundSyncRepositoryStreamProvider),
      child: AppShellBadgeScope(
        child: MultiBlocProvider(
          providers: [
            BlocProvider(
              lazy: false,
              create: (_) => VideoVolumeCubit(
                sharedPreferences: ref.read(sharedPreferencesProvider),
              ),
            ),
            // App-global signal: a codec-heavy surface (camera/editor/exporter)
            // is open, so background feeds must release their hardware decoders.
            BlocProvider(create: (_) => CodecHeavySurfaceCubit()),
            BlocProvider(
              create: (_) => LocaleCubit(
                localePreferenceService: LocalePreferenceService(
                  sharedPreferences: ref.read(sharedPreferencesProvider),
                ),
              ),
            ),
            BlocProvider.value(value: ref.read(appearanceCubitProvider)),
            BlocProvider(
              create: (_) => BackgroundPublishBloc(
                videoPublishServiceFactory: createPublishService,
                draftStorageService: ref.read(draftStorageServiceProvider),
                foregroundSession: ref.read(publishForegroundSessionProvider),
              ),
            ),
            BlocProvider(
              create: (_) => CameraPermissionBloc(
                permissionsService: const PermissionHandlerPermissionsService(),
              )..add(const CameraPermissionRefresh()),
            ),
            BlocProvider(
              key: ValueKey((oauthClient, authService)),
              create: (_) => EmailVerificationCubit(
                oauthClient: oauthClient,
                authService: authService,
              ),
            ),
            BlocProvider(
              create: (_) => AppUpdateBloc(
                repository: AppUpdateRepository(
                  appVersionClient: AppVersionClient(),
                  sharedPreferences: ref.read(sharedPreferencesProvider),
                  currentVersion: packageInfo.version,
                  // Real install source resolved at startup (Play / App Store
                  // / TestFlight / Zapstore / sideload) — drives the correct
                  // download URL for update nudges. Was hardcoded `sideload`.
                  installSource: ref.read(installSourceProvider),
                ),
              )..add(const AppUpdateCheckRequested()),
            ),
            // Provisioned above MaterialApp.router so every route (including
            // ones outside AppShell) sees the same lists state.
            //
            // Deliberately not wrapped in `if (curatedLists enabled)`: a
            // conditional entry changes this provider chain's shape, so
            // flipping the flag re-inflated everything below it — the whole
            // MaterialApp.router subtree, feed state, video controllers, and
            // the upload-listener dedupe sets with it. Users were thrown back
            // to Settings from the imperatively pushed feature-flag screen;
            // both the symptom and its disappearance under this shape are
            // verified on device (#6477). What is not pinned is the
            // Navigator-level step in between — a synthetic probe of the same
            // shape kept the pushed route — so do not read the chain below
            // re-inflation as established.
            //
            // Laziness does the creation gate instead: every entry point into
            // the people-lists UI checks FeatureFlag.curatedLists before
            // reading the bloc — the lists routes redirect home, the profile
            // and search affordances stay hidden, and both sheets refuse to
            // open — so a disabled feature does not construct the bloc.
            //
            // Once constructed while the flag is on, the bloc remains session-
            // lifetime even if the flag flips off — laziness gates construction,
            // not teardown. enabledStream is how it stands down instead: on a
            // flag-off it drops its cache subscription and stops syncing, and on
            // a flag-on it rewires to whoever is signed in then (#6494).
            //
            // peopleListsRepositoryProvider is keepAlive but not identity-
            // stable: it watches nostrServiceProvider, which recreates its
            // client on auth change. This provider is intentionally still not
            // keyed; repositoryStream keeps the app-lifetime bloc pointed at
            // the current repository without re-inflating MaterialApp.router
            // (#6480, #6482).
            BlocProvider(
              create: (_) {
                final authService = ref.read(authServiceProvider);
                final ownerPubkeyStream = authService.authStateStream
                    .map((_) => authService.currentPublicKeyHex)
                    .distinct();
                return PeopleListsBloc(
                  repository: ref.read(peopleListsRepositoryProvider),
                  repositoryStream: ref.read(
                    peopleListsRepositoryIdentityStreamProvider,
                  ),
                  enabledStream: ref.read(curatedListsEnabledStreamProvider),
                  ownerPubkeyStream: ownerPubkeyStream,
                  initialOwnerPubkey: authService.currentPublicKeyHex,
                )..add(const PeopleListsStarted());
              },
            ),
          ],
          // Global listener for email verification failures - shows snackbar
          // when verification times out or fails while user is elsewhere in app
          child: BlocListener<EmailVerificationCubit, EmailVerificationState>(
            listenWhen: (previous, current) =>
                current.status == EmailVerificationStatus.failure &&
                previous.status != EmailVerificationStatus.failure,
            listener: (context, state) {
              final messenger = ScaffoldMessenger.maybeOf(context);
              final errorCode = state.errorCode;
              if (messenger != null && errorCode != null) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      context.l10n.emailVerificationErrorMessage(errorCode),
                    ),
                    backgroundColor: VineTheme.error,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            },
            child: UpdateDialogListener(
              child: UploadFailureListener(
                child: GeoBlockingGate(
                  child: AppLifecycleHandler(child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
