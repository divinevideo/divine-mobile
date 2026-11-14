// ABOUTME: Pins that iosModalPage is a full-screen dialog on iOS only
// ABOUTME: and keeps go_router page metadata like fadeUpwardsPage does

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/router/ios_modal_page.dart';

class _FakeGoRouterState extends Fake implements GoRouterState {
  _FakeGoRouterState({
    required this.pageKey,
    this.name,
    this.path,
    Uri? uri,
  }) : uri = uri ?? Uri.parse('/');

  @override
  final ValueKey<String> pageKey;

  @override
  final String? name;

  @override
  final String? path;

  @override
  GoRoute? get topRoute => null;

  @override
  String? get fullPath => null;

  @override
  Map<String, String> get pathParameters => const {};

  @override
  final Uri uri;
}

_FakeGoRouterState _state({Uri? uri}) => _FakeGoRouterState(
  pageKey: const ValueKey('support-report-bug'),
  name: 'support-report-bug',
  path: '/support-center/report-bug',
  uri: uri,
);

void main() {
  group('iosModalPage', () {
    test(
      'is a full-screen dialog on iOS, so it slides up with no back swipe',
      () {
        final page = iosModalPage(
          state: _state(),
          child: const SizedBox.shrink(),
          platform: TargetPlatform.iOS,
        );
        expect(page.fullscreenDialog, isTrue);
      },
    );

    test('is a regular page on Android, so its transition stays as it is', () {
      final page = iosModalPage(
        state: _state(),
        child: const SizedBox.shrink(),
        platform: TargetPlatform.android,
      );
      expect(page.fullscreenDialog, isFalse);
    });

    test(
      'carries go_router page metadata so observers see a real route name',
      () {
        final page = iosModalPage(
          state: _state(uri: Uri.parse('/support-center/report-bug?from=test')),
          child: const SizedBox.shrink(),
        );
        expect(page.key, const ValueKey('support-report-bug'));
        expect(page.name, 'support-report-bug');
        expect(page.arguments, {'from': 'test'});
        expect(page.restorationId, 'support-report-bug');
      },
    );
  });
}
