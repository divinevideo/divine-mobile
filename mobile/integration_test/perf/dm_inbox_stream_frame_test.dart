// ABOUTME: #7923 — what the unpaginated Messages streams cost the UI isolate on
// ABOUTME: a heavy DM account, and whether a burst of conversation writes
// ABOUTME: drops frames with the inbox closed and open.
//
// Since #6286 the inbox watches the COMPLETE accepted set and windows it
// client-side, so every conversations-table write re-delivers every row.
// Everything below the UI is the production stack: an encrypted Drift
// database on its background isolate (`openEncryptedConnection`), the real
// DAOs, `DmRepository`, `ContentBlocklistRepository`, `ConversationListBloc`
// and `DmUnreadCountCubit` with their default 200 ms debounce. Only the
// `NostrClient` (never reached) and `FollowRepository` (a plain fake, so a
// mock's dispatch cost is not mistaken for the app's) are stand-ins.
//
// Two measurements per account size and blocklist variant, and a third per
// size:
//
// * The ladder adds one layer at a time — writes alone, raw DAO watches,
//   repository watches (row -> DmConversation mapping, before any debounce),
//   then the badge cubit alone and the bloc with it — and records the longest
//   uninterrupted stretch of UI-isolate work during a write burst. A frame
//   cannot start while that stretch runs, so it is the number that decides
//   jank. The "x4" steps keep the pre-#7923 shape, list and badge both on
//   every row, as the baseline; the step after them is the shape since then.
// * The frame trace renders a list that selects `visibleConversations` the
//   way `InboxView` does, under a continuously running animation, and counts
//   over-budget frames for an idle baseline, a burst, and a trickle.
// * The synchronous recompute pieces, classify + mergeAndSort and the state
//   equality check, are timed alone.
//
// Run in profile mode on a device; debug and host numbers are relative only:
//   flutter drive --profile --driver=test_driver/integration_test.dart \
//     --target=integration_test/perf/dm_inbox_stream_frame_test.dart -d <id>

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';

class _MockNostrClient extends Mock implements NostrClient {}

/// Follow state the bloc and cubit read on every recompute. A set lookup is
/// cheaper than the real repository's list scan, so classifying requests here
/// costs less than it does on a long follow list.
class _FakeFollowRepository extends Fake implements FollowRepository {
  _FakeFollowRepository(this._following);

  final Set<String> _following;

  @override
  Stream<List<String>> get followingStream => const Stream.empty();

  @override
  List<String> get followingPubkeys => List.unmodifiable(_following);

  @override
  bool isFollowing(String pubkey) => _following.contains(pubkey);
}

const _accountSizes = [100, 1000, 5000];

/// The size the pass/fail bar is applied at (#7923 Gate A); the others are
/// reported only.
const _gatedSize = 1000;

/// A single UI-isolate stall this long fails a gated window, whatever its
/// dropped-frame count says.
const _frozenUiStallMs = 100.0;

/// Conversation writes in one burst, issued as fast as Drift accepts them:
/// the shape of a post-reinstall history drain landing rows one by one.
const _burstWrites = 200;

/// One write per second for this long: ordinary incoming messages.
const _trickleSeconds = 10;

/// Pubkeys blocked in the blocklist variant. Half are 1:1 peers, half are
/// members of group threads whose last message they sent, so the list's
/// hidden-member pass (#10150) has rows to re-read on every recompute. Those
/// groups are seeded read, so the unread-only badge reaches one only after a
/// write marks it unread.
const _blockedPubkeys = 20;

const _owner =
    'a4f5c1b2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8';

String _pubkey(int i) => i.toRadixString(16).padLeft(64, '0');

String _hex(Random rng, int bytes) => [
  for (var i = 0; i < bytes; i++) rng.nextInt(256).toRadixString(16),
].map((b) => b.padLeft(2, '0')).join();

enum _Variant { plain, blocked }

/// An account of [size] conversations in a real encrypted database.
class _Account {
  _Account._(this.size, this.variant, this._dir, this.db, this.rng);

  final int size;
  final _Variant variant;
  final Directory _dir;
  final AppDatabase db;
  final Random rng;

