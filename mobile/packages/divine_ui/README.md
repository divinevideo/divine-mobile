# divine_ui

Status: Current
Validated against: `pubspec.yaml` on 2026-03-19.

Purpose: shared Divine design-system package for theme, icons, and reusable UI components.

Used by: the Flutter app and any workspace package that renders app-consistent UI.

Test locally:

```bash
cd mobile/packages/divine_ui
flutter test
```

Icons render from precompiled vectors in this package's `assets/icons/`.
The editable SVG sources remain in `mobile/assets/icon/`. After changing,
adding, or removing an SVG, regenerate from this package:

```bash
dart run tool/compile_icons.dart
```

Commit the generated `.vec` files with the SVG changes. The icon tests check
that every generated asset matches its source and that every icon loads from
the package bundle. Both `DivineIcon` and the shadow raster cache use these
vectors to avoid runtime SVG asset decoding on worker isolates.
