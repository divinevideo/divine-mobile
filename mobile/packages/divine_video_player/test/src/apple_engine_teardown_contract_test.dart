import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// These assertions guard the Apple-side fixes for the "zombie CADisplayLink"
/// crash (#5371), the multi-engine registration hardening that followed
/// (#5397), and the shell-teardown crash they left open (#9342): a
/// `FlutterEngine` whose shell is destroyed — scene disconnect, app
/// termination, view-controller dealloc — must have its own players released
/// before or as the shell goes, without calling back into that engine, and
/// without touching another engine's players. The native player has no
/// host-side Swift test harness in this package (it links Flutter), so the
/// contract is asserted against the source like the sibling threading
/// contract test; `ios/RunnerTests` covers the behaviour against a fake
/// engine.
void main() {
  group('Apple native player engine-teardown contract', () {
    test('publishes the plugin so Flutter delivers detachFromEngine', () {
      expect(
        _registerBody(),
        contains('registrar.publish(plugin)'),
        reason:
            'Flutter calls detachFromEngineForRegistrar: only on plugins that '
            'published themselves (FlutterPlugin.h). Without publish the '
            'detach hook below is dead code, which is how #4400 shipped.',
      );
    });

    test('hooks the lifecycle callbacks that precede shell teardown', () {
      final register = _registerBody();
      final source = _pluginSource();

      expect(
        register,
        allOf(
          contains('registrar.addSceneDelegate(plugin)'),
          contains('registrar.addApplicationDelegate(plugin)'),
        ),
        reason:
            'FlutterViewController answers UISceneDidDisconnectNotification '
            'and UIApplicationWillTerminateNotification with destroyContext, '
            'which frees the shell while the engine object stays alive. The '
            'scene and application delegate callbacks are what UIKit delivers '
            'ahead of those notifications, so the plugin must register for '
            'both.',
      );
      expect(
        _sceneDisconnectBody(),
        contains('tearDownEngine()'),
        reason:
            'Scene disconnect (switcher swipe-away or background memory '
            "reclaim) must release this engine's players before the shell "
            'goes.',
      );
      expect(
        _willTerminateBody(),
        contains('tearDownIfRendering()'),
        reason:
            'App termination destroys the shell too and the process keeps a '
            'live run loop for a while afterwards.',
      );
      expect(
        _detachBody(),
        contains('tearDownEngine()'),
        reason:
            'Engine dealloc is the last backstop; the app can hold the engine '
            'past its shell, so nothing may depend on it arriving in time.',
      );
      expect(
        register,
        allOf(
          contains('selector: #selector(flutterViewControllerWillDealloc(_:))'),
          contains('name: Self.viewControllerWillDeallocNotification'),
        ),
        reason:
            'A view-controller dealloc runs destroyContext from '
            'notifyViewControllerDeallocated with no delegate callback ahead '
            'of it; the controller posts FlutterViewControllerWillDealloc '
            'synchronously first, and that is the only hook for that path '
            'that does not wait on an engine dealloc.',
      );
      expect(
        _viewControllerWillDeallocBody(),
        allOf(
          contains('ObjectIdentifier(controller) == renderingViewControllerId'),
          contains('tearDownEngine()'),
        ),
        reason:
            "Inside the controller's dealloc every weak reference to it reads "
            'nil, so the notification object must be matched against an '
            "identity captured earlier — and only that controller's dealloc "
            'may tear this engine down.',
      );
      expect(
        source,
        contains(
          'extension DivineVideoPlayerPlugin: FlutterSceneLifeCycleDelegate',
        ),
        reason:
            'addSceneDelegate only accepts a FlutterSceneLifeCycleDelegate; '
            'the conformance is what makes sceneDidDisconnect reachable.',
      );
    });

    test('tears down only engines whose shell the event destroys', () {
      expect(
        _tearDownIfRenderingBody(),
        contains('guard registrar?.viewController != nil else { return }'),
        reason:
            'addApplicationDelegate registers on the shared app delegate and '
            'the engine registers every plugin instance with the single '
            'scene, so a headless engine (the notification isolate) receives '
            'both callbacks although no controller destroys its shell. '
            'Tearing it down would strand players it creates later and skip '
            'unregisterTexture against a live registry.',
      );
      expect(
        _sceneDisconnectBody(),
        allOf(
          contains('guard let controller = registrar?.viewController'),
          contains('windowScene !== scene'),
        ),
        reason:
            'The scene hook mirrors '
            'FlutterViewController.shouldHandleSceneNotification: — no '
            'controller means no shell teardown, a controller in another '
            'scene is not the one going away, and a detached window still '
            'counts, which is the memory-reclaim shape.',
      );
      expect(
        _createBody(),
        contains('guard !isEngineTornDown else {'),
        reason:
            'The teardown is one-way: its observers are gone and it never '
            'runs again, so a player created afterwards would be the zombie '
            'it exists to prevent.',
      );
    });

    test('tears down without calling back into the engine', () {
      final teardown = _tearDownBody();

      expect(
        teardown,
        contains(
          'PlayerRegistry.shared.disposeForEngine('
          'engineId, engineTearingDown: true)',
        ),
        reason:
            "Teardown must dispose only this engine's players, on the path "
            'that skips every call into the engine.',
      );
      expect(
        teardown,
        isNot(contains('disposeAll')),
        reason:
            'Teardown must never blanket-dispose: a process-wide sweep would '
            "tear down a second live engine's players.",
      );
      expect(
        teardown,
        contains('NotificationCenter.default.removeObserver(self)'),
        reason:
            "Teardown must drop this engine's lifecycle observers so a stray "
            'foreground notification cannot resume a torn-down engine.',
      );
      expect(
        teardown,
        isNot(contains('messenger(')),
        reason:
            'registrar.messenger() resolves through a weak engine reference '
            'that already reads nil inside the engine dealloc; the engine '
            'identity must come from the value captured at register.',
      );
      expect(
        _logSinkBody(),
        contains('!self.isEngineTornDown'),
        reason:
            'The native log sink delivers asynchronously on the main queue; '
            'an entry logged during teardown would otherwise reach '
            'sendOnChannel: after destroyContext and dereference the null '
            'shell.',
      );
      expect(
        _textureOutputSource(),
        allOf(
          contains('func dispose(unregisterTexture: Bool = true)'),
          contains('if unregisterTexture {'),
        ),
        reason:
            '-[FlutterEngine unregisterTexture:] dereferences the shell '
            'exactly like textureFrameAvailable:; the teardown path must be '
            'able to skip it. The shell owns the texture registry and drops '
            'the entry with itself.',
      );
      expect(
        _instanceSource(),
        allOf(
          contains('func dispose(engineTearingDown: Bool = false)'),
          contains(
            'textureOutput?.dispose(unregisterTexture: !engineTearingDown)',
          ),
        ),
        reason:
            'The player must forward the teardown flag so the texture is left '
            'registered when the shell is going.',
      );
    });

    test('scopes teardown to the engine that owns the players', () {
      final source = _pluginSource();

      expect(
        source,
        contains('func disposeForEngine('),
        reason:
            'PlayerRegistry.shared is process-wide and shared with the FCM '
            'background isolate; teardown must be scoped per owning engine, '
            'never a blanket disposeAll on detach or register.',
      );
      expect(
        source,
        isNot(contains('func disposeAll')),
        reason:
            'No process-wide sweep may exist: every caller has an engine to '
            'scope to.',
      );
      expect(
        source,
        contains('engine engineId: ObjectIdentifier'),
        reason:
            'Each player must record the engine (its binary messenger '
            'identity) that created it.',
      );
      expect(
        _createBody(),
        allOf(
          contains('engine: engineId'),
          isNot(contains('engine: Self.engineId(')),
        ),
        reason:
            'create must record the receiving engine as the owner so teardown '
            "and hot-restart register can identify this engine's players. It "
            'must use the key captured at register rather than re-deriving '
            'one: two independent derivations can diverge, and '
            'registrar.messenger() reads through a weak engine reference.',
      );
      expect(
        _registrySetBody(),
        contains('engines[id] = engineId'),
        reason:
            'The recording side must key the owner map on the engine identity '
            'it was handed. If set keys on anything else while the lookup '
            'keeps keying on the engine identity, recording and lookup keys '
            'never match, ownedIds is always empty, and no player is disposed '
            'on teardown / hot-restart register — the #5371 zombie '
            'CADisplayLink returns.',
      );
      expect(
        _disposeForEngineBody(),
        allOf(
          contains('ownedIds(of: engineId)'),
          contains('remove(id)?.dispose(engineTearingDown: engineTearingDown)'),
        ),
        reason:
            "The lookup side must filter the owner map to this engine's own "
            'players, then dispose each matched id through remove(id) so the '
            'owner-map entry is cleared in lockstep with the player, passing '
            'the teardown flag through.',
      );
      expect(
        _ownedIdsBody(),
        contains(r'$0.value == engineId'),
        reason:
            'The owner filter must compare against the engine identity; a body '
            'that returned every id would reintroduce the #5397 cross-engine '
            'teardown without any literal disposeAll token.',
      );
    });

    test('scopes app lifecycle notifications to the owning engine', () {
      final source = _pluginSource();

      expect(
        _resignActiveBody(),
        contains('PlayerRegistry.shared.forEngine(engineId)'),
        reason: "Resign-active must suspend only this engine's players.",
      );
      expect(
        _becomeActiveBody(),
        contains('PlayerRegistry.shared.forEngine(engineId)'),
        reason:
            "After a scene reconnect the new engine's plugin instance handles "
            'didBecomeActive; a process-wide sweep would re-arm frame delivery '
            "on the torn-down engine's players and crash on the first frame.",
      );
      expect(
        source,
        isNot(contains('forAll(')),
        reason: 'No process-wide iteration may remain in the plugin.',
      );
    });

    test('scopes the Dart disposeAll channel to the calling engine', () {
      expect(
        _disposeAllHandlerBody(),
        allOf(
          contains('PlayerRegistry.shared.disposeForEngine(engineId)'),
          isNot(contains('engineTearingDown')),
        ),
        reason:
            'Dart asks for the players of the engine it runs in, whose shell '
            "is alive, so textures are unregistered normally; another engine's "
            'players are not its to release.',
      );
    });

    test(
      'player creation uses the receiving instance registrar, not a static',
      () {
        final source = _pluginSource();

        expect(
          source,
          isNot(contains('static var registrar')),
          reason:
              'A process-wide static registrar is overwritten by the last '
              'engine to register; player creation would then use the wrong '
              "engine's messenger / texture registry. See #5397.",
        );
        expect(
          source,
          contains('private var registrar: FlutterPluginRegistrar?'),
          reason:
              'The registrar must be per plugin instance so each engine keeps '
              'its own messenger / texture registry.',
        );
        expect(
          _createBody(),
          contains('let registrar = self.registrar'),
          reason:
              'create must use the registrar of the plugin instance that '
              'received the method call — the engine the Dart side is talking '
              'to — not a static last-writer-wins registrar.',
        );
      },
    );

    test(
      'scopes hot-restart register-time cleanup to the registering engine',
      () {
        final register = _registerBody();

        expect(
          register,
          contains('PlayerRegistry.shared.disposeForEngine(engineId)'),
          reason:
              'Hot restart re-calls register on the same engine; cleanup must '
              "dispose only that engine's previous-run players, and the shell "
              'is alive there so textures are unregistered normally.',
        );
        expect(
          register,
          isNot(contains('disposeAll')),
          reason:
              'A process-wide disposeAll at register would free a second live '
              "engine's players when the FCM background isolate registers "
              'after the UI engine created players. See #5397.',
        );
      },
    );

    test('guards resume against a disposed texture output', () {
      final source = _textureOutputSource();

      expect(
        source,
        contains('guard !isDisposed else { return }'),
        reason:
            'resumeFrameDelivery must no-op once the output is disposed so a '
            'foreground notification racing a teardown-driven dispose cannot '
            're-arm delivery on an unregistered texture.',
      );
      expect(
        source,
        contains('isDisposed = true'),
        reason: 'dispose() must mark the output disposed for the resume guard.',
      );
    });
  });
}

