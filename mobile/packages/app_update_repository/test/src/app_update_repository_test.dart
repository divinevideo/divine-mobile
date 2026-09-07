import 'package:app_update_repository/app_update_repository.dart';
import 'package:app_version_client/app_version_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

class _MockAppVersionClient extends Mock implements AppVersionClient {}

void main() {
  group(AppUpdateRepository, () {
    late _MockAppVersionClient client;
    late SharedPreferences prefs;

    setUp(() async {
      client = _MockAppVersionClient();
      SharedPreferences.setMockInitialValues({
        UpdatePrefsKeys.lastChecked: DateTime.now()
            .subtract(const Duration(hours: 25))
            .toIso8601String(),
      });
      prefs = await SharedPreferences.getInstance();
    });

    AppUpdateRepository buildRepo({
      String currentVersion = '1.0.4',
      InstallSource installSource = InstallSource.sideload,
    }) {
      return AppUpdateRepository(
        appVersionClient: client,
        sharedPreferences: prefs,
        currentVersion: currentVersion,
        installSource: installSource,
      );
    }

    AppVersionInfo buildInfo({
      String version = '1.0.8',
      DateTime? publishedAt,
      String? minimumVersion,
      List<String> highlights = const ['New feature'],
    }) {
      return AppVersionInfo(
        latestVersion: version,
        publishedAt: publishedAt ?? DateTime.now(),
        releaseNotesUrl:
            'https://github.com/divinevideo/divine-mobile/releases/'
            'tag/$version',
        minimumVersion: minimumVersion,
        releaseHighlights: highlights,
      );
    }

    group('checkForUpdate', () {
      test('returns none when on latest version', () async {
        when(
          () => client.fetchLatestRelease(),
        ).thenAnswer((_) async => buildInfo());

        final repo = buildRepo(currentVersion: '1.0.8');
        final result = await repo.checkForUpdate();

        expect(result!.urgency, equals(UpdateUrgency.none));
      });

      test('returns none when ahead of latest', () async {
        when(
          () => client.fetchLatestRelease(),
        ).thenAnswer((_) async => buildInfo());

        final repo = buildRepo(currentVersion: '1.0.9');
        final result = await repo.checkForUpdate();

        expect(result!.urgency, equals(UpdateUrgency.none));
      });

      test('returns gentle when update is < 2 weeks old', () async {
        when(() => client.fetchLatestRelease()).thenAnswer(
          (_) async => buildInfo(
            publishedAt: DateTime.now().subtract(const Duration(days: 5)),
          ),
        );

        final repo = buildRepo();
        final result = await repo.checkForUpdate();

        expect(result!.urgency, equals(UpdateUrgency.gentle));
      });

      test('returns moderate when update is >= 2 weeks old', () async {
        when(() => client.fetchLatestRelease()).thenAnswer(
          (_) async => buildInfo(
            publishedAt: DateTime.now().subtract(const Duration(days: 15)),
          ),
        );

        final repo = buildRepo();
        final result = await repo.checkForUpdate();

        expect(result!.urgency, equals(UpdateUrgency.moderate));
      });

      test('returns urgent when below minimum_version', () async {
        when(
          () => client.fetchLatestRelease(),
        ).thenAnswer((_) async => buildInfo(minimumVersion: '1.0.6'));

        final repo = buildRepo();
        final result = await repo.checkForUpdate();

        expect(result!.urgency, equals(UpdateUrgency.urgent));
      });

      test('urgent overrides moderate when below minimum', () async {
        when(() => client.fetchLatestRelease()).thenAnswer(
          (_) async => buildInfo(
            publishedAt: DateTime.now().subtract(const Duration(days: 30)),
            minimumVersion: '1.0.6',
          ),
        );

        final repo = buildRepo();
        final result = await repo.checkForUpdate();

        expect(result!.urgency, equals(UpdateUrgency.urgent));
      });

      test('resolves correct download URL for install source', () async {
        when(() => client.fetchLatestRelease()).thenAnswer(
          (_) async => buildInfo(
            publishedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        );

        final repo = buildRepo(installSource: InstallSource.playStore);
        final result = await repo.checkForUpdate();

        expect(result!.downloadUrl, equals(DownloadUrls.playStore));
      });

      test('resolves GitHub URL for sideload source', () async {
        when(() => client.fetchLatestRelease()).thenAnswer(
          (_) async => buildInfo(
            publishedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        );

        final repo = buildRepo();
        final result = await repo.checkForUpdate();

        expect(result!.downloadUrl, equals(DownloadUrls.github));
      });

      test('includes release highlights in result', () async {
        when(() => client.fetchLatestRelease()).thenAnswer(
          (_) async => buildInfo(
            publishedAt: DateTime.now().subtract(const Duration(days: 1)),
            highlights: ['Feature A', 'Feature B'],
          ),
        );

        final repo = buildRepo();
        final result = await repo.checkForUpdate();

        expect(result!.releaseHighlights, equals(['Feature A', 'Feature B']));
      });

      test('returns none on fetch failure', () async {
        when(
          () => client.fetchLatestRelease(),
        ).thenThrow(const AppVersionFetchException('no network'));

        final repo = buildRepo();
        final result = await repo.checkForUpdate();

        expect(result!.urgency, equals(UpdateUrgency.none));
      });

      test('returns null on first install', () async {
        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();

        final repo = buildRepo();
        final result = await repo.checkForUpdate();

        expect(result, isNull);
        expect(prefs.getString(UpdatePrefsKeys.lastChecked), isNotNull);
      });

      test('returns null when within 24h TTL', () async {
        SharedPreferences.setMockInitialValues({
          UpdatePrefsKeys.lastChecked: DateTime.now()
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
        });
        prefs = await SharedPreferences.getInstance();

        final repo = buildRepo();
        final result = await repo.checkForUpdate();

        expect(result, isNull);
        verifyNever(() => client.fetchLatestRelease());
      });

      test('restores a cached available update within the 24h TTL', () async {
        SharedPreferences.setMockInitialValues({
          UpdatePrefsKeys.lastChecked: DateTime.now()
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
          UpdatePrefsKeys.latestVersion: '1.0.8',
          UpdatePrefsKeys.downloadUrl: DownloadUrls.playStore,
        });
        prefs = await SharedPreferences.getInstance();

        final repo = buildRepo(installSource: InstallSource.playStore);
        final result = await repo.checkForUpdate();

        expect(
          result,
          const UpdateCheckResult(
            urgency: UpdateUrgency.none,
            downloadUrl: DownloadUrls.playStore,
            latestVersion: '1.0.8',
          ),
        );
        verifyNever(() => client.fetchLatestRelease());
      });

      test(
        'ignores a cached update after the app reaches that version',
        () async {
          SharedPreferences.setMockInitialValues({
            UpdatePrefsKeys.lastChecked: DateTime.now()
                .subtract(const Duration(hours: 1))
                .toIso8601String(),
            UpdatePrefsKeys.latestVersion: '1.0.8',
            UpdatePrefsKeys.downloadUrl: DownloadUrls.playStore,
          });
          prefs = await SharedPreferences.getInstance();

          final repo = buildRepo(
            currentVersion: '1.0.8',
            installSource: InstallSource.playStore,
          );
          final result = await repo.checkForUpdate();

          expect(result, isNull);
          expect(prefs.getString(UpdatePrefsKeys.latestVersion), isNull);
          expect(prefs.getString(UpdatePrefsKeys.downloadUrl), isNull);
          verifyNever(() => client.fetchLatestRelease());
        },
      );

      test('gentle dismissed hides until next version', () async {
        await prefs.setString(UpdatePrefsKeys.dismissedVersion, '1.0.8');
        await prefs.setString(
          UpdatePrefsKeys.dismissedAt,
          DateTime.now().toIso8601String(),
        );

        when(() => client.fetchLatestRelease()).thenAnswer(
          (_) async => buildInfo(
            publishedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        );

        final repo = buildRepo();
        final result = await repo.checkForUpdate();

        expect(result!.urgency, equals(UpdateUrgency.none));
      });

      test('moderate reappears after 3-day cooldown', () async {
        await prefs.setString(UpdatePrefsKeys.dismissedVersion, '1.0.8');
        await prefs.setString(
          UpdatePrefsKeys.dismissedAt,
          DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
        );

        when(() => client.fetchLatestRelease()).thenAnswer(
          (_) async => buildInfo(
            publishedAt: DateTime.now().subtract(const Duration(days: 20)),
          ),
        );

        final repo = buildRepo();
        final result = await repo.checkForUpdate();

        expect(result!.urgency, equals(UpdateUrgency.moderate));
      });

      test('new version resets dismissal', () async {
        await prefs.setString(UpdatePrefsKeys.dismissedVersion, '1.0.7');
        await prefs.setString(
          UpdatePrefsKeys.dismissedAt,
          DateTime.now().toIso8601String(),
        );

        when(() => client.fetchLatestRelease()).thenAnswer(
          (_) async => buildInfo(
            publishedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        );

        final repo = buildRepo();
        final result = await repo.checkForUpdate();

        expect(result!.urgency, equals(UpdateUrgency.gentle));
      });
    });

    group('dismissUpdate', () {
      test('persists version and timestamp', () async {
        final repo = buildRepo();
        await repo.dismissUpdate('1.0.8');

        expect(
          prefs.getString(UpdatePrefsKeys.dismissedVersion),
          equals('1.0.8'),
        );
        expect(prefs.getString(UpdatePrefsKeys.dismissedAt), isNotNull);
      });
    });
  });
}
