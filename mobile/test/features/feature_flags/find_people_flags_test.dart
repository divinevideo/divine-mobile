import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/services/build_configuration.dart';

void main() {
  test('people discovery requires separate internal opt-ins', () {
    const configuration = BuildConfiguration();
    expect(configuration.getDefault(FeatureFlag.findPeople), isFalse);
    expect(
      configuration.getDefault(FeatureFlag.feedPeopleSuggestions),
      isFalse,
    );
    expect(FeatureFlag.findPeople.isInternal, isTrue);
    expect(FeatureFlag.feedPeopleSuggestions.isInternal, isTrue);
  });
}
