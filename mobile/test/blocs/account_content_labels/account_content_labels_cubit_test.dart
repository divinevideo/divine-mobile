// ABOUTME: Unit tests for AccountContentLabelsCubit — load snapshot and
// ABOUTME: persisting label-set changes.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/account_content_labels/account_content_labels_cubit.dart';
import 'package:openvine/blocs/account_content_labels/account_content_labels_state.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/services/account_label_service.dart';

class _MockAccountLabelService extends Mock implements AccountLabelService {}

void main() {
  setUpAll(() {
    registerFallbackValue(<ContentLabel>{});
  });

  group(AccountContentLabelsCubit, () {
    late _MockAccountLabelService service;

    setUp(() {
      service = _MockAccountLabelService();
      when(() => service.accountLabels).thenReturn(const {});
      when(() => service.setAccountLabels(any())).thenAnswer((call) async {
        when(() => service.accountLabels)
            .thenReturn(call.positionalArguments.first as Set<ContentLabel>);
      });
    });

    AccountContentLabelsCubit buildCubit() =>
        AccountContentLabelsCubit(service: service);

    blocTest<AccountContentLabelsCubit, AccountContentLabelsState>(
      'load emits the current account labels',
      setUp: () => when(() => service.accountLabels).thenReturn(const {
        ContentLabel.nudity,
        ContentLabel.violence,
      }),
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => const [
        AccountContentLabelsState(
          labels: {ContentLabel.nudity, ContentLabel.violence},
        ),
      ],
    );

    blocTest<AccountContentLabelsCubit, AccountContentLabelsState>(
      'setLabels persists and emits the new label set',
      build: buildCubit,
      act: (cubit) => cubit.setLabels(const {ContentLabel.porn}),
      expect: () => const [
        AccountContentLabelsState(labels: {ContentLabel.porn}),
      ],
      verify: (_) {
        verify(
          () => service.setAccountLabels(const {ContentLabel.porn}),
        ).called(1);
      },
    );

    blocTest<AccountContentLabelsCubit, AccountContentLabelsState>(
      'setLabels with an empty set clears the labels',
      seed: () =>
          const AccountContentLabelsState(labels: {ContentLabel.nudity}),
      build: buildCubit,
      act: (cubit) => cubit.setLabels(const {}),
      expect: () => const [AccountContentLabelsState()],
      verify: (_) {
        verify(() => service.setAccountLabels(const {})).called(1);
      },
    );
  });
}
