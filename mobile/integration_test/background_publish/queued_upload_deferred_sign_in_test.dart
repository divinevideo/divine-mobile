// ABOUTME: E2E for #9604: signing in again from an expired session while one
// ABOUTME: video uploads and a second waits must not leave until both finish.
// ABOUTME: Requires: local Docker stack (mise run local_up)

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/video_publish/video_publish_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../helpers/constants.dart';
import '../helpers/db_helpers.dart';
import '../helpers/held_upload_proxy.dart';
import '../helpers/http_helpers.dart';
import '../helpers/navigation_helpers.dart';
import '../helpers/relay_helpers.dart' show queryRelay;
import '../helpers/test_setup.dart';

void main() {
  // A plain suite, so it stays out of integration_test/auth/: `mise run
  // e2e_test` runs that directory as one patrol bundle, which installs
  // PatrolBinding first, and this second binding would abort the whole bundle.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Deferred sign-in behind a queued upload', () {
    testWidgets(
      'opens login options only after the queued upload finishes',
      (tester) async {
        await runWithAppErrorHandlers(() async {
          await _postTwoVideosThenSignInAgain(tester);
          drainAsyncErrors(tester);
        });
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  });
}

Future<void> _postTwoVideosThenSignInAgain(WidgetTester tester) async {
  final runTag = DateTime.now().millisecondsSinceEpoch;

  // Every video transfer passes through this proxy on its way to the real
  // local Blossom server; the test decides when each one lands.
  final proxy = await HeldUploadProxy.start(
    upstream: Uri.parse('http://$localHost:$localBlossomPort'),
  );
  addTearDown(proxy.close);

  launchAppGuarded(app.main);
  expect(
    await waitForWidget(tester, find.byType(MaterialApp), maxSeconds: 60),
    isTrue,
    reason: 'App should start',
  );

  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  final authService = container.read(authServiceProvider);
  final router = container.read(goRouterProvider);

  final pubkey = await _signInWithAnExpiredSession(
    tester,
    container,
    email: 'queued-upload-$runTag@test.divine.video',
  );

  // Local builds must upload to the local stack, through the proxy.
  final blossom = container.read(blossomUploadServiceProvider);
  await blossom.setBlossomEnabled(true);
  await blossom.setBlossomServer(proxy.baseUrl);
  addTearDown(
    () => blossom.setBlossomServer('http://$localHost:$localBlossomPort'),
  );

  final draftA = await _saveRenderedDraft(container, 'A', runTag);
  final draftB = await _saveRenderedDraft(container, 'B', runTag);

  final rootContext = NavigatorKeys.root.currentContext!;
  final publishBloc = rootContext.read<BackgroundPublishBloc>();
  final publisher = container.read(videoPublishProvider.notifier);

  final loginNavigations = <_LoginNavigation>[];
  var lastLocation = _location(router);
  void onRouteChanged() {
    final location = _location(router);
    if (location == lastLocation) return;
    lastLocation = location;
    final queued = proxy.uploads.length > 1 ? proxy.uploads[1] : null;
    final inFlight = _inFlight(publishBloc.state);
    logPhase(
      'Route -> $location | queued upload: ${_describe(queued)} '
      '| bloc in flight: $inFlight',
    );
    if (location == WelcomeScreen.loginOptionsPath) {
      loginNavigations.add(
        _LoginNavigation(
          queuedUploadHeld: queued != null && !queued.isReleased,
          queuedUploadAnswered: queued?.isAnswered ?? false,
          blocInFlight: inFlight,
        ),
      );
    }
  }

  router.routerDelegate.addListener(onRouteChanged);
  addTearDown(() => router.routerDelegate.removeListener(onRouteChanged));
  final blocLog = publishBloc.stream.listen(
    (state) => logPhase('Bloc in flight: ${_inFlight(state)}'),
  );
  addTearDown(blocLog.cancel);

  // ── Post A: its transfer is held, so A stays in flight ──────────────────
  final publishA = publisher.publishVideo(rootContext, draftA);
  final uploadA = await _awaitWhilePumping(
    tester,
    proxy.arrival(0),
    what: "upload A's video transfer",
  );

  // Posting lands on the profile, which asks the expired session to sign in.
  // Put it off for now, as someone about to post another video would.
  final l10n = lookupAppLocalizations(const Locale('en'));
  await _tapWhenReachable(
    tester,
    find.text(l10n.profileMaybeLaterLabel),
    what: "the expired session's sign-in prompt on the profile",
  );
  await _pumpUntil(
    tester,
    () =>
        container.read(videoPublishProvider).publishState !=
        VideoPublishState.preparing,
    what: 'the Post action to accept another video',
  );

  // ── Post B while A is still uploading: B queues behind A ────────────────
  final publishB = publisher.publishVideo(rootContext, draftB);
  final uploadB = await _awaitWhilePumping(
    tester,
    proxy.arrival(1),
    what: "upload B's video transfer",
  );
  logPhase(
    'Both transfers held | bloc in flight: ${_inFlight(publishBloc.state)}',
  );

  // ── Sign in again from Settings while both are unfinished ───────────────
  await _tapWhenReachable(
    tester,
    find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.identifier == SemanticIds.profileSettingsButton,
    ),
    what: "the profile's Settings gear",
  );
  await _tapWhenReachable(
    tester,
    find.descendant(
      of: find.byType(SettingsScreen),
      matching: find.text(l10n.settingsSessionExpired),
    ),
    what: "Settings' expired-session row",
  );
  // Resolves only after the tap's own refresh has failed: it either shares
  // that in-flight attempt or starts after it. By then Settings has handed
  // the navigation to the deferred navigator.
  final refreshed = await _awaitWhilePumping(
    tester,
    authService.tryRefreshExpiredSession(),
    what: 'the expired-session refresh',
  );
  expect(refreshed, isFalse, reason: 'The refresh tokens were consumed');
  await pumpUntilSettled(tester, maxSeconds: 2);
  expect(
    _location(router),
    SettingsScreen.path,
    reason: 'Both uploads are unfinished, so sign-in must wait',
  );
  // The wait for upload A to finish publishing below relies on this.
  expect(
    _isInFlight(publishBloc.state, draftA),
    isTrue,
    reason: 'Upload A is held, so the bloc must still count it in flight',
  );

  // ── Let A finish while B is still uploading ─────────────────────────────
  uploadA.release();
  expect(
    await _awaitWhilePumping(
      tester,
      uploadA.answered,
      what: "upload A's server response",
    ),
    inInclusiveRange(200, 299),
  );
  await _pumpUntil(
    tester,
    () => !_isInFlight(publishBloc.state, draftA),
    what: 'upload A to finish publishing',
  );
  logPhase('Upload A finished; holding upload B for a settle window');
  await pumpUntilSettled(tester, maxSeconds: 3);

  // ── Let B finish ────────────────────────────────────────────────────────
  uploadB.release();
  expect(
    await _awaitWhilePumping(
      tester,
      uploadB.answered,
      what: "upload B's server response",
    ),
    inInclusiveRange(200, 299),
  );
  await _pumpUntil(
    tester,
    () => _location(router) == WelcomeScreen.loginOptionsPath,
    what: 'the deferred sign-in to open login options',
  );
  await _awaitWhilePumping(tester, publishA, what: 'post A to return');
  await _awaitWhilePumping(tester, publishB, what: 'post B to return');

  // Both videos really went out, so the wait was for real uploads.
  final titles = await _publishedVideoTitles(pubkey, expected: 2);
  expect(titles, containsAll([draftA.title, draftB.title]));

  expect(
    loginNavigations,
    hasLength(1),
    reason: 'Login options should open exactly once',
  );
  final navigation = loginNavigations.single;
  expect(
    navigation.queuedUploadHeld,
    isFalse,
    reason:
        'Login options opened while upload B, queued behind A, was still '
        'being uploaded (#9604)',
  );
  expect(navigation.queuedUploadAnswered, isTrue);
  expect(
    navigation.blocInFlight,
    isEmpty,
    reason: 'No upload may still be in flight when sign-in navigates',
  );
}

