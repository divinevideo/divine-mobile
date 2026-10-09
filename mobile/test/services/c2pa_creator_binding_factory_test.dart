import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/c2pa_creator_binding_factory.dart';
import 'package:openvine/services/nostr_creator_binding_service.dart';

class _MockBindingService extends Mock implements NostrCreatorBindingService {}

void main() {
  group(C2paCreatorBindingFactory, () {
    const binding = NostrCreatorBindingAssertion(
      assertionLabel: NostrCreatorBindingService.assertionLabel,
      payloadJson: '{}',
      signature: 'signature',
      pubkey: 'pubkey',
    );

    late _MockBindingService bindingService;

    setUpAll(() {
      registerFallbackValue(const CreatorBindingClaims());
      registerFallbackValue(
        const CreatorBindingHardBinding(alg: 'sha256', value: ''),
      );
    });

    setUp(() {
      bindingService = _MockBindingService();
    });

    Future<NostrCreatorBindingAssertion?> Function() stubCreate() =>
        () => bindingService.createAssertion(
          claims: any(named: 'claims'),
          hardBinding: any(named: 'hardBinding'),
          referencedAssertions: any(named: 'referencedAssertions'),
        );

    C2paCreatorBindingFactory buildFactory({Duration? timeout}) =>
        C2paCreatorBindingFactory(
          bindingService: () => bindingService,
          nip05: () => 'alice@example.com',
          timeout: timeout ?? C2paCreatorBindingFactory.defaultTimeout,
        );

    group('create', () {
      test('binds the hash of the file about to be signed', () async {
        final directory = await Directory.systemTemp.createTemp(
          'creator-binding-factory-test-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = File('${directory.path}/clip.mp4');
        await file.writeAsString('abc');
        when(stubCreate()).thenAnswer((_) async => binding);

        final result = await buildFactory().create(file.path);

        expect(result, same(binding));
        final captured = verify(
          () => bindingService.createAssertion(
            claims: captureAny(named: 'claims'),
            hardBinding: captureAny(named: 'hardBinding'),
            referencedAssertions: captureAny(named: 'referencedAssertions'),
          ),
        ).captured;
        expect(
          (captured[0] as CreatorBindingClaims).nip05,
          equals('alice@example.com'),
        );
        final hardBinding = captured[1] as CreatorBindingHardBinding;
        expect(hardBinding.alg, equals('sha256'));
        // SHA-256 of "abc".
        expect(
          hardBinding.value,
          equals(
            'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
          ),
        );
        expect(
          captured[2],
          equals(C2paCreatorBindingFactory.referencedAssertions),
        );
      });

      test('returns null when nobody is signed in', () async {
        when(stubCreate()).thenThrow(StateError('no identity'));

        final result = await C2paCreatorBindingFactory(
          bindingService: () => bindingService,
          nip05: () => null,
          sha256OfFile: (_) async => 'hash',
        ).create('clip.mp4');

        expect(result, isNull);
      });

      test('returns null when the file cannot be read', () async {
        final result = await buildFactory().create('/does/not/exist.mp4');

        expect(result, isNull);
        verifyNever(stubCreate());
      });

      test('gives up on a signer that does not answer', () {
        fakeAsync((async) {
          when(
            stubCreate(),
          ).thenAnswer(
            (_) => Completer<NostrCreatorBindingAssertion?>().future,
          );
          NostrCreatorBindingAssertion? result = binding;
          var done = false;

          unawaited(
            C2paCreatorBindingFactory(
              bindingService: () => bindingService,
              nip05: () => null,
              sha256OfFile: (_) async => 'hash',
              timeout: const Duration(seconds: 2),
            ).create('clip.mp4').then((value) {
              result = value;
              done = true;
            }),
          );
          async.elapse(const Duration(seconds: 3));

          expect(done, isTrue);
          expect(result, isNull);
        });
      });
    });
  });
}
