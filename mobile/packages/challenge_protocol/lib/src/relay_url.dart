part of '../challenge_protocol.dart';

// WHATWG URL special-scheme parsing, restricted to the properties the canonical
// relay check observes. Path/query serialization cannot affect this decision.
// https://url.spec.whatwg.org/#url-parsing
bool _validRelayUrl(String input) {
  final value = input
      .replaceAll(RegExp(r'^[\x00-\x20]+|[\x00-\x20]+$'), '')
      .replaceAll(RegExp(r'[\t\r\n]'), '');
  final scheme = RegExp('^wss?:', caseSensitive: false).firstMatch(value);
  if (scheme == null) return false;
  final fragment = value.indexOf('#');
  if (fragment >= 0 && fragment != value.length - 1) return false;
  var offset = scheme.end;
  while (offset < value.length &&
      (value[offset] == '/' || value[offset] == r'\')) {
    offset++;
  }
  final end = value.indexOf(RegExp(r'[/\\?#]'), offset);
  var authority = value.substring(offset, end < 0 ? value.length : end);
  final at = authority.lastIndexOf('@');
  if (at >= 0) {
    // An empty username and password serialize as either "" or ":" here.
    // Any earlier @ is percent-encoded by the URL parser into the username.
    final credentials = authority.substring(0, at);
    if (credentials.isNotEmpty && credentials != ':') return false;
    authority = authority.substring(at + 1);
  }
  if (authority.isEmpty) return false;
  String host;
  String port;
  if (authority.startsWith('[')) {
    final close = authority.indexOf(']');
    if (close < 0) return false;
    host = authority.substring(1, close);
    final suffix = authority.substring(close + 1);
    if (suffix.isNotEmpty && !suffix.startsWith(':')) return false;
    port = suffix.isEmpty ? '' : suffix.substring(1);
    if (!_validIpv6(host)) return false;
  } else {
    final colon = authority.indexOf(':');
    host = colon < 0 ? authority : authority.substring(0, colon);
    port = colon < 0 ? '' : authority.substring(colon + 1);
    try {
      // The special-host parser percent-decodes before domain processing.
      host = _decodeHost(host);
    } on FormatException {
      return false;
    }
    final asciiHost = idna.domainToAscii(host);
    if (asciiHost == null) return false;
    host = asciiHost;
    if (host.isEmpty ||
        RegExp(r'[\x00-\x20\x7F#%/:<>?@\[\\\]^|]').hasMatch(host)) {
      return false;
    }
    if (!_validIpv4OrDomain(host)) return false;
  }
  if (port.isNotEmpty) {
    if (!RegExp(r'^[0-9]+$').hasMatch(port)) return false;
    final number = BigInt.tryParse(port);
    if (number == null || number > BigInt.from(65535)) return false;
  }
  return true;
}

String _decodeHost(String host) {
  final bytes = utf8.encode(host);
  final decoded = <int>[];
  for (var at = 0; at < bytes.length; at++) {
    if (bytes[at] != 0x25) {
      decoded.add(bytes[at]);
      continue;
    }
    if (at + 2 >= bytes.length) {
      throw const FormatException('Incomplete host escape');
    }
    final pair = String.fromCharCodes(bytes.sublist(at + 1, at + 3));
    if (!RegExp(r'^[0-9a-fA-F]{2}$').hasMatch(pair)) {
      throw const FormatException('Invalid host escape');
    }
    decoded.add(int.parse(pair, radix: 16));
    at += 2;
  }
  return utf8.decode(decoded);
}

// https://url.spec.whatwg.org/#concept-ipv4-parser
bool _validIpv4OrDomain(String domain) {
  final parts = domain.split('.');
  if (parts.length > 1 && parts.last.isEmpty) parts.removeLast();
  final last = parts.last;
  final endsInNumber =
      RegExp(r'^[0-9]+$').hasMatch(last) || _ipv4Number(last) != null;
  if (!endsInNumber) return true;
  if (parts.length > 4) return false;
  final numbers = parts.map(_ipv4Number).toList();
  if (numbers.any((number) => number == null)) return false;
  for (var i = 0; i < numbers.length - 1; i++) {
    if (numbers[i]! > BigInt.from(255)) return false;
  }
  return numbers.last! < (BigInt.one << (8 * (5 - parts.length)));
}

BigInt? _ipv4Number(String input) {
  if (input.isEmpty) return null;
  var digits = input;
  var radix = 10;
  if (digits.length >= 2 && digits.substring(0, 2).toLowerCase() == '0x') {
    digits = digits.substring(2);
    radix = 16;
  } else if (digits.length >= 2 && digits.startsWith('0')) {
    digits = digits.substring(1);
    radix = 8;
  }
  if (digits.isEmpty) return BigInt.zero;
  final allowed = switch (radix) {
    16 => RegExp(r'^[0-9a-fA-F]+$'),
    8 => RegExp(r'^[0-7]+$'),
    _ => RegExp(r'^[0-9]+$'),
  };
  if (!allowed.hasMatch(digits)) return null;
  return BigInt.tryParse(digits, radix: radix);
}

bool _validIpv6(String host) {
  if (host.contains('%')) return false;
  if (host.contains('.')) {
    final tail = host.substring(host.lastIndexOf(':') + 1).split('.');
    if (tail.length != 4) return false;
    for (final part in tail) {
      if (!RegExp(r'^(0|[1-9][0-9]{0,2})$').hasMatch(part) ||
          int.parse(part) > 255) {
        return false;
      }
    }
  }
  try {
    Uri.parseIPv6Address(host);
    return true;
  } on FormatException {
    return false;
  }
}
