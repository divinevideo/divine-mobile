import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/sound_requests/sound_requests_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/inbox/conversation/widgets/sound_request_card.dart';

class _Repository extends Mock implements SoundRequestsRepository {}

const creator =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const requester =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const id = 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const address = '34236:$creator:clip';
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  group('interactions', () {
    testWidgets(
      'incoming request explains public reuse and exposes creator actions',
      (tester) async {
        final repo = _Repository();
        when(() => repo.ownerPubkey).thenReturn(creator);
        when(repo.watchState).thenAnswer(
          (_) => Stream.value(
            const SoundRequestSnapshot(
              requests: {
                id: SoundRequestEntry(
                  id: id,
                  requester: requester,
                  videoAddress: address,
                ),
              },
            ),
          ),
        );
        when(repo.start).thenAnswer((_) async {});
        when(() => repo.sourceVideo(address)).thenAnswer(
          (_) async => VideoEvent(
            id: 'd' * 64,
            pubkey: creator,
            createdAt: 1,
            content: 'clip',
            timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
            title: 'My clip',
          ),
        );
        final cubit = SoundRequestsCubit();
        await cubit.connect(repo);
        addTearDown(cubit.close);
        const message = SoundRequestMessage(
          kind: SoundRequestMessageKind.request,
          messageId: id,
          senderPubkey: requester,
          recipientPubkey: creator,
          videoAddress: address,
          creatorPubkey: creator,
        );
        await tester.pumpWidget(
          BlocProvider.value(
            value: cubit,
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SoundRequestCard(message: message, isSent: false),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.soundRequestEnable), findsOneWidget);
        expect(find.text(l10n.soundRequestDescription), findsOneWidget);
        expect(find.text(l10n.saveOriginalDismiss), findsOneWidget);
        expect(find.text('My clip'), findsOneWidget);
        verifyNever(() => repo.approve(id));
      },
    );
  });
}
