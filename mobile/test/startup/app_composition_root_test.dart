// ABOUTME: Tests the publish service AppCompositionRoot builds for
// ABOUTME: BackgroundPublishBloc retries.

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/layer_rasterizer_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/scheduled_posts_providers.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/repositories/scheduled_posts_repository.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';
import 'package:openvine/startup/app_composition_root.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockScheduledPostsRepository extends Mock
    implements ScheduledPostsRepository {}

class _MockLayerRasterizer extends Mock implements LayerRasterizer {}

class _MockUploadManager extends Mock implements UploadManager {}

class _MockAuthService extends Mock implements AuthService {}

class _MockVideoEventPublisher extends Mock implements VideoEventPublisher {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockDraftStorageService extends Mock implements DraftStorageService {}

class _MockDmRepository extends Mock implements DmRepository {}

class _MockPerformanceMonitoringService extends Mock
    implements PerformanceMonitoringService {}

void main() {
  group('createBackgroundPublishService', () {
    testWidgets(
      'gives a retried publish the scheduled-post outbox (#3538)',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repository = _MockScheduledPostsRepository();
        VideoPublishService? service;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              scheduledPostsRepositoryProvider.overrideWithValue(repository),
              layerRasterizerProvider.overrideWithValue(_MockLayerRasterizer()),
              uploadManagerProvider.overrideWithValue(_MockUploadManager()),
              authServiceProvider.overrideWithValue(_MockAuthService()),
              videoEventPublisherProvider.overrideWithValue(
                _MockVideoEventPublisher(),
              ),
              blossomUploadServiceProvider.overrideWithValue(
                _MockBlossomUploadService(),
              ),
              draftStorageServiceProvider.overrideWithValue(
                _MockDraftStorageService(),
              ),
              profileRepositoryProvider.overrideWithValue(null),
              dmRepositoryProvider.overrideWithValue(_MockDmRepository()),
              sharedPreferencesProvider.overrideWithValue(prefs),
              performanceMonitoringServiceProvider.overrideWithValue(
                _MockPerformanceMonitoringService(),
              ),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                service = createBackgroundPublishService(
                  ref,
                  onProgress: ({required draftId, required progress}) {},
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(service, isNotNull);
        expect(service!.scheduledPostsRepository, same(repository));
      },
    );
  });
}
