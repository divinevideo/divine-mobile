// ABOUTME: Tests editable-draft DM sharing email confirmation feedback both
// ABOUTME: before opening the recipient picker and inside the confirm sheet.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/drafts_library/draft_dm_share_cubit.dart';
import 'package:openvine/blocs/email_confirmation/email_confirmation_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/library/draft_dm_share_sheet.dart';

class _MockEmailConfirmationCubit extends MockCubit<EmailConfirmationState>
    implements EmailConfirmationCubit {}

class _MockDraftDmShareCubit extends MockCubit<DraftDmShareState>
    implements DraftDmShareCubit {}

class _MockAuthService extends Mock implements AuthService {}

const _account =
    'a3c1e0b6f7d2948e5c1b0a9f8e7d6c5b4a3928170f6e5d4c3b2a19087f6e5d4c';
const _email = 'you@example.com';
const _draftId = 'draft-1';

void main() {
  group('draft DM share email confirmation', () {
    late _MockEmailConfirmationCubit confirmation;
    late _MockDraftDmShareCubit shareCubit;
    late _MockAuthService authService;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      confirmation = _MockEmailConfirmationCubit();
      shareCubit = _MockDraftDmShareCubit();
      authService = _MockAuthService();
      when(
        () => confirmation.resend(account: any(named: 'account')),
      ).thenAnswer((_) async {});
      when(() => shareCubit.state).thenReturn(DraftDmShareState.idle);
      when(() => shareCubit.send(any())).thenAnswer((_) async {});
      when(() => authService.currentPublicKeyHex).thenReturn(_account);
    });

    Widget buildConfirmationSheet({bool withConfirmation = true}) {
      Widget body = BlocProvider<DraftDmShareCubit>.value(
        value: shareCubit,
        child: const DraftDmShareConfirmation(draftId: _draftId),
      );
      if (withConfirmation) {
        body = BlocProvider<EmailConfirmationCubit>.value(
          value: confirmation,
          child: body,
        );
      }
      return MaterialApp(
        theme: VineTheme.theme,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: body),
      );
    }

    testWidgets(
      'showDraftDmShare stops before recipient selection when unconfirmed',
      (tester) async {
        when(() => confirmation.state).thenReturn(
          const EmailConfirmationState(
            account: _account,
            status: EmailConfirmationStatus.unconfirmed,
            email: _email,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [authServiceProvider.overrideWithValue(authService)],
            child: MaterialApp(
              theme: VineTheme.theme,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: BlocProvider<EmailConfirmationCubit>.value(
                value: confirmation,
                child: Scaffold(
                  body: Consumer(
                    builder: (context, ref, _) => DivineButton(
                      label: 'share-draft',
                      onPressed: () =>
                          unawaited(showDraftDmShare(context, ref, _draftId)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('share-draft'));
        await tester.pump();

        expect(find.text(l10n.emailConfirmationSendBlocked), findsOneWidget);
        verifyNever(() => authService.currentPublicKeyHex);
      },
    );

    testWidgets(
      'shows email confirmation feedback and scopes resend in confirm sheet',
      (tester) async {
        final states = StreamController<EmailConfirmationState>();
        addTearDown(states.close);
        const unconfirmed = EmailConfirmationState(
          account: _account,
          status: EmailConfirmationStatus.unconfirmed,
          email: _email,
          resendStatus: EmailConfirmationResendStatus.sent,
        );
        whenListen(confirmation, states.stream, initialState: unconfirmed);
        when(() => shareCubit.state).thenReturn(DraftDmShareState.blocked);

        await tester.pumpWidget(buildConfirmationSheet());

        // Email-specific feedback replaces generic DM block copy, and an old
        // resend outcome from before opening this sheet is not shown.
        expect(find.text(l10n.emailConfirmationSendBlocked), findsOneWidget);
        expect(find.text(l10n.dmSendBlockedMessage), findsNothing);
        expect(find.text(l10n.emailConfirmationResendSent), findsNothing);

        // Share action is disabled while email confirmation is required.
        await tester.tap(
          find.text(l10n.libraryDraftActionShare),
          warnIfMissed: false,
        );
        await tester.pump();
        verifyNever(() => shareCubit.send(any()));

        // Tapping resend scopes subsequent feedback to this open sheet.
        await tester.tap(find.text(l10n.emailConfirmationResendButton));
        states.add(
          unconfirmed.copyWith(
            resendStatus: EmailConfirmationResendStatus.failed,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.emailConfirmationResendFailed), findsOneWidget);
        verify(() => confirmation.resend(account: _account)).called(1);
      },
    );

    testWidgets(
      'keeps generic blocked copy when email is confirmed',
      (tester) async {
        when(() => confirmation.state).thenReturn(
          const EmailConfirmationState(
            account: _account,
            status: EmailConfirmationStatus.confirmed,
            email: _email,
          ),
        );
        when(() => shareCubit.state).thenReturn(DraftDmShareState.blocked);

        await tester.pumpWidget(buildConfirmationSheet());

        expect(find.text(l10n.dmSendBlockedMessage), findsOneWidget);
        expect(find.text(l10n.emailConfirmationSendBlocked), findsNothing);
      },
    );
  });
}
