# divine_quick_actions

Flutter plugin for Android and iOS home-screen quick actions.

## Features

- Typed shortcut models with payload support.
- Cold-start shortcut consumption so launch actions are not lost.
- Runtime shortcut events exposed as a broadcast stream.
- Android dynamic shortcuts through `ShortcutManager`.
- iOS quick actions through `UIApplicationShortcutItem`.
- One-tap camera widget placement on Android launchers that support `AppWidgetManager.requestPinAppWidget` (API 26+). iOS has no equivalent API and always reports it as unsupported.

```dart
final launchAction = await DivineQuickActions.instance.initialize(
  onAction: (action) {
    // Route from action.type and action.payload.
  },
);

await DivineQuickActions.instance.setActions([
  DivineQuickAction(
    type: 'record',
    title: 'Record',
    subtitle: 'Open the camera',
    androidIconName: 'ic_quick_record',
    iosIconName: 'video.fill',
    iosIconStyle: DivineQuickActionIosIconStyle.system,
  ),
]);
```

### Camera widget

Branch the UI on the capability, not the platform, and keep written steps as the fallback: a launcher can still refuse the request, and cancelling its confirmation emits nothing.

```dart
final quickActions = DivineQuickActions.instance;

if (await quickActions.isCameraWidgetPinSupported) {
  quickActions.cameraWidgetPinnedStream.listen((_) {
    // The widget is on the home screen.
  });
  final requested = await quickActions.requestPinCameraWidget();
  if (!requested) {
    // Show the manual instructions.
  }
}
```
