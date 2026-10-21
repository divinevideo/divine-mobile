// RFC 3492 codec ported from punycode.js 2.3.1 (Mathias Bynens, MIT).
// Provenance and license: third_party/tr46/SOURCE.md and PUNYCODE-LICENSE.txt.
const _maxInt = 2147483647;

Never _invalid() => throw const FormatException('Invalid Punycode');
int _digit(int code) {
  if (code >= 48 && code <= 57) return code - 22;
  if (code >= 65 && code <= 90) return code - 65;
  if (code >= 97 && code <= 122) return code - 97;
  return 36;
}

int _adapt(int delta, int points, bool first) {
  var value = first ? delta ~/ 700 : delta >> 1;
  value += value ~/ points;
  var k = 0;
  while (value > 455) {
    value ~/= 35;
    k += 36;
  }
  return k + (36 * value) ~/ (value + 38);
}

/// RFC 3492 decoding without Unicode case folding or IDNA label processing.
String decodePunycode(String input) {
  final output = <int>[];
  var n = 128;
  var i = 0;
  var bias = 72;
  final basic = input.lastIndexOf('-');
  for (var j = 0; j < basic; j++) {
    final cp = input.codeUnitAt(j);
    if (cp >= 128) _invalid();
    output.add(cp);
  }
  var index = basic > 0 ? basic + 1 : 0;
  while (index < input.length) {
    final old = i;
    var weight = 1;
    for (var k = 36; ; k += 36) {
      if (index >= input.length) _invalid();
      final digit = _digit(input.codeUnitAt(index++));
      if (digit >= 36 || digit > (_maxInt - i) ~/ weight) _invalid();
      i += digit * weight;
      final t = k <= bias
          ? 1
          : k >= bias + 26
          ? 26
          : k - bias;
      if (digit < t) break;
      if (weight > _maxInt ~/ (36 - t)) _invalid();
      weight *= 36 - t;
    }
    final length = output.length + 1;
    bias = _adapt(i - old, length, old == 0);
    if (i ~/ length > _maxInt - n) _invalid();
    n += i ~/ length;
    i %= length;
    if (n > 0x10ffff) _invalid();
    output.insert(i++, n);
  }
  return String.fromCharCodes(output);
}

/// RFC 3492 encoding with punycode.js's checked 31-bit arithmetic.
String encodePunycode(String input) {
  final points = input.runes.toList();
  final output = <int>[];
  var n = 128;
  var delta = 0;
  var bias = 72;
  for (final point in points) {
    if (point < 128) output.add(point);
  }
  var handled = output.length;
  final basic = handled;
  if (basic > 0) output.add(45);
  while (handled < points.length) {
    var m = _maxInt;
    for (final point in points) {
      if (point >= n && point < m) m = point;
    }
    if (m - n > (_maxInt - delta) ~/ (handled + 1)) _invalid();
    delta += (m - n) * (handled + 1);
    n = m;
    for (final point in points) {
      if (point < n && ++delta > _maxInt) _invalid();
      if (point != n) continue;
      var q = delta;
      for (var k = 36; ; k += 36) {
        final t = k <= bias
            ? 1
            : k >= bias + 26
            ? 26
            : k - bias;
        if (q < t) break;
        final digit = t + (q - t) % (36 - t);
        output.add(digit < 26 ? digit + 97 : digit + 22);
        q = (q - t) ~/ (36 - t);
      }
      output.add(q < 26 ? q + 97 : q + 22);
      bias = _adapt(delta, handled + 1, handled == basic);
      delta = 0;
      handled++;
    }
    delta++;
    n++;
  }
  return String.fromCharCodes(output);
}
