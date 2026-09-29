import 'dart:async';

import 'package:divine_quick_actions/divine_quick_actions.dart';
import 'package:divine_quick_actions/divine_quick_actions_method_channel.dart';
import 'package:divine_quick_actions/divine_quick_actions_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDivineQuickActionsPlatform
    with MockPlatformInterfaceMixin
    implements DivineQuickActionsPlatform {
  final StreamController<DivineQuickActionEvent> _controller =
      StreamController<DivineQuickActionEvent>.broadcast();
  final StreamController<void> _pinnedController =
      StreamController<void>.broadcast();

  DivineQuickActionEvent? launchAction;
  List<DivineQuickAction> actions = const <DivineQuickAction>[];
  bool supported = true;
  bool pinSupported = true;
  int pinRequests = 0;

  @override
  Stream<DivineQuickActionEvent> get actionStream => _controller.stream;

  @override
  Stream<void> get cameraWidgetPinnedStream => _pinnedController.stream;

  @override
  Future<bool> isCameraWidgetPinSupported() async => pinSupported;

  @override
  Future<bool> requestPinCameraWidget() async {
    pinRequests++;
    return pinSupported;
  }

  void confirmPinned() {
    _pinnedController.add(null);
  }

  @override
  Future<bool> clearActions() async {
    actions = const <DivineQuickAction>[];
    return supported;
  }

  @override
  Future<DivineQuickActionEvent?> consumeLaunchAction() async {
    final action = launchAction;
    launchAction = null;
    return action;
  }

  @override
  Future<List<DivineQuickAction>> getActions() async => actions;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<bool> setActions(List<DivineQuickAction> actions) async {
    this.actions = actions;
    return supported;
  }

  void addAction(DivineQuickActionEvent action) {
    _controller.add(action);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final initialPlatform = DivineQuickActionsPlatform.instance;

  // Platform singletons are process-global; restore after every test so the
  // swapped-in mock cannot strand sibling suites in the merged-isolate run.
  tearDown(() {
    DivineQuickActionsPlatform.instance = initialPlatform;
  });

  group('platform instance', () {
    test('$MethodChannelDivineQuickActions is the default instance', () {
      expect(initialPlatform, isInstanceOf<MethodChannelDivineQuickActions>());
    });
  });

  group('setActions', () {
    test('setActions delegates typed actions to the platform', () async {
      final plugin = DivineQuickActions.instance;
      final fakePlatform = MockDivineQuickActionsPlatform();
      DivineQuickActionsPlatform.instance = fakePlatform;

      const action = DivineQuickAction(
        type: 'record',
        title: 'Record',
        payload: <String, String>{'source': 'shortcut'},
      );

      expect(await plugin.setActions(<DivineQuickAction>[action]), isTrue);
      expect(await plugin.getActions(), equals(<DivineQuickAction>[action]));
    });

    test('setActions rejects duplicate action types', () async {
      final plugin = DivineQuickActions.instance;
      DivineQuickActionsPlatform.instance = MockDivineQuickActionsPlatform();

      expect(
        () => plugin.setActions(const <DivineQuickAction>[
          DivineQuickAction(type: 'record', title: 'Record'),
          DivineQuickAction(type: 'record', title: 'Record again'),
        ]),
        throwsArgumentError,
      );
    });
  });

  group('camera widget pinning', () {
    test('forwards the launcher capability and request result', () async {
      final plugin = DivineQuickActions.instance;
      final fakePlatform = MockDivineQuickActionsPlatform()
        ..pinSupported = false;
      DivineQuickActionsPlatform.instance = fakePlatform;

      expect(await plugin.isCameraWidgetPinSupported, isFalse);
      expect(await plugin.requestPinCameraWidget(), isFalse);
      expect(fakePlatform.pinRequests, 1);
    });

    test('emits when the platform confirms the widget was added', () async {
      final plugin = DivineQuickActions.instance;
      final fakePlatform = MockDivineQuickActionsPlatform();
      DivineQuickActionsPlatform.instance = fakePlatform;
      var pinnedCount = 0;
      final subscription = plugin.cameraWidgetPinnedStream.listen(
        (_) => pinnedCount++,
      );
      addTearDown(subscription.cancel);

      fakePlatform.confirmPinned();
      await pumpEventQueue();

      expect(pinnedCount, 1);
    });
  });

  group('initialize', () {
    test('initialize returns and forwards launch action once', () async {
      final plugin = DivineQuickActions.instance;
      final fakePlatform = MockDivineQuickActionsPlatform()
        ..launchAction = const DivineQuickActionEvent(
          type: 'record',
          payload: <String, String>{'source': 'launch'},
          isLaunchAction: true,
        );
      DivineQuickActionsPlatform.instance = fakePlatform;
      final received = <DivineQuickActionEvent>[];

      final launchAction = await plugin.initialize(onAction: received.add);

      expect(launchAction?.type, 'record');
      expect(launchAction?.isLaunchAction, isTrue);
      expect(received, contains(launchAction));
      expect(await plugin.initialize(), isNull);
    });

    test('initialize subscribes to runtime action stream', () async {
      final plugin = DivineQuickActions.instance;
      final fakePlatform = MockDivineQuickActionsPlatform();
      DivineQuickActionsPlatform.instance = fakePlatform;
      final received = <DivineQuickActionEvent>[];

      await plugin.initialize(onAction: received.add);
      fakePlatform.addAction(const DivineQuickActionEvent(type: 'search'));
      await pumpEventQueue();

      expect(received.single.type, 'search');
    });
  });
}
