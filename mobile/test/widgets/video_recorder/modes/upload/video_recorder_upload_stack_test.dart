import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_recorder/modes/upload/upload_explainer_constants.dart';
import 'package:openvine/widgets/video_recorder/modes/upload/video_recorder_upload_stack.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../../helpers/url_launcher_test_double.dart';

void main() {
  group(VideoRecorderUploadStack, () {
    late UrlLauncherPlatform originalPlatform;
    late UrlLauncherTestDouble launcher;

    setUp(() {
      originalPlatform = UrlLauncherPlatform.instance;
      launcher = UrlLauncherTestDouble();
      UrlLauncherPlatform.instance = launcher;
    });

    tearDown(() {
      UrlLauncherPlatform.instance = originalPlatform;
    });

    Widget pumpStack({Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: VideoRecorderUploadStack()),
    );

    testWidgets('renders title, body paragraphs, cta, and learn-more link', (
      tester,
    ) async {
      await tester.pumpWidget(pumpStack());
      final l10n = lookupAppLocalizations(const Locale('en'));

      expect(find.text(l10n.videoRecorderUploadTitle), findsOneWidget);
      expect(find.text(l10n.videoRecorderUploadBody), findsOneWidget);
      expect(find.text(l10n.videoRecorderUploadBodyDetail), findsOneWidget);
      expect(find.text(l10n.videoRecorderUploadBodyCta), findsOneWidget);
      expect(find.text(l10n.videoRecorderUploadLearnMore), findsOneWidget);
    });

    testWidgets('learn-more tap opens proofmode URL externally', (
      tester,
    ) async {
      await tester.pumpWidget(pumpStack());
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.tap(find.text(l10n.videoRecorderUploadLearnMore));
      await tester.pumpAndSettle();

      expect(launcher.launched, isNotEmpty);
      expect(launcher.launched.last.url, equals(proofmodeLearnMoreUrl));
      expect(launcher.launched.last.useExternalApplication, isTrue);
    });
  });
}
