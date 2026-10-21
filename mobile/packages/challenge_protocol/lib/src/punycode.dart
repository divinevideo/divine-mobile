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
  final basicPoints = <int>[];
  final insertions = <(int, int)>[];
  var n = 128;
  var i = 0;
  var bias = 72;
  final basic = input.lastIndexOf('-');
  for (var j = 0; j < basic; j++) {
    final cp = input.codeUnitAt(j);
    if (cp >= 128) _invalid();
    basicPoints.add(cp);
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
    final length = basicPoints.length + insertions.length + 1;
    bias = _adapt(i - old, length, old == 0);
    if (i ~/ length > _maxInt - n) _invalid();
    n += i ~/ length;
    i %= length;
    if (n > 0x10ffff) _invalid();
    insertions.add((i++, n));
  }
  // Reconstruct in reverse: each recorded insertion occupies the corresponding
  // still-empty slot. Order statistics avoid shifting the growing output list.
  final length = basicPoints.length + insertions.length;
  final slots = _Positions(length, filled: true);
  final output = List<int>.filled(length, 0);
  for (final (position, code) in insertions.reversed) {
    final slot = slots.select(position);
    output[slot] = code;
    slots.add(slot, -1);
  }
  for (final code in basicPoints) {
    final slot = slots.select(0);
    output[slot] = code;
    slots.add(slot, -1);
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
  final positions = _Positions(points.length);
  final nonBasic = <int>[];
  for (var index = 0; index < points.length; index++) {
    if (points[index] < 128) {
      positions.add(index, 1);
    } else {
      nonBasic.add(index);
    }
  }
  nonBasic.sort((a, b) {
    final byCode = points[a].compareTo(points[b]);
    return byCode == 0 ? a.compareTo(b) : byCode;
  });
  var at = 0;
  while (at < nonBasic.length) {
    final m = points[nonBasic[at]];
    if (m - n > (_maxInt - delta) ~/ (handled + 1)) _invalid();
    delta += (m - n) * (handled + 1);
    n = m;
    final groupStart = at;
    var previous = 0;
    while (at < nonBasic.length && points[nonBasic[at]] == m) {
      final index = nonBasic[at++];
      // Only codepoints below n increment delta in the RFC's input scan.
      delta += positions.before(index) - positions.before(previous);
      if (delta > _maxInt) _invalid();
      previous = index + 1;
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
    delta += positions.before(points.length) - positions.before(previous);
    if (delta > _maxInt) _invalid();
    for (var j = groupStart; j < at; j++) {
      positions.add(nonBasic[j], 1);
    }
    delta++;
    n++;
  }
  return String.fromCharCodes(output);
}

// Fenwick prefix counts: O(log n) update, prefix count and order selection.
final class _Positions {
  _Positions(int length, {bool filled = false})
    : _tree = List<int>.generate(
        length + 1,
        (index) => filled ? index & -index : 0,
      );

  final List<int> _tree;

  void add(int position, int delta) {
    for (
      var index = position + 1;
      index < _tree.length;
      index += index & -index
    ) {
      _tree[index] += delta;
    }
  }

  int before(int position) {
    var count = 0;
    for (var index = position; index > 0; index -= index & -index) {
      count += _tree[index];
    }
    return count;
  }

  int select(int rank) {
    var remaining = rank;
    var index = 0;
    var step = 1;
    while (step < _tree.length) {
      step <<= 1;
    }
    for (; step > 0; step >>= 1) {
      final candidate = index + step;
      if (candidate < _tree.length && _tree[candidate] <= remaining) {
        index = candidate;
        remaining -= _tree[candidate];
      }
    }
    return index;
  }
}
