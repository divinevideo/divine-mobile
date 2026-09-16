// ABOUTME: Tests the Riverpod service-listener invalidation detector.
// ABOUTME: Pins its callback boundary so one-shot refreshes remain allowed.

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports, scripts are outside the application library.
import '../../scripts/lib/listener_invalidate_self_detector.dart';

void main() {
  group('findListenerInvalidateSelfSitesInSource', () {
    test('flags a named addListener callback that invalidates itself', () {
      final sites = findListenerInvalidateSelfSitesInSource('''
int provider(Ref ref) {
  void listener() => ref.invalidateSelf();
  service.addListener(listener);
  ref.onDispose(() => service.removeListener(listener));
  return 0;
}
''');

      expect(sites, hasLength(1));
      expect(sites.single.line, 3);
    });

    test('flags an inline addListener callback that invalidates itself', () {
      final sites = findListenerInvalidateSelfSitesInSource('''
int provider(Ref ref) {
  service.addListener(() {
    ref.invalidateSelf();
  });
  return 0;
}
''');

      expect(sites, hasLength(1));
    });

    test('allows invalidateSelf outside a registered listener', () {
      final sites = findListenerInvalidateSelfSitesInSource('''
Future<void> refresh(Ref ref) async {
  await repository.refresh();
  ref.invalidateSelf();
}
''');

      expect(sites, isEmpty);
    });

    test('allows a listener that publishes a new version', () {
      final sites = findListenerInvalidateSelfSitesInSource('''
int provider(Ref ref) {
  var version = 0;
  void listener() => ref.state = ++version;
  service.addListener(listener);
  return version;
}
''');

      expect(sites, isEmpty);
    });

    test('flags a `_ref` field receiver', () {
      final sites = findListenerInvalidateSelfSitesInSource('''
class Owner {
  Owner(this._ref);
  final Ref _ref;
  void install() {
    service.addListener(() {
      _ref.invalidateSelf();
    });
  }
}
''');

      expect(sites, hasLength(1));
    });

    test('flags a `this.ref` receiver', () {
      final sites = findListenerInvalidateSelfSitesInSource('''
class Owner {
  Owner(this.ref);
  final Ref ref;
  void install() => service.addListener(() => this.ref.invalidateSelf());
}
''');

      expect(sites, hasLength(1));
    });

    test('flags a cascaded invalidateSelf', () {
      final sites = findListenerInvalidateSelfSitesInSource('''
int provider(Ref ref) {
  service.addListener(() {
    ref..invalidateSelf();
  });
  return 0;
}
''');

      expect(sites, hasLength(1));
    });

    test('allows invalidateSelf on an unrelated receiver', () {
      final sites = findListenerInvalidateSelfSitesInSource('''
int provider(Ref ref) {
  service.addListener(() => other.invalidateSelf());
  return 0;
}
''');

      expect(sites, isEmpty);
    });

    test('follows a closure bound to a local variable', () {
      final sites = findListenerInvalidateSelfSitesInSource('''
int provider(Ref ref) {
  final void Function() listener = () {
    ref.invalidateSelf();
  };
  service.addListener(listener);
  return 0;
}
''');

      expect(sites, hasLength(1));
    });

    test('follows a closure bound to a field', () {
      final sites = findListenerInvalidateSelfSitesInSource('''
class Owner {
  Owner(this.ref);
  final Ref ref;
  late final VoidCallback _listener = () => ref.invalidateSelf();
  void install() => service.addListener(_listener);
}
''');

      expect(sites, hasLength(1));
    });

    test('ignores a same-named closure scoped to another method', () {
      final sites = findListenerInvalidateSelfSitesInSource('''
class Owner {
  Owner(this.ref);
  final Ref ref;
  void other() {
    final void Function() listener = () => ref.invalidateSelf();
    listener();
  }
  void install() {
    final void Function() listener = () => ref.state = 1;
    service.addListener(listener);
  }
}
''');

      expect(sites, isEmpty);
    });

    test('flags ref.invalidateSelf registered as the listener itself', () {
      final sites = findListenerInvalidateSelfSitesInSource('''
int provider(Ref ref) {
  service.addListener(ref.invalidateSelf);
  return 0;
}
''');

      expect(sites, hasLength(1));
    });

    test('flags a `_ref` tear-off registered as the listener', () {
      final sites = findListenerInvalidateSelfSitesInSource('''
class Owner {
  Owner(this._ref);
  final Ref _ref;
  void install() => service.addListener(_ref.invalidateSelf);
}
''');

      expect(sites, hasLength(1));
    });

    test('allows a tear-off on a receiver that is not a Ref', () {
      final sites = findListenerInvalidateSelfSitesInSource('''
int provider(Ref ref) {
  service.addListener(other.invalidateSelf);
  return 0;
}
''');

      expect(sites, isEmpty);
    });

    test('follows a closure assigned to a field and null-asserted', () {
      final sites = findListenerInvalidateSelfSitesInSource('''
class Owner {
  Owner(this.ref);
  final Ref ref;
  void Function()? listener;

  void install() {
    listener = () => ref.invalidateSelf();
    service.addListener(listener!);
  }
}
''');

      expect(sites, hasLength(1));
    });

    test('follows a closure assigned to a local variable', () {
      final sites = findListenerInvalidateSelfSitesInSource('''
int provider(Ref ref) {
  void Function() listener;
  listener = () => ref.invalidateSelf();
  service.addListener(listener);
  return 0;
}
''');

      expect(sites, hasLength(1));
    });

    test('ignores an assignment scoped to another method', () {
      final sites = findListenerInvalidateSelfSitesInSource('''
class Owner {
  Owner(this.ref);
  final Ref ref;
  void Function()? listener;

  void other() {
    listener = () => ref.invalidateSelf();
    listener!();
  }

  void install() {
    listener = () => ref.state = 1;
    service.addListener(listener!);
  }
}
''');

      expect(sites, isEmpty);
    });

    test('follows a class method tear-off', () {
      final sites = findListenerInvalidateSelfSitesInSource('''
class Owner {
  Owner(this.ref);
  final Ref ref;
  void install() => service.addListener(_changed);
  void _changed() => ref.invalidateSelf();
}
''');

      expect(sites, hasLength(1));
    });
  });
}