String? _cachedPluginSource;
String? _cachedTextureOutputSource;
String? _cachedInstanceSource;

/// The Swift sources are static for the duration of the run, so read each
/// once and reuse it across all helpers/tests instead of re-reading per call.
String _pluginSource() => _cachedPluginSource ??= _resolve(
  'DivineVideoPlayerPlugin.swift',
).readAsStringSync();

String _textureOutputSource() => _cachedTextureOutputSource ??= _resolve(
  'VideoTextureOutput.swift',
).readAsStringSync();

String _instanceSource() => _cachedInstanceSource ??= _resolve(
  'DivineVideoPlayerInstance.swift',
).readAsStringSync();

/// Slices the `register(with:)` body, which runs from the function signature
/// up to the first app-lifecycle selector that follows it.
String _registerBody() => _slice(
  _pluginSource(),
  'public static func register(with registrar:',
  '@objc private func appWillResignActive',
);

String _resignActiveBody() => _slice(
  _pluginSource(),
  '@objc private func appWillResignActive',
  '@objc private func appDidBecomeActive',
);

String _becomeActiveBody() => _slice(
  _pluginSource(),
  '@objc private func appDidBecomeActive',
  'public func detachFromEngine(for registrar:',
);

/// Slices the `detachFromEngine(for:)` body, up to the will-terminate hook.
String _detachBody() => _slice(
  _pluginSource(),
  'public func detachFromEngine(for registrar:',
  'public func applicationWillTerminate(',
);

