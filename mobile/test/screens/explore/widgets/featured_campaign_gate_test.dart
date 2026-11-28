import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/featured_tabs/featured_tabs_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/repositories/featured_tabs_repository.dart';
import 'package:openvine/screens/explore/widgets/featured_campaign_gate.dart';

class _MockFeaturedTabsRepository extends Mock
    implements FeaturedTabsRepository {}

void main() {
  group('renders', () {
    testWidgets('loading settles and stays static with reduced motion', (
      tester,
    ) async {
      final cubit = FeaturedTabsCubit(
        repository: _MockFeaturedTabsRepository(),
        audience: () => FeaturedTabAudience.loading,
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: cubit,
            child: const MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: FeaturedCampaignGate(),
            ),
          ),
        ),
      );
      expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 1),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
