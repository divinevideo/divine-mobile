import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/invite_models.dart';
import 'package:openvine/screens/settings/invites_screen.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';

class _MockInviteStatusCubit extends MockCubit<InviteStatusState>
    implements InviteStatusCubit {}

void main() {
  group(InvitesView, () {
    late _MockInviteStatusCubit mockCubit;

    setUp(() {
      mockCubit = _MockInviteStatusCubit();
    });

    Widget buildSubject() {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<InviteStatusCubit>.value(
          value: mockCubit,
          child: const Scaffold(body: InvitesView()),
        ),
      );
    }

    group('renders', () {
      testWidgets('loading indicator when loading', (tester) async {
        when(() => mockCubit.state).thenReturn(
          const InviteStatusState(status: InviteStatusLoadingStatus.loading),
        );
        await tester.pumpWidget(buildSubject());
        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      });

      testWidgets('empty state when no invites', (tester) async {
        when(() => mockCubit.state).thenReturn(
          const InviteStatusState(
            status: InviteStatusLoadingStatus.loaded,
            inviteStatus: InviteStatus(
              canInvite: false,
              remaining: 0,
              total: 0,
              codes: [],
            ),
          ),
        );
        await tester.pumpWidget(buildSubject());
        expect(find.text('No invites available right now'), findsOneWidget);
      });

      testWidgets('invite codes when available', (tester) async {
        when(() => mockCubit.state).thenReturn(
          const InviteStatusState(
            status: InviteStatusLoadingStatus.loaded,
            inviteStatus: InviteStatus(
              canInvite: true,
              remaining: 2,
              total: 3,
              codes: [
                InviteCode(code: 'AB23-EF7K', claimed: false),
                InviteCode(code: 'HN4P-QR56', claimed: false),
              ],
            ),
          ),
        );
        await tester.pumpWidget(buildSubject());
        expect(find.text('AB23-EF7K'), findsOneWidget);
        expect(find.text('HN4P-QR56'), findsOneWidget);
        // Resolved from l10n, not hardcoded: this assertion should survive a
        // copy change and fail only if the widget stops reading from l10n.
        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.invitesShareWithPeople), findsOneWidget);
      });

      testWidgets('constrains menu content width on wide screens', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(900, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        when(() => mockCubit.state).thenReturn(
          const InviteStatusState(
            status: InviteStatusLoadingStatus.loaded,
            inviteStatus: InviteStatus(
              canInvite: true,
              remaining: 1,
              total: 1,
              codes: [InviteCode(code: 'AB23-EF7K', claimed: false)],
            ),
          ),
        );

        await tester.pumpWidget(buildSubject());

        final scrollViewWidth = tester
            .getSize(find.byType(CustomScrollView).first)
            .width;
        expect(scrollViewWidth, moreOrLessEquals(600));
      });

      testWidgets('generate invite action when capacity is available', (
        tester,
      ) async {
        when(() => mockCubit.state).thenReturn(
          const InviteStatusState(
            status: InviteStatusLoadingStatus.loaded,
            inviteStatus: InviteStatus(
              canInvite: true,
              remaining: 5,
              total: 5,
              codes: [],
            ),
          ),
        );
        await tester.pumpWidget(buildSubject());
        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.invitesGenerateButtonLabel), findsOneWidget);
        expect(find.text('No invites available right now'), findsNothing);
      });

      testWidgets('claimed codes section', (tester) async {
        when(() => mockCubit.state).thenReturn(
          const InviteStatusState(
            status: InviteStatusLoadingStatus.loaded,
            inviteStatus: InviteStatus(
              canInvite: true,
              remaining: 0,
              total: 1,
              codes: [
                InviteCode(
                  code: 'CCCC-DDDD',
                  claimed: true,
                  claimedBy: 'abc123',
                ),
              ],
            ),
          ),
        );
        await tester.pumpWidget(buildSubject());
        expect(find.text('CCCC-DDDD'), findsOneWidget);
        expect(find.text('Claimed'), findsOneWidget);
        expect(find.text('Used invites'), findsOneWidget);
      });

      testWidgets('retry button on error', (tester) async {
        when(() => mockCubit.state).thenReturn(
          const InviteStatusState(status: InviteStatusLoadingStatus.error),
        );
        await tester.pumpWidget(buildSubject());
        expect(find.text('Retry'), findsOneWidget);
        expect(find.text('Could not load invites'), findsOneWidget);
      });

      testWidgets('no generate card once every code has been minted', (
        tester,
      ) async {
        // remaining stays at 2 because nothing was redeemed, but both codes are
        // already minted. Offering the button here just earns a 429.
        when(() => mockCubit.state).thenReturn(
          const InviteStatusState(
            status: InviteStatusLoadingStatus.loaded,
            inviteStatus: InviteStatus(
              canInvite: true,
              remaining: 2,
              remainingToGenerate: 0,
              total: 2,
              codes: [
                InviteCode(code: 'AB23-EF7K', claimed: false),
                InviteCode(code: 'HN4P-QR56', claimed: false),
              ],
            ),
          ),
        );
        await tester.pumpWidget(buildSubject());
        final l10n = lookupAppLocalizations(const Locale('en'));

        expect(find.text(l10n.invitesGenerateButtonLabel), findsNothing);
        // The codes themselves are still listed and shareable.
        expect(find.text('AB23-EF7K'), findsOneWidget);
      });

      testWidgets('generate card counts mintable codes, not shareable ones', (
        tester,
      ) async {
        when(() => mockCubit.state).thenReturn(
          const InviteStatusState(
            status: InviteStatusLoadingStatus.loaded,
            inviteStatus: InviteStatus(
              canInvite: true,
              remaining: 10,
              remainingToGenerate: 3,
              total: 10,
              codes: [InviteCode(code: 'AB23-EF7K', claimed: false)],
            ),
          ),
        );
        await tester.pumpWidget(buildSubject());
        final l10n = lookupAppLocalizations(const Locale('en'));

        expect(find.text(l10n.invitesGenerateCardTitle(3)), findsOneWidget);
        expect(find.text(l10n.invitesGenerateCardTitle(10)), findsNothing);
      });

      testWidgets('generate card sits above the code list', (tester) async {
        // A full allocation of code cards used to push the button off-screen.
        when(() => mockCubit.state).thenReturn(
          InviteStatusState(
            status: InviteStatusLoadingStatus.loaded,
            inviteStatus: InviteStatus(
              canInvite: true,
              remaining: 10,
              remainingToGenerate: 4,
              total: 10,
              codes: List.generate(
                6,
                (i) => InviteCode(code: 'CODE-000$i', claimed: false),
              ),
            ),
          ),
        );
        await tester.pumpWidget(buildSubject());
        final l10n = lookupAppLocalizations(const Locale('en'));

        final buttonY = tester
            .getTopLeft(find.text(l10n.invitesGenerateButtonLabel))
            .dy;
        final firstCodeY = tester.getTopLeft(find.text('CODE-0000')).dy;
        expect(buttonY, lessThan(firstCodeY));
      });

      testWidgets('falls back to remaining when the server omits the field', (
        tester,
      ) async {
        when(() => mockCubit.state).thenReturn(
          const InviteStatusState(
            status: InviteStatusLoadingStatus.loaded,
            inviteStatus: InviteStatus(
              canInvite: true,
              remaining: 5,
              total: 5,
              codes: [],
            ),
          ),
        );
        await tester.pumpWidget(buildSubject());
        final l10n = lookupAppLocalizations(const Locale('en'));

        expect(find.text(l10n.invitesGenerateCardTitle(5)), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('tapping retry calls load', (tester) async {
        when(() => mockCubit.state).thenReturn(
          const InviteStatusState(status: InviteStatusLoadingStatus.error),
        );
        when(() => mockCubit.load()).thenAnswer((_) async {});
        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text('Retry'));
        verify(() => mockCubit.load()).called(1);
      });

      testWidgets('tapping generate invite creates a code', (tester) async {
        when(() => mockCubit.state).thenReturn(
          const InviteStatusState(
            status: InviteStatusLoadingStatus.loaded,
            inviteStatus: InviteStatus(
              canInvite: true,
              remaining: 5,
              total: 5,
              codes: [],
            ),
          ),
        );
        when(() => mockCubit.generateInvite()).thenAnswer((_) async {});

        await tester.pumpWidget(buildSubject());
        final l10n = lookupAppLocalizations(const Locale('en'));
        final generateButton = find.widgetWithText(
          DivineButton,
          l10n.invitesGenerateButtonLabel,
        );

        await tester.pump();
        await tester.ensureVisible(generateButton);
        await tester.tap(generateButton);
        await tester.pump();

        verify(() => mockCubit.generateInvite()).called(1);
      });
    });
  });
}
