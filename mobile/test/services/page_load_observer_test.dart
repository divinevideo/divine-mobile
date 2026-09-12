import 'package:analytics/analytics.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _RecordingAnalyticsEventSink implements AnalyticsEventSink {
  final events = <({String name, Map<String, Object> parameters})>[];
  final screenViews =
      <
        ({
          String screenName,
          String? screenClass,
          Map<String, Object>? parameters,
        })
      >[];

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {}

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    events.add((name: name, parameters: parameters));
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {
    screenViews.add((
      screenName: screenName,
      screenClass: screenClass,
      parameters: parameters,
    ));
  }
}

class _FakeFirebaseCore extends Fake
    with MockPlatformInterfaceMixin
    implements FirebasePlatform {
  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    return _FakeFirebaseApp();
  }

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return _FakeFirebaseApp();
  }

  @override
  List<FirebaseAppPlatform> get apps => [_FakeFirebaseApp()];
}

class _FakeFirebaseApp extends Fake
    with MockPlatformInterfaceMixin
    implements FirebaseAppPlatform {
  @override
  String get name => defaultFirebaseAppName;

  @override
  FirebaseOptions get options => const FirebaseOptions(
    apiKey: 'test-api-key',
    appId: 'test-app-id',
    messagingSenderId: 'test-sender-id',
    projectId: 'test-project-id',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FirebasePlatform originalFirebasePlatform;

  setUpAll(() {
    originalFirebasePlatform = FirebasePlatform.instance;
    FirebasePlatform.instance = _FakeFirebaseCore();
  });

  tearDownAll(() {
    FirebasePlatform.instance = originalFirebasePlatform;
  });

  group(PageLoadObserver, () {
    late _RecordingAnalyticsEventSink sink;
    late PageLoadObserver observer;

    setUp(() {
      sink = _RecordingAnalyticsEventSink();
      observer = PageLoadObserver(
        analytics: ScreenAnalyticsService(
          history: PageLoadHistory(),
          sink: sink,
        ),
      );
    });

    test('creates an instance', () {
      expect(observer, isA<NavigatorObserver>());
    });

    testWidgets('tracks didPush for regular routes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: [observer],
          home: const Scaffold(body: Text('Home')),
          routes: {'/test': (_) => const Scaffold(body: Text('Test'))},
        ),
      );

      final context = tester.element(find.text('Home'));
      Navigator.of(context).pushNamed('/test');
      await tester.pumpAndSettle();

      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('skips popup routes without crashing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: [observer],
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => const AlertDialog(content: Text('Dialog')),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      final baselineScreenViewCount = sink.screenViews.length;
      final baselineEventCount = sink.events.length;

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Dialog'), findsOneWidget);
      expect(sink.screenViews, hasLength(baselineScreenViewCount));
      expect(sink.events, hasLength(baselineEventCount));
    });

    testWidgets('tracks didPop for regular routes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: [observer],
          home: const Scaffold(body: Text('Home')),
          routes: {
            '/test': (_) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ),
            ),
          },
        ),
      );

      final context = tester.element(find.text('Home'));
      Navigator.of(context).pushNamed('/test');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Go Back'));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('logs semantic screen view for named routes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: [observer],
          home: const Scaffold(body: Text('Home')),
          onGenerateRoute: (settings) {
            if (settings.name == '/video/123') {
              return MaterialPageRoute<void>(
                settings: const RouteSettings(name: 'video'),
                builder: (_) => const Scaffold(body: Text('Video Detail')),
              );
            }
            return null;
          },
        ),
      );

      final context = tester.element(find.text('Home'));
      Navigator.of(context).pushNamed('/video/123');
      await tester.pumpAndSettle();

      expect(find.text('Video Detail'), findsOneWidget);
      expect(
        sink.screenViews.map((event) => event.screenName),
        contains('video_detail'),
      );
      expect(
        sink.screenViews.last.parameters,
        containsPair(AnalyticsParam.routeName, 'video'),
      );
      expect(
        sink.screenViews.last.parameters,
        containsPair(AnalyticsParam.entryPoint, 'navigation'),
      );
    });

    testWidgets('normalizes app route names before logging screen views', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: [observer],
          home: const Scaffold(body: Text('Home')),
          onGenerateRoute: (settings) {
            final routeName = switch (settings.name) {
              '/developer-options' => 'developer-options',
              '/original-sound' => 'originalSound',
              _ => null,
            };
            if (routeName == null) {
              return null;
            }
            return MaterialPageRoute<void>(
              settings: RouteSettings(name: routeName),
              builder: (_) => Scaffold(body: Text(settings.name!)),
            );
          },
        ),
      );

      final context = tester.element(find.text('Home'));
      Navigator.of(context).pushNamed('/developer-options');
      await tester.pumpAndSettle();
      Navigator.of(context).pushNamed('/original-sound');
      await tester.pumpAndSettle();

      expect(
        sink.screenViews.map((event) => event.screenName),
        containsAllInOrder(['developer_options', 'original_sound']),
      );
      expect(
        sink.screenViews.map((event) => event.screenName),
        isNot(contains('developer-options')),
      );
      expect(
        sink.screenViews.map((event) => event.screenName),
        isNot(contains('originalSound')),
      );
    });

    testWidgets('uses unknown route for unnamed regular route screen views', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: [observer],
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('Unnamed')),
                  ),
                );
              },
              child: const Text('Open Unnamed'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Unnamed'));
      await tester.pumpAndSettle();

      expect(find.text('Unnamed'), findsOneWidget);
      expect(sink.screenViews.last.screenName, AnalyticsSurface.unknownRoute);
      expect(
        sink.screenViews.last.parameters,
        containsPair(AnalyticsParam.routeName, AnalyticsSurface.unknownRoute),
      );
      expect(
        sink.screenViews.map((event) => event.screenName),
        isNot(contains('MaterialPageRoute<void>')),
      );
    });
  });
}
