// Port of jsdom/tr46 6.0.0's nontransitional WHATWG processing path.
// Copyright tr46 contributors. MIT license and provenance in third_party/tr46.
import 'package:challenge_protocol/src/normalization.dart';
import 'package:challenge_protocol/src/punycode.dart';
import 'package:challenge_protocol/src/tr46_data.g.dart' as data;

/// WHATWG domain-to-ASCII processing (Unicode 17, nontransitional).
///
/// CheckBidi and CheckJoiners are enabled; CheckHyphens, UseSTD3ASCIIRules and
/// VerifyDnsLength are disabled. Returns null for invalid input. URL-specific
/// forbidden domain characters and numeric IPv4 processing remain in the
/// caller.
String? domainToAscii(String input) {
  final mapped = StringBuffer();
  for (final rune in input.runes) {
    final record = _status(rune);
    switch (record.$3) {
      case 1:
        mapped.write(record.$4);
      case 7:
        break;
      default:
        mapped.writeCharCode(rune);
    }
  }
  final labels = normalizeNfc(mapped.toString()).split('.');
  final bidiDomain = data.bidiDomain.hasMatch(
    labels
        .map((label) {
          if (!label.startsWith('xn--')) return label;
          try {
            return decodePunycode(label.substring(4));
          } on FormatException {
            return '';
          }
        })
        .join('.'),
  );
  for (var i = 0; i < labels.length; i++) {
    var label = labels[i];
    if (label.startsWith('xn--')) {
      if (_nonAscii(label)) return null;
      try {
        label = decodePunycode(label.substring(4));
      } on FormatException {
        return null;
      }
      if (label.isEmpty || !_nonAscii(label)) return null;
    }
    if (!_validLabel(label, bidiDomain)) return null;
    try {
      labels[i] = _nonAscii(label) ? 'xn--${encodePunycode(label)}' : label;
    } on FormatException {
      return null;
    }
  }
  return labels.join('.');
}

bool _nonAscii(String text) => text.codeUnits.any((code) => code > 0x7f);

(int, int, int, String) _status(int code) {
  var low = 0;
  var high = data.tr46Mapping.length - 1;
  while (low <= high) {
    final mid = (low + high) ~/ 2;
    final record = data.tr46Mapping[mid];
    if (code < record.$1) {
      high = mid - 1;
    } else if (code > record.$2) {
      low = mid + 1;
    } else {
      return record;
    }
  }
  return (code, code, 3, '');
}

bool _validLabel(String label, bool bidiDomain) {
  if (label.isEmpty) return true;
  if (normalizeNfc(label) != label ||
      label.startsWith('xn--') ||
      label.contains('.')) {
    return false;
  }
  final points = label.runes.map(String.fromCharCode).toList();
  if (data.combiningMarks.hasMatch(points.first)) return false;
  for (final code in label.runes) {
    final status = _status(code).$3;
    if (status != 2 && status != 6) return false;
  }
  var last = 0;
  for (var i = 0; i < points.length; i++) {
    final ch = points[i];
    if (ch != '\u200c' && ch != '\u200d') continue;
    if (i > 0) {
      if (data.combiningClassVirama.hasMatch(points[i - 1])) continue;
      if (ch == '\u200c') {
        final next = points.indexOf('\u200c', i + 1);
        final span = points.sublist(last, next < 0 ? points.length : next);
        if (data.validZWNJ.hasMatch(span.join())) {
          last = i + 1;
          continue;
        }
      }
    }
    return false;
  }
  if (bidiDomain) {
    if (data.bidiS1RTL.hasMatch(points.first)) {
      if (!data.bidiS2.hasMatch(label) ||
          !data.bidiS3.hasMatch(label) ||
          (data.bidiS4EN.hasMatch(label) && data.bidiS4AN.hasMatch(label))) {
        return false;
      }
    } else if (data.bidiS1LTR.hasMatch(points.first)) {
      if (!data.bidiS5.hasMatch(label) || !data.bidiS6.hasMatch(label)) {
        return false;
      }
    } else {
      return false;
    }
  }
  return true;
}