/// Signs in a local key secured with Keycast, then expires the OAuth session
/// so that signing in again cannot silently refresh it. Returns the pubkey.
///
/// This is the "started anonymous, then secured" account: once the session
/// expires it keeps signing with the local key, so it can still post.
Future<String> _signInWithAnExpiredSession(
  WidgetTester tester,
  ProviderContainer container, {
  required String email,
}) async {
  const password = 'TestPass123!';
  final authService = container.read(authServiceProvider);
  final nsec = Nip19.encodePrivateKey(generatePrivateKey());
  final keyContainer = await tester.runAsync(
    () => container.read(secureKeyStorageProvider).importFromNsec(nsec),
  );
  final pubkey = keyContainer!.publicKeyHex;

  final oauthClient = container.read(oauthClientProvider);
  final (registerResult, verifier) = (await tester.runAsync(
    () => oauthClient.headlessRegister(
      email: email,
      password: password,
      nsec: nsec,
      scope: 'policy:full',
    ),
  ))!;
  expect(registerResult.success, isTrue, reason: 'Keycast registration');
  await callVerifyEmail(await getVerificationToken(email));

  String? authCode;
  for (var i = 0; i < 30 && authCode == null; i++) {
    final poll = await tester.runAsync(
      () => oauthClient.pollForCode(registerResult.deviceCode!),
    );
    authCode = poll!.code;
    if (authCode == null) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }
  expect(authCode, isNotNull, reason: 'Keycast should issue a code');
  final tokens = await tester.runAsync(
    () => oauthClient.exchangeCode(code: authCode!, verifier: verifier),
  );
  await tester.runAsync(
    () => authService.signInWithDivineOAuth(
      KeycastSession.fromTokenResponse(tokens!),
    ),
  );
  await pumpUntilSettled(tester);
  expect(authService.authenticationSource, AuthenticationSource.divineOAuth);
  expect(authService.currentPublicKeyHex, pubkey);
  logPhase('Signed in via Keycast: pubkey=$pubkey');

  final secureStorage = container.read(flutterSecureStorageProvider);
  final session = await KeycastSession.load(secureStorage);
  await session!
      .copyWith(expiresAt: DateTime.now().subtract(const Duration(hours: 1)))
      .save(secureStorage);
  expect(
    await consumeAllRefreshTokens(pubkey),
    greaterThan(0),
    reason: 'A live refresh token would let signing in again succeed',
  );
  await authService.initialize();
  await pumpUntilSettled(tester, maxSeconds: 10);
  expect(authService.hasExpiredOAuthSession, isTrue);
  expect(
    authService.isAuthenticated,
    isTrue,
    reason: 'The local key keeps the account signed in and able to post',
  );
  return pubkey;
}