  late final ConversationsDao conversations = ConversationsDao(db);
  late final DirectMessagesDao messages = DirectMessagesDao(db);
  late final DmRepository repository = DmRepository(
    nostrClient: _MockNostrClient(),
    directMessagesDao: messages,
    conversationsDao: conversations,
    userPubkey: _owner,
  );
  final ContentBlocklistRepository blocklist = ContentBlocklistRepository();
  late final _FakeFollowRepository follows;

  final _rows =
      <
        ({String id, List<String> participants, bool isGroup, bool seededRead})
      >[];
  final _touched = <String>{};
  var _clock = 1700000000;

  static Future<_Account> open(int size, _Variant variant) async {
    final dir = Directory.systemTemp.createTempSync('dm_inbox_perf_');
    final rng = Random(7923 + size + variant.index);
    final db = AppDatabase(
      openEncryptedConnection(
        rawKeyHex: _hex(rng, 32),
        databasePath: '${dir.path}/perf.sqlite',
      ),
    );
    final account = _Account._(size, variant, dir, db, rng);
    try {
      await account._seed();
    } on Object {
      // Cleanup is best effort; the seed's own error is the one to report.
      await account.close().onError((_, _) {});
      rethrow;
    }
    return account;
  }

  /// 85% accepted, 15% potential requests (two thirds from followed accounts),
  /// one in ten a group of three to five, one in ten unread.
  Future<void> _seed() async {
    final following = <String>{};
    await db.transaction(() async {
      for (var i = 0; i < size; i++) {
        final isGroup = i % 10 == 3;
        final peers = [
          for (var p = 0; p < (isGroup ? 2 + i % 3 : 1); p++)
            _pubkey(10000 + i * 7 + p),
        ];
        final accepted = i % 20 >= 3;
        if (!accepted && i.isEven) following.addAll(peers);
        final participants = [_owner, ...peers]..sort();
        final id = DmRepository.computeConversationId(participants);
        _rows.add((
          id: id,
          participants: participants,
          isGroup: isGroup,
          seededRead: i % 10 != 0,
        ));
        await conversations.upsertConversation(
          id: id,
          participantPubkeys: _json(participants),
          isGroup: isGroup,
          createdAt: _clock,
          lastMessageContent: 'message ${_hex(rng, 24)}',
          lastMessageTimestamp: _clock + i,
          lastMessageSenderPubkey: peers.first,
          isRead: i % 10 != 0,
          currentUserHasSent: accepted,
          ownerPubkey: _owner,
        );
      }
    });
    follows = _FakeFollowRepository(following);
    _clock += size;
    if (variant == _Variant.blocked) await _block();
  }

  Future<void> _block() async {
    final blocked = <String>[];
    final groups = _rows.where((r) => r.isGroup).take(_blockedPubkeys ~/ 2);
    for (final group in groups) {
      final member = group.participants.firstWhere((p) => p != _owner);
      blocked.add(member);
      // The hidden member wrote last, so the row reads through #10150's
      // visible-activity query, which needs a visible message to fall back to.
      final visible = group.participants.lastWhere((p) => p != _owner);
      await messages.insertMessage(
        id: _hex(rng, 32),
        conversationId: group.id,
        senderPubkey: visible,
        content: 'visible ${_hex(rng, 12)}',
        createdAt: _clock - 1,
        giftWrapId: _hex(rng, 32),
        ownerPubkey: _owner,
      );
    }
    final oneToOnes = _rows.where((r) => !r.isGroup).take(_blockedPubkeys ~/ 2);
    blocked.addAll(
      oneToOnes.map((r) => r.participants.firstWhere((p) => p != _owner)),
    );
    await blocklist.blockUsers(blocked, ourPubkey: _owner);
  }

  /// A new message in a random existing conversation, as ingest writes it.
  Future<void> write() {
    final row = _rows[rng.nextInt(_rows.length)];
    _touched.add(row.id);
    _clock++;
    return conversations.upsertConversation(
      id: row.id,
      participantPubkeys: _json(row.participants),
      isGroup: row.isGroup,
      createdAt: 1700000000,
      lastMessageContent: 'message ${_hex(rng, 24)}',
      lastMessageTimestamp: _clock,
      lastMessageSenderPubkey: row.participants.firstWhere((p) => p != _owner),
      isRead: false,
      ownerPubkey: _owner,
      isNewMessage: true,
    );
  }

