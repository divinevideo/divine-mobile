import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/config/app_config.dart';

void main() {
  test('deployment policy is immutable and preserves exact d-tags', () {
    final tags = AppConfig.parsePublicPeopleListExcludedDTags(
      '["synthetic-machine-set", "second-synthetic-set"]',
    );
    expect(tags, {'synthetic-machine-set', 'second-synthetic-set'});
    expect(() => tags!.add('another-set'), throwsUnsupportedError);
  });

  test('missing or malformed deployment input has no valid policy', () {
    for (final input in ['', '[]', 'null', '{}', '[4]', '[" "]', 'invalid']) {
      expect(AppConfig.parsePublicPeopleListExcludedDTags(input), isNull);
    }
  });
}
