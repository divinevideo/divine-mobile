// ABOUTME: Tests for addReceivedClipToLibrary: the C2PA check outlives the
// ABOUTME: screen that started it and still reports its outcome.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/clip_save/dm_clip_save_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/inbox/conversation/widgets/dm_clip_save_scope.dart';

class _MockDmClipSaveCubit extends MockCubit<DmClipSaveState>
    implements DmClipSaveCubit {}

DmMessage _videoMessage() => DmMessage(
  id: 'a' * 64,
  conversationId: 'conversation',
  senderPubkey: 'b' * 64,
  content: 'https://blossom.example/encrypted',
  createdAt: 1757385263,
  giftWrapId: 'c' * 64,
  messageKind: 15,
  fileMetadata: const DmFileMetadata(
    fileType: 'video/mp4',
    encryptionAlgorithm: 'aes-gcm',
    decryptionKey: '00',
    decryptionNonce: '00',
    fileHash: 'ab',
  ),
);

void main() {
  final l10n = AppLocalizationsEn();

  setUpAll(() => registerFallbackValue(_videoMessage()));

  group('addReceivedClipToLibrary', () {
    testWidgets('reports the outcome after its screen has closed', (
      tester,
    ) async {
      final outcome = Completer<DmClipSaveStatus>();
      final cubit = _MockDmClipSaveCubit();
      when(() => cubit.save(any())).thenAnswer((_) => outcome.future);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BlocProvider<DmClipSaveCubit>.value(
                      value: cubit,
                      child: Scaffold(
                        body: Builder(
                          builder: (context) => TextButton(
                            onPressed: () => addReceivedClipToLibrary(
                              context,
                              _videoMessage(),
                            ),
                            child: const Text('add'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('add'));
      await tester.pump();
      expect(find.text(l10n.dmClipChecking), findsOneWidget);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.text('add'), findsNothing);

      outcome.complete(DmClipSaveStatus.saved);
      await tester.pumpAndSettle();

      expect(find.text(l10n.videoEditorClipSavedSuccess), findsOneWidget);
    });
  });
}