  /// Marks read again the seeded-read rows written since the last call, so
  /// every ladder step starts from the seeded unread set.
  Future<void> restoreSeededReadState() async {
    final ids = [
      for (final row in _rows)
        if (row.seededRead && _touched.contains(row.id)) row.id,
    ];
    _touched.clear();
    await conversations.markMultipleAsRead(ids, ownerPubkey: _owner);
  }

  Future<void> close() async {
    try {
      await repository.stopListening();
      blocklist.dispose();
      await db.close();
    } finally {
      _dir.deleteSync(recursive: true);
    }
  }

  static String _json(List<String> pubkeys) =>
      '[${pubkeys.map((p) => '"$p"').join(',')}]';
}

/// Records how long the UI isolate went without servicing a 1 ms timer.
///
/// Each gap beyond the timer period is time some synchronous task held the
/// isolate; nothing else, a frame included, could run during it.
class _StallSampler {
  final _gapsMicros = <int>[];
  final _watch = Stopwatch();
  Timer? _timer;
  int _last = 0;

  void start() {
    _watch.start();
    _last = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
      final now = _watch.elapsedMicroseconds;
      _gapsMicros.add(now - _last);
      _last = now;
    });
  }

  /// Stops sampling; safe to call more than once.
  void cancel() {
    _timer?.cancel();
    _watch.stop();
  }

  ({double maxMs, double over8Ms, int over8, int over16}) stop() {
    cancel();
    final gaps = _gapsMicros.map((g) => g / 1000).toList();
    return (
      maxMs: gaps.fold(0, max),
      over8Ms: gaps.where((g) => g > 8.33).fold(0, (a, g) => a + g),
      over8: gaps.where((g) => g > 8.33).length,
      over16: gaps.where((g) => g > 16.67).length,
    );
  }
}

/// Records every error a bloc or cubit reports. Bloc's default observer drops
/// them, and a window timed over a failing recompute measures nothing.
class _ErrorRecorder extends BlocObserver {
  final errors = <Object>[];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

/// Waits until [badge] has counted the seed, which leaves every account with
/// unread rows. Its stream does not replay, so a count that landed before
/// this call is read from its state.
Future<void> _counted(DmUnreadCountCubit badge) async {
  if (badge.state > 0) return;
  await badge.stream
      .firstWhere((count) => count > 0)
      .timeout(const Duration(seconds: 30));
}

/// Lets queued emissions and the 200 ms debounce run out after a phase.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 600));

Future<void> _burst(_Account account) async {
  for (var i = 0; i < _burstWrites; i++) {
    await account.write();
  }
}

Future<void> _trickle(_Account account) async {
  for (var i = 0; i < _trickleSeconds; i++) {
    await account.write();
    // Real-time pacing for the trickle, not synchronisation.
    await Future<void>.delayed(const Duration(seconds: 1));
  }
}

String _fmt(double v) => v.toStringAsFixed(2);

/// The inbox's rebuild shape: the list selects `visibleConversations`, whose
/// identity changes on every emitted recompute.
class _InboxCanary extends StatelessWidget {
  const _InboxCanary();

  @override
  Widget build(BuildContext context) => _Canary(
    rows: context.select(
      (ConversationListBloc bloc) => bloc.state.visibleConversations,
    ),
  );
}

/// Any other screen, the video feed say: rows that never change, while the
/// app-shell badge keeps listening to the DM tables underneath.
class _FeedCanary extends StatelessWidget {
  const _FeedCanary(this.rows);

  final List<DmConversation> rows;

  @override
  Widget build(BuildContext context) => _Canary(rows: rows);
}

/// An animated list that keeps frames running the way a scroll would.
class _Canary extends StatefulWidget {
  const _Canary({required this.rows});

  final List<DmConversation> rows;