/// What the app looked like at the moment it navigated to login options.
class _LoginNavigation {
  const _LoginNavigation({
    required this.queuedUploadHeld,
    required this.queuedUploadAnswered,
    required this.blocInFlight,
  });

  final bool queuedUploadHeld;
  final bool queuedUploadAnswered;
  final List<String> blocInFlight;
}

/// The top-most route. A pushed route such as Settings does not change the
/// router's base location, so read the state of the route on top instead.
String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.isEmpty
    ? ''
    : router.state.uri.path;

/// Source draft ids the bloc still counts as unfinished.
List<String> _inFlight(BackgroundPublishState state) => [
  for (final upload in state.uploads)
    if (upload.result == null) upload.draft.sourceDraftId ?? upload.draft.id,
];

bool _isInFlight(BackgroundPublishState state, DivineVideoDraft source) =>
    _inFlight(state).contains(source.id);

String _describe(HeldUpload? upload) => switch (upload) {
  null => 'none',
  HeldUpload(isAnswered: true) => 'answered',
  HeldUpload(isReleased: true) => 'released',
  _ => 'held',
};

/// Saves a one-clip draft whose final render is already on disk, the state
/// the editor leaves a draft in when the user reaches Post.
///
/// Each render is the bundled intro clip plus a trailing ISO-BMFF `free` box,
/// which players skip, so every draft uploads a distinct blob.
Future<DivineVideoDraft> _saveRenderedDraft(
  ProviderContainer container,
  String label,
  int runTag,
) async {
  final intro = await rootBundle.load('assets/videos/default_intro.mp4');
  final documents = await getApplicationDocumentsDirectory();
  final render = File('${documents.path}/queued_upload_${label}_$runTag.mp4');
  await render.writeAsBytes([
    ...intro.buffer.asUint8List(),
    ..._freeBox('divine e2e queued upload $label $runTag'),
  ]);

  final clip = DivineVideoClip(
    id: 'queued_upload_clip_${label}_$runTag',
    video: EditorVideo.file(render.path),
    duration: const Duration(seconds: 3),
    recordedAt: DateTime.now(),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 320 / 240,
  );
  final draft = DivineVideoDraft.create(
    id: 'queued_upload_draft_${label}_$runTag',
    clips: [clip],
    title: 'Queued upload $label $runTag',
    description: 'Posted by the queued-upload sign-in E2E',
    hashtags: const {},
    selectedApproach: 'video',
    finalRenderedClip: clip,
  );
  await container.read(draftStorageServiceProvider).saveDraft(draft);
  return draft;
}

