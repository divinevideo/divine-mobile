// ABOUTME: Palette-level guards for light mode — legibility floors on both
// ABOUTME: palettes, and the token pairs a dark-only check cannot tell apart.
import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// WCAG relative luminance of an opaque color.
double _luminance(Color color) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// [foreground] composited onto the opaque [background].
Color _composite(Color foreground, Color background) {
  final alpha = foreground.a;
  return Color.from(
    alpha: 1,
    red: foreground.r * alpha + background.r * (1 - alpha),
    green: foreground.g * alpha + background.g * (1 - alpha),
    blue: foreground.b * alpha + background.b * (1 - alpha),
  );
}

/// WCAG contrast ratio of [foreground] over [background], honouring alpha.
double _contrast(Color foreground, Color background) {
  final first = _luminance(_composite(foreground, background));
  final second = _luminance(background);
  final lighter = math.max(first, second);
  final darker = math.min(first, second);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Every token, by name, so a pair can be reported readably.
Map<String, Color> _tokens(VineThemeColors c) => {
  'background': c.background,
  'card': c.card,
  'mediaCard': c.mediaCard,
  'surface': c.surface,
  'surfaceContainer': c.surfaceContainer,
  'surfaceContainerHigh': c.surfaceContainerHigh,
  'containerLow': c.containerLow,
  'primaryContainer': c.primaryContainer,
  'nav': c.nav,
  'onNav': c.onNav,
  'onNavMuted': c.onNavMuted,
  'iconButton': c.iconButton,
  'primaryText': c.primaryText,
  'secondaryText': c.secondaryText,
  'mutedText': c.mutedText,
  'onSurface': c.onSurface,
  'onSurfaceVariant': c.onSurfaceVariant,
  'onSurfaceMuted': c.onSurfaceMuted,
  'outline': c.outline,
  'outlineMuted': c.outlineMuted,
  'outlineDisabled': c.outlineDisabled,
  'disabled': c.disabled,
  'skeleton': c.skeleton,
  'errorContainer': c.errorContainer,
  'onErrorContainer': c.onErrorContainer,
  'accentPositive': c.accentPositive,
  'accentWarning': c.accentWarning,
  'inverseSurface': c.inverseSurface,
  'inverseOnSurface': c.inverseOnSurface,
  'mediaChrome': c.mediaChrome,
  'mediaChromeForeground': c.mediaChromeForeground,
};

/// Body-copy pairs, held to the WCAG AA normal-text ratio.
const _bodyPairs = <(String, String)>[
  ('primaryText', 'background'),
  ('primaryText', 'card'),
  ('primaryText', 'surface'),
  ('secondaryText', 'background'),
  ('secondaryText', 'surface'),
  ('onSurface', 'surface'),
  ('onSurface', 'card'),
  ('onSurface', 'surfaceContainer'),
  ('onSurface', 'containerLow'),
  ('onSurface', 'primaryContainer'),
  ('onNav', 'nav'),
  ('inverseOnSurface', 'inverseSurface'),
  // `mutedText` is `textTheme.bodySmall`'s color at fontSize 12, so it is
  // normal text by the WCAG threshold (18px / 14px bold), not large text.
  ('mutedText', 'background'),
  ('mutedText', 'card'),
  ('mutedText', 'surface'),
  // `accentWarning` labels the copy next to its icon ("Reconnect needed"), not
  // just the icon, so it is held to the body ratio rather than the 3:1 floor.
  ('accentWarning', 'background'),
  // `accentPositive` was icon-only when this list was written. It now colors
  // copy too — link text, active labels, the selected-row tick that is the
  // only marker of which row is chosen — on every app surface it reaches, so
  // it moved up from the 3:1 floor to the body ratio on each of them.
  ('accentPositive', 'background'),
  ('accentPositive', 'card'),
  ('accentPositive', 'surface'),
  ('accentPositive', 'surfaceContainer'),
  ('accentPositive', 'surfaceContainerHigh'),
];

/// Supporting copy — hints, placeholders, secondary labels — held to the
/// large-text ratio because that is the type size these tokens are used at.
const _supportingPairs = <(String, String)>[
  ('onSurfaceVariant', 'surface'),
  ('onSurfaceMuted', 'surface'),
  ('onErrorContainer', 'errorContainer'),
];

/// Token pairs that share a dark value while differing in light.
///
/// The migration's dark-value parity script (`check_dark_value_parity.dart`)
/// compares the DARK value of a removed constant against its replacement, so
/// these pairs are interchangeable as far as it — and the dark goldens — are
/// concerned. Picking the wrong one of a pair is a bug that only renders in
/// light mode. Freezing the inventory means a future palette edit that widens
/// this blind spot has to say so.
const _darkAmbiguousPairs = <(String, String)>[
  ('containerLow', 'outlineMuted'),
  ('iconButton', 'skeleton'),
  ('onNavMuted', 'disabled'),
  ('surfaceContainer', 'iconButton'),
  ('surfaceContainer', 'skeleton'),
];

void main() {
  group('VineTheme palettes', () {
    const palettes = <String, VineThemeColors>{
      'light': VineTheme.lightColors,
      'dark': VineTheme.darkColors,
    };

    group('legibility', () {
      // Both palettes are checked, not just light: a floor that only light has
      // to clear is a floor nobody maintains.
      palettes.forEach((name, colors) {
        final tokens = _tokens(colors);

        test('$name body copy clears WCAG AA (4.5:1)', () {
          for (final (foreground, background) in _bodyPairs) {
            expect(
              _contrast(tokens[foreground]!, tokens[background]!),
              greaterThanOrEqualTo(4.5),
              reason: '$name $foreground on $background',
            );
          }
        });

        test('$name supporting copy clears the large-text ratio (3:1)', () {
          for (final (foreground, background) in _supportingPairs) {
            expect(
              _contrast(tokens[foreground]!, tokens[background]!),
              greaterThanOrEqualTo(3),
              reason: '$name $foreground on $background',
            );
          }
        });
      });

      test('light never trails dark by more than a third on body copy', () {
        // Catches a light value that is technically legible but markedly
        // worse than its dark counterpart — the shape a hurried palette edit
        // takes when it only gets eyeballed in dark.
        final light = _tokens(VineTheme.lightColors);
        final dark = _tokens(VineTheme.darkColors);
        for (final (foreground, background) in _bodyPairs) {
          final lightRatio = _contrast(light[foreground]!, light[background]!);
          final darkRatio = _contrast(dark[foreground]!, dark[background]!);
          expect(
            lightRatio,
            greaterThanOrEqualTo(darkRatio * 2 / 3),
            reason: '$foreground on $background',
          );
        }
      });
    });

    group('dark-parity blind spots', () {
      test('only the inventoried pairs share a dark value', () {
        final light = _tokens(VineTheme.lightColors);
        final dark = _tokens(VineTheme.darkColors);
        final names = light.keys.toList();
        final found = <(String, String)>[];

        for (var i = 0; i < names.length; i++) {
          for (var j = i + 1; j < names.length; j++) {
            final first = names[i];
            final second = names[j];
            if (dark[first] == dark[second] && light[first] != light[second]) {
              found.add((first, second));
            }
          }
        }

        expect(
          found..sort((a, b) => '$a'.compareTo('$b')),
          List<(String, String)>.from(_darkAmbiguousPairs)
            ..sort((a, b) => '$a'.compareTo('$b')),
          reason:
              'A pair that collides in dark but not in light is invisible to '
              'the dark-value parity script and to the dark goldens. Add it '
              'here deliberately, or give the tokens distinct dark values.',
        );
      });

      test('tokens that collide in both palettes are intentional aliases', () {
        // These are the same colour by design, so a mis-pick between them is
        // not a rendering bug in either mode — only a naming one.
        final light = _tokens(VineTheme.lightColors);
        final dark = _tokens(VineTheme.darkColors);
        const aliases = <(String, String)>[
          ('surface', 'nav'),
          ('onNav', 'primaryText'),
          ('onNav', 'inverseSurface'),
          ('onNav', 'mediaChromeForeground'),
          ('primaryText', 'inverseSurface'),
          ('primaryText', 'mediaChromeForeground'),
          ('inverseSurface', 'mediaChromeForeground'),
        ];

        for (final (first, second) in aliases) {
          expect(dark[first], dark[second], reason: 'dark $first/$second');
          expect(light[first], light[second], reason: 'light $first/$second');
        }
      });
    });

    group('surfaces stay separable', () {
      palettes.forEach((name, colors) {
        test('$name keeps mediaCard clear of the surfaces it sits on', () {
          expect(colors.mediaCard, isNot(colors.card), reason: name);
          expect(colors.mediaCard, isNot(colors.surface), reason: name);
          expect(
            colors.mediaCard,
            isNot(colors.surfaceContainerHigh),
            reason: name,
          );
        });

        test('$name keeps its three outline weights distinct', () {
          expect(colors.outline, isNot(colors.outlineMuted), reason: name);
          expect(colors.outline, isNot(colors.outlineDisabled), reason: name);
          expect(
            colors.outlineMuted,
            isNot(colors.outlineDisabled),
            reason: name,
          );
        });
      });
    });
  });
}