String _willTerminateBody() => _slice(
  _pluginSource(),
  'public func applicationWillTerminate(',
  '@objc private func flutterViewControllerWillDealloc(',
);

String _viewControllerWillDeallocBody() => _slice(
  _pluginSource(),
  '@objc private func flutterViewControllerWillDealloc(',
  'private func tearDownIfRendering()',
);

String _tearDownIfRenderingBody() => _slice(
  _pluginSource(),
  'private func tearDownIfRendering()',
  'private func noteRenderingViewController()',
);

/// Slices the shared teardown body, up to the `handle` method.
String _tearDownBody() => _slice(
  _pluginSource(),
  'private func tearDownEngine()',
  'public func handle(',
);

String _sceneDisconnectBody() => _slice(
  _pluginSource(),
  'public func sceneDidDisconnect(',
  '/// Global registry',
);

/// Slices the asynchronous log-sink closure, up to `installLogSink`.
String _logSinkBody() => _slice(
  _pluginSource(),
  'private lazy var logSink',
  'private func installLogSink()',
);

/// Slices the `disposeAll` method-call handler inside `handle`.
String _disposeAllHandlerBody() =>
    _slice(_pluginSource(), 'if call.method == "disposeAll"', 'guard let args');

/// Slices the `create` switch case, up to the `dispose` case.
String _createBody() =>
    _slice(_pluginSource(), 'case "create":', 'case "dispose":');

