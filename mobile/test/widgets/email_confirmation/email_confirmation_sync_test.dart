// ABOUTME: Tests EmailConfirmationSync: only Keycast email accounts are checked
// ABOUTME: for confirmation, and the cubit follows sign-in and sign-out.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/email_confirmation/email_confirmation_cubit.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/email_confirmation/email_confirmation_sync.dart';

class _MockEmailConfirmationCubit extends MockCubit<EmailConfirmationState>
    implements EmailConfirmationCubit {}

class _MockAuthService extends Mock implements AuthService {}

const _account =
    'a3c1e0b6f7d2948e5c1b0a9f8e7d6c5b4a3928170f6e5d4c3b2a19087f6e5d4c';

void main() {
  group(EmailConfirmationSync, () {
    late _MockEmailConfirmationCubit cubit;
    late _MockAuthService authService;
    late StreamController<AuthState> authStates;

    setUp(() {
      cubit = _MockEmailConfirmationCubit();
      when(() => cubit.state).thenReturn(const EmailConfirmationState());
      when(() => cubit.loadFor(any())).thenAnswer((_) async {});
      when(() => cubit.refresh()).thenAnswer((_) async {});
      when(() => cubit.markUnconfirmedByKeycast(any()))
          .thenAnswer((_) async {});
      authService = _MockAuthService();
      authStates = StreamController<AuthState>.broadcast();
      addTearDown(authStates.close);
      when(() => authService.authStateStream)
          .thenAnswer((_) => authStates.stream);
      when(() => authService.currentPublicKeyHex).thenReturn(_account);
    });

    Widget buildSubject() => ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(authService)],
      child: BlocProvider<EmailConfirmationCubit>.value(
        value: cubit,
        child: const EmailConfirmationSync(child: SizedBox()),
      ),
    );

    testWidgets('checks a signed-in Keycast email account', (tester) async {
      when(() => authService.authState).thenReturn(AuthState.authenticated);
      when(
        () => authService.authenticationSource,
      ).thenReturn(AuthenticationSource.divineOAuth);

      await tester.pumpWidget(buildSubject());

      verify(() => cubit.loadFor(_account)).called(1);
    });

    testWidgets('points accounts with a local key at nobody', (tester) async {
      when(() => authService.authState).thenReturn(AuthState.authenticated);
      when(
        () => authService.authenticationSource,
      ).thenReturn(AuthenticationSource.importedKeys);

      await tester.pumpWidget(buildSubject());

      verify(() => cubit.loadFor(null)).called(1);
      verifyNever(() => cubit.loadFor(_account));
    });

    testWidgets('routes Keycast refusals to the cubit', (tester) async {
      when(() => authService.authState).thenReturn(AuthState.authenticated);
      when(
        () => authService.authenticationSource,
      ).thenReturn(AuthenticationSource.divineOAuth);
      await tester.pumpWidget(buildSubject());

      final rpc = KeycastRpc(
        nostrApi: 'https://login.divine.video/api/nostr',
        accessToken: 'token',
        owner: _account,
        httpClient: MockClient(
          (_) async => http.Response(
            '{"error":"limit","code":"UNCONFIRMED_RATE_LIMITED"}',
            429,
          ),
        ),
      );
      await expectLater(
        rpc.getPublicKey,
        throwsA(isA<UnconfirmedRateLimitedException>()),
      );
      await tester.pump();

      verify(() => cubit.reportCapReached(_account)).called(1);
    });

    testWidgets('forgets the account on sign-out', (tester) async {
      when(() => authService.authState).thenReturn(AuthState.authenticated);
      when(
        () => authService.authenticationSource,
      ).thenReturn(AuthenticationSource.divineOAuth);
      await tester.pumpWidget(buildSubject());
      verify(() => cubit.loadFor(_account)).called(1);

      when(() => authService.authState).thenReturn(AuthState.unauthenticated);
      authStates.add(AuthState.unauthenticated);
      await tester.pumpAndSettle();

      verify(() => cubit.loadFor(null)).called(1);
    });
  });
}