List<int> _freeBox(String payload) {
  final body = utf8.encode(payload);
  final size = 8 + body.length;
  return [
    (size >> 24) & 0xff,
    (size >> 16) & 0xff,
    (size >> 8) & 0xff,
    size & 0xff,
    ...ascii.encode('free'),
    ...body,
  ];
}

/// Titles of the kind 34236 videos [pubkey] has on the local relay, polled
/// until at least [expected] have arrived.
Future<Set<String>> _publishedVideoTitles(
  String pubkey, {
  required int expected,
}) async {
  var titles = <String>{};
  for (var attempt = 0; attempt < 30; attempt++) {
    final events = await queryRelay({
      'kinds': [34236],
      'authors': [pubkey],
    });
    titles = {
      for (final event in events)
        for (final tag in event.tags)
          if (tag.length > 1 && tag.first == 'title') tag[1],
    };
    if (titles.length >= expected) break;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  return titles;
}

/// Awaits [future] while pumping frames, so the app keeps running.
Future<T> _awaitWhilePumping<T>(
  WidgetTester tester,
  Future<T> future, {
  required String what,
  Duration timeout = const Duration(seconds: 90),
}) async {
  var done = false;
  T? value;
  Object? error;
  StackTrace? stackTrace;
  unawaited(
    future.then(
      (result) {
        value = result;
        done = true;
      },
      onError: (Object e, StackTrace s) {
        error = e;
        stackTrace = s;
        done = true;
      },
    ),
  );
  await _pumpUntil(tester, () => done, what: what, timeout: timeout);
  if (error != null) Error.throwWithStackTrace(error!, stackTrace!);
  return value as T;
}

/// Taps [finder] once it is on screen and nothing covers it. A sheet or a
/// route still animating in has the widget in the tree, but a tap there
/// lands off screen or on a modal barrier.
Future<void> _tapWhenReachable(
  WidgetTester tester,
  Finder finder, {
  required String what,
}) async {
  final reachable = finder.hitTestable();
  await _pumpUntil(
    tester,
    () => reachable.evaluate().isNotEmpty,
    what: what,
    timeout: const Duration(seconds: 20),
  );
  await tester.tap(reachable.first);
  await tester.pump();
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String what,
  Duration timeout = const Duration(seconds: 90),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out after ${timeout.inSeconds}s waiting for $what');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}
