// Unicode 17 NFC using the exact unorm_dart 0.3.2 data and Hangul lookup.
// Algorithm: UAX #15 canonical decomposition, stable ordering, composition.
// This adapter intentionally uses the pinned package's data API, not its
// quadratic iterator buffers. See third_party/tr46/SOURCE.md.
// ignore: implementation_imports
import 'package:unorm_dart/src/uchar.dart';

/// Canonical normalization with O(n log n) ordering and append-only buffers.
String normalizeNfc(String input) {
  initUCharCache();
  final decomposed = <(UChar, int, int)>[];
  void decompose(UChar char) {
    final mapping = char.getDecomp();
    if (mapping == null || char.isCompatibility()) {
      decomposed.add((char, char.getCanonicalClass(), decomposed.length));
    } else {
      for (final code in mapping) {
        decompose(UChar.fromCharCode(code, false)!);
      }
    }
  }

  for (final code in input.runes) {
    decompose(UChar.fromCharCode(code, false)!);
  }
  final ordered = <(UChar, int, int)>[];
  var at = 0;
  while (at < decomposed.length) {
    if (decomposed[at].$2 == 0) {
      ordered.add(decomposed[at++]);
      continue;
    }
    final start = at;
    while (at < decomposed.length && decomposed[at].$2 != 0) {
      at++;
    }
    final marks = decomposed.sublist(start, at)
      ..sort((a, b) {
        final byClass = a.$2.compareTo(b.$2);
        // Explicit original position makes equal-class ordering stable.
        return byClass == 0 ? a.$3.compareTo(b.$3) : byClass;
      });
    ordered.addAll(marks);
  }
  final output = <UChar>[];
  var starter = 0;
  var lastClass = -1;
  for (final (char, canonicalClass, _) in ordered) {
    final composite = output.isEmpty
        ? null
        : output[starter].getComposite(char);
    if (composite != null && (lastClass < canonicalClass || lastClass == 0)) {
      output[starter] = composite;
    } else {
      if (canonicalClass == 0) starter = output.length;
      output.add(char);
      lastClass = canonicalClass;
    }
  }
  return String.fromCharCodes(output.map((char) => char.codepoint));
}