  @override
  State<_Canary> createState() => _CanaryState();
}

class _CanaryState extends State<_Canary> with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: AnimatedBuilder(
          animation: _motion,
          builder: (context, _) => ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) => _Row(
              conversation: rows[i],
              phase: (_motion.value + i / 20) % 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.conversation, required this.phase});

  final DmConversation conversation;
  final double phase;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: 0.4 + 0.6 * phase,
    child: ListTile(
      title: Text(conversation.participantPubkeys.last, maxLines: 1),
      subtitle: Text(conversation.lastMessageContent ?? '', maxLines: 1),
      trailing: Text('${conversation.lastMessageTimestamp}'),
    ),
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // FrameTimings arrive in batches up to ~100 ms late, so they cannot say
  // which frames a window drew. A persistent frame callback runs in each frame
  // as it is built.
  var framesBegun = 0;
  binding.addPersistentFrameCallback((_) => framesBegun++);
  final results = <String, Object>{};
  final report = StringBuffer();
  final blocErrors = _ErrorRecorder();
  final previousObserver = Bloc.observer;

  setUpAll(() => Bloc.observer = blocErrors);
  setUp(blocErrors.errors.clear);
  tearDownAll(() {
    Bloc.observer = previousObserver;
    binding.reportData = results;
    // One line at a time: the iOS console truncates a long single message.
    // This benchmark's result is a human-readable console report.
    // ignore: avoid_print
    report.toString().split('\n').forEach(print);
  });

  group('inbox stream cost (#7923)', () {
    for (final size in _accountSizes) {
      for (final variant in _Variant.values) {
        test('ladder N=$size ${variant.name}', () async {
          final account = await _Account.open(size, variant);
          addTearDown(account.close);

          Future<Map<String, double>> phase(
            String layer, {
            DmUnreadCountCubit? badge,
            ConversationListBloc? list,
          }) async {
            await _settle();
            var badgeUpdates = 0;
            var listUpdates = 0;
            final watchers = <StreamSubscription<Object?>>[
              ?badge?.stream.listen((_) => badgeUpdates++),
              ?list?.stream
                  .where((s) => s.status == ConversationListStatus.loaded)
                  .listen((_) => listUpdates++),
            ];
            final sampler = _StallSampler()..start();
            final wall = Stopwatch()..start();
            try {
              await _burst(account);
              await _settle();
              wall.stop();
            } finally {
              sampler.cancel();
              for (final watcher in watchers) {
                await watcher.cancel();
              }
            }
            final s = sampler.stop();
            await account.restoreSeededReadState();
            report.writeln(
              'N=$size ${variant.name} $layer: '
              'longest stall=${_fmt(s.maxMs)}ms '
              'stalls>8.33ms=${s.over8} (${_fmt(s.over8Ms)}ms) '
              '>16.67ms=${s.over16} burst+settle=${wall.elapsedMilliseconds}ms '
              'badge updates=$badgeUpdates list updates=$listUpdates',
            );
            if (badge != null) {
              expect(
                badgeUpdates,
                greaterThan(0),
                reason: '$layer: the burst must reach the badge',
              );
            }
            if (list != null) {
              expect(
                listUpdates,
                greaterThan(0),
                reason: '$layer: the burst must reach the list',
              );
              expect(
                list.state.status,
                equals(ConversationListStatus.loaded),
                reason: '$layer: the list must still be composing',
              );
            }
            return {
              'maxStallMs': s.maxMs,
              'over8': s.over8.toDouble(),
              'over16': s.over16.toDouble(),
            };
          }

          final ladder = <String, Map<String, double>>{};
          final subscriptions = <StreamSubscription<Object?>>[];
          Future<void> cancelAll() async {
            for (final s in subscriptions) {
              await s.cancel();
            }
            subscriptions.clear();
          }

          // Same SQL as the repository's watches: Drift shares one query
          // between identical watchers, so this is the row transfer alone.
          void attachDaoWatches() {
            for (var i = 0; i < 2; i++) {
              subscriptions
                ..add(
                  account.conversations
                      .watchAcceptedConversations(ownerPubkey: _owner)
                      .listen((_) {}),
                )
                ..add(
                  account.conversations
                      .watchPotentialRequestConversations(ownerPubkey: _owner)
                      .listen((_) {}),
                );
            }
          }

          // The pre-#7923 shape: the list and the badge both watch every row,
          // two streams each, and each maps every row before its debounce.
          void attachRepositoryWatches() {
            for (var i = 0; i < 2; i++) {
              subscriptions
                ..add(
                  account.repository.watchAcceptedConversations().listen(
                    (_) {},
                  ),
                )
                ..add(
                  account.repository.watchPotentialRequests().listen((_) {}),
                );
            }
          }

          ladder['writes'] = await phase('writes');

          // The control flips only the row mapping: raw rows, mapped rows,
          // raw again, mapped again. A cost that follows the mapping shows up
          // in the second and fourth phases and not in the third.
          attachDaoWatches();
          ladder['daoWatches'] = await phase('dao watches x4');
          await cancelAll();
          attachRepositoryWatches();
          ladder['repoWatches'] = await phase('repository watches x4');
          await cancelAll();
          attachDaoWatches();
          ladder['daoWatchesAgain'] = await phase('dao watches x4 (again)');
          await cancelAll();
          attachRepositoryWatches();
          ladder['repoWatchesAgain'] = await phase(
            'repository watches x4 (again)',
          );
          await cancelAll();

          // The shape since #7923: the list watches every row, the badge only
          // the unread ones.
          subscriptions.addAll([
            account.repository.watchAcceptedConversations().listen((_) {}),
            account.repository.watchPotentialRequests().listen((_) {}),
            account.repository
                .watchAcceptedConversations(unreadOnly: true)
                .listen((_) {}),
            account.repository
                .watchPotentialRequests(unreadOnly: true)
                .listen((_) {}),
          ]);
          ladder['repoWatchesUnreadBadge'] = await phase(
            'repository watches, list full + badge unread-only',
          );
          await cancelAll();

          // The inbox closed: the app-shell badge is the only listener, as it
          // is on every other screen.
          final badgeAlone = DmUnreadCountCubit(
            dmRepository: account.repository,
            followRepository: account.follows,
            contentBlocklistRepository: account.blocklist,
          );
          addTearDown(badgeAlone.close);
          await _counted(badgeAlone);
          ladder['badgeAlone'] = await phase(
            'badge cubit alone',
            badge: badgeAlone,
          );
          await badgeAlone.close();

          final bloc = ConversationListBloc(
            dmRepository: account.repository,
            followRepository: account.follows,
            contentBlocklistRepository: account.blocklist,
          )..add(const ConversationListStarted());
          addTearDown(bloc.close);
          final cubit = DmUnreadCountCubit(
            dmRepository: account.repository,
            followRepository: account.follows,
            contentBlocklistRepository: account.blocklist,
          );
          addTearDown(cubit.close);
          await bloc.stream
              .firstWhere((s) => s.status == ConversationListStatus.loaded)
              .timeout(const Duration(seconds: 30));
          expect(
            bloc.state.conversations.length +
                bloc.state.requestConversations.length,
            greaterThan(size * 0.8),
            reason: 'the bloc must be composing the seeded account',
          );
          await _counted(cubit);
          ladder['blocAndCubit'] = await phase(
            'bloc + cubit',
            badge: cubit,
            list: bloc,
          );
          await bloc.close();
          await cubit.close();
          expect(
            blocErrors.errors,
            isEmpty,
            reason: 'a bloc or cubit failed while it was being measured',
          );

          results['ladder_${size}_${variant.name}'] = ladder;
          // Seeding 5000 rows and a burst per ladder step outlast the 30 s
          // default on a phone.
        }, timeout: const Timeout(Duration(minutes: 5)));
      }
    }

    test('synchronous recompute pieces', () {
      for (final size in _accountSizes) {
        final rng = Random(size);
        final conversations = [
          for (var i = 0; i < size; i++)
            DmConversation(
              id: _hex(rng, 32),
              participantPubkeys: [_owner, _pubkey(10000 + i)],
              isGroup: false,
              createdAt: 1700000000,
              lastMessageContent: 'message ${_hex(rng, 24)}',
              lastMessageTimestamp: 1700000000 + i,
              lastMessageSenderPubkey: _pubkey(10000 + i),
              isRead: i % 10 != 0,
              currentUserHasSent: i.isOdd,
            ),
        ];
        final timer = Stopwatch()..start();
        const reps = 20;
        for (var r = 0; r < reps; r++) {
          final split = DmRepository.classifyPotentialRequests(
            conversations.where((c) => !c.currentUserHasSent).toList(),
            userPubkey: _owner,
            isFollowing: (_) => true,
          );
          DmRepository.mergeAndSort(
            conversations.where((c) => c.currentUserHasSent).toList(),
            split.followed,
          );
        }
        final classifyMs = timer.elapsedMicroseconds / reps / 1000;
        timer
          ..reset()
          ..start();
        var equal = 0;
        for (var r = 0; r < reps; r++) {
          final a = ConversationListState(conversations: conversations);
          final b = ConversationListState(conversations: [...conversations]);
          if (a == b) equal++;
        }
        final equalityMs = timer.elapsedMicroseconds / reps / 1000;
        expect(equal, reps, reason: 'copies must compare equal (deep compare)');
        report.writeln(
          'N=$size classify+mergeAndSort=${_fmt(classifyMs)}ms '
          'state equality (deep)=${_fmt(equalityMs)}ms',
        );
        results['pieces_$size'] = {
          'classifyAndSortMs': classifyMs,
          'stateEqualityMs': equalityMs,
        };
      }
    });
  });

  group('inbox frame trace (#7923)', () {
    for (final size in _accountSizes) {
      for (final variant in _Variant.values) {
        testWidgets('frames N=$size ${variant.name}', (tester) async {
          final account = await tester.runAsync(
            () => _Account.open(size, variant),
          );
          // Teardowns run last-registered first: bloc, cubit, then the
          // database, and they run when an expectation fails too.
          addTearDown(account!.close);
          final view = PlatformDispatcher.instance.views.first;
          final hz = view.display.refreshRate;
          final budgetMs = hz > 0 ? 1000 / hz : 16.67;
          binding.framePolicy =
              LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

          // The badge is app-shell-wide: alive before the inbox opens.
          final cubit = DmUnreadCountCubit(
            dmRepository: account.repository,
            followRepository: account.follows,
            contentBlocklistRepository: account.blocklist,
          );
          addTearDown(cubit.close);
          final feedRows = await tester.runAsync(
            () => account.repository.watchAcceptedConversations().first,
          );
          await tester.pumpWidget(_FeedCanary(feedRows!.take(40).toList()));

          final over =
              <
                String,
                ({
                  int frames,
                  int over,
                  int dropped,
                  int actFrames,
                  double stall,
                  int badge,
                  int list,
                })
              >{};
          Future<void> trace(
            String label,
            Future<void> Function() act, {
            ConversationListBloc? list,
          }) async {
            final timings = <FrameTiming>[];
            void collect(List<FrameTiming> t) => timings.addAll(t);
            binding.addTimingsCallback(collect);
            var badgeUpdates = 0;
            var listUpdates = 0;
            final watchers = <StreamSubscription<Object?>>[
              cubit.stream.listen((_) => badgeUpdates++),
              ?list?.stream
                  .where((s) => s.status == ConversationListStatus.loaded)
                  .listen((_) => listUpdates++),
            ];
            final sampler = _StallSampler()..start();
            final wall = Stopwatch()..start();
            var actFrames = 0;
            final framesAtStart = framesBegun;
            try {
              await act();
              wall.stop();
              actFrames = framesBegun - framesAtStart;
              // FrameTimings arrive in batches, about every 100 ms in profile
              // builds: wait out the last debounced recompute and its batch.
              await Future<void>.delayed(const Duration(seconds: 2));
            } finally {
              sampler.cancel();
              binding.removeTimingsCallback(collect);
              for (final watcher in watchers) {
                await watcher.cancel();
              }
            }
            final s = sampler.stop();
            double ms(Duration d) => d.inMicroseconds / 1000;
            final build = timings.map((t) => ms(t.buildDuration)).toList()
              ..sort();
            final raster = timings.map((t) => ms(t.rasterDuration)).toList()
              ..sort();
            final late = timings
                .where((t) => ms(t.vsyncOverhead) > budgetMs)
                .length;
            final overBudget = timings
                .where(
                  (t) =>
                      ms(t.buildDuration) > budgetMs ||
                      ms(t.rasterDuration) > budgetMs ||
                      ms(t.vsyncOverhead) > budgetMs,
                )
                .length;
            double p(List<double> xs, double q) => xs.isEmpty
                ? 0
                : xs[(xs.length * q).floor().clamp(0, xs.length - 1)];
            // A frame the engine skipped while the UI isolate was busy has no
            // FrameTiming at all; it shows only as a gap between vsyncs.
            final vsyncs =
                timings
                    .map(
                      (t) => t.timestampInMicroseconds(FramePhase.vsyncStart),
                    )
                    .toList()
                  ..sort();
            var dropped = 0;
            for (var i = 1; i < vsyncs.length; i++) {
              final gapMs = (vsyncs[i] - vsyncs[i - 1]) / 1000;
              if (gapMs > budgetMs * 1.5) {
                dropped += (gapMs / budgetMs).round() - 1;
              }
            }
            over[label] = (
              frames: timings.length,
              actFrames: actFrames,
              over: overBudget,
              dropped: dropped,
              stall: s.maxMs,
              badge: badgeUpdates,
              list: listUpdates,
            );
            report.writeln(
              'N=$size ${variant.name} $label: frames=${timings.length} '
              '($actFrames begun while acting) '
              'in ${wall.elapsedMilliseconds}ms+2000ms dropped=$dropped '
              'over-budget=$overBudget (late start=$late) '
              'build p50/p99/max=${_fmt(p(build, .5))}/${_fmt(p(build, .99))}/'
              '${_fmt(build.isEmpty ? 0 : build.last)}ms '
              'raster p99=${_fmt(p(raster, .99))}ms '
              'longest stall=${_fmt(s.maxMs)}ms budget=${_fmt(budgetMs)}ms '
              'badge updates=$badgeUpdates list updates=$listUpdates',
            );
          }

          await tester.runAsync(() async {
            await _counted(cubit);
            await trace(
              'idle, inbox closed',
              () => Future<void>.delayed(const Duration(seconds: 3)),
            );
            await trace('trickle, inbox closed', () => _trickle(account));
          });

          final bloc = ConversationListBloc(
            dmRepository: account.repository,
            followRepository: account.follows,
            contentBlocklistRepository: account.blocklist,
          )..add(const ConversationListStarted());
          addTearDown(bloc.close);
          await tester.pumpWidget(
            BlocProvider<ConversationListBloc>.value(
              value: bloc,
              child: const _InboxCanary(),
            ),
          );
          await tester.runAsync(() async {
            await bloc.stream
                .firstWhere((s) => s.status == ConversationListStatus.loaded)
                .timeout(const Duration(seconds: 30));
            await trace(
              'idle',
              () => Future<void>.delayed(const Duration(seconds: 3)),
              list: bloc,
            );
            await trace('burst', () => _burst(account), list: bloc);
            await trace('trickle', () => _trickle(account), list: bloc);
          });

          results['frames_${size}_${variant.name}'] = {
            for (final e in over.entries)
              e.key: {
                'frames': e.value.frames,
                'framesWhileActing': e.value.actFrames,
                'overBudget': e.value.over,
                'dropped': e.value.dropped,
                'longestStallMs': e.value.stall,
                'badgeUpdates': e.value.badge,
                'listUpdates': e.value.list,
              },
          };

          final burst = over['burst']!;
          // The final trickle is not checked for the badge: a small account's
          // burst can leave every row unread, so its writes need not move the
          // count. Every write outside a hidden member's group moves a row, so
          // the list still updates.
          expect(
            over['trickle, inbox closed']!.badge,
            greaterThan(0),
            reason: 'the trickle must reach the badge',
          );
          expect(
            burst.badge,
            greaterThan(0),
            reason: 'the burst must reach the badge',
          );
          expect(
            burst.list,
            greaterThan(0),
            reason: 'the burst must reach the list',
          );
          expect(
            over['trickle']!.list,
            greaterThan(0),
            reason: 'the trickle must reach the list',
          );
          expect(
            bloc.state.status,
            equals(ConversationListStatus.loaded),
            reason: 'the list must still be composing after the writes',
          );
          expect(
            blocErrors.errors,
            isEmpty,
            reason: 'a bloc or cubit failed while it was being measured',
          );
          expect(
            burst.actFrames,
            greaterThan(0),
            reason: 'the burst must render frames while it runs',
          );
          if (size == _gatedSize) {
            void expectNoWorseThanIdle(String idleLabel, String label) {
              final base = over[idleLabel]!;
              final phase = over[label]!;
              final allowed =
                  ((base.over + base.dropped) /
                          max(base.frames, 1) *
                          phase.frames)
                      .ceil() +
                  2;
              expect(
                phase.stall,
                lessThan(_frozenUiStallMs),
                reason: 'N=$size ${variant.name} $label froze the UI isolate',
              );
              expect(
                phase.over + phase.dropped,
                lessThanOrEqualTo(allowed),
                reason:
                    'N=$size ${variant.name} $label must not miss more '
                    'frames than $idleLabel does',
              );
            }

            expectNoWorseThanIdle('idle', 'burst');
            expectNoWorseThanIdle('idle', 'trickle');
            expectNoWorseThanIdle(
              'idle, inbox closed',
              'trickle, inbox closed',
            );
          }

          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  });
}
