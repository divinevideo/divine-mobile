import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/profile_feed/profile_tab_retap_cubit.dart';

void main() {
  group(ProfileTabRetapCubit, () {
    blocTest<ProfileTabRetapCubit, int>(
      'emits a new count for every retap',
      build: ProfileTabRetapCubit.new,
      act: (cubit) => cubit
        ..request()
        ..request(),
      expect: () => const [1, 2],
    );
  });
}
