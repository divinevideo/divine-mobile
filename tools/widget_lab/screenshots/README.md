# Native widget captures · 2026-10-24

- `ios-square-home.png`: actual small WidgetKit widget on an iOS 26.1 simulator home screen. Next, Like, and Open were verified through XCTest.
- `android-shapes.png`: composed native RemoteViews in the Android API 36 test activity, showing 160 × 160 dp and 160 × 280 dp layouts. This is a native preview, not a physical launcher screenshot. The separate system-host test verifies actions, resizing, frame advancement, and stopping.

Both use the repository's already-published seed content. Still captures establish appearance, not useful animated playback or production integration. Generated video assets remain ignored.

Refreshed with the green camera shortcut in the center of each card's control row. Android's minimum width is 144 dp to accommodate three 48 dp controls.