/// Slices the `PlayerRegistry.set(...)` body — the *recording* side of the
/// owner map — up to the `remove` method (`@discardableResult`) that follows.
/// Anchored on the unique `engine engineId:` parameter label rather than the
/// generic `func set(`, so a future `func set(` on any earlier class can't
/// silently redirect the slice to the wrong body.
String _registrySetBody() => _slice(
  _pluginSource(),
  'engine engineId: ObjectIdentifier',
  '@discardableResult',
);

/// Slices the `PlayerRegistry.disposeForEngine` body — the *lookup* and
/// teardown side — up to the `forEngine` method that follows it.
String _disposeForEngineBody() =>
    _slice(_pluginSource(), 'func disposeForEngine(', 'func forEngine(');

String _ownedIdsBody() =>
    _slice(_pluginSource(), 'private func ownedIds(', 'func diagnostics()');

String _slice(String source, String start, String end) {
  final from = source.indexOf(start);
  final to = source.indexOf(end, from);
  expect(from, isNonNegative, reason: 'expected to find "$start" in source');
  expect(to, greaterThan(from), reason: 'expected "$end" after "$start"');
  return source.substring(from, to);
}

/// The iOS and macOS players share a single Darwin source tree
/// (`darwin/divine_video_player/Sources/`), so the contract is asserted once.
File _resolve(String fileName) {
  final packageRelative = File(
    'darwin/divine_video_player/Sources/divine_video_player/$fileName',
  );
  if (packageRelative.existsSync()) {
    return packageRelative;
  }

  return File(
    'packages/divine_video_player/'
    'darwin/divine_video_player/Sources/divine_video_player/$fileName',
  );
}
