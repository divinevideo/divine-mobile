// // copy from
// // https://github.com/fusion44/dart_nostr/blob/main/lib/src/bech32.dart

// import 'dart:typed_data' as typed;

// class Bech32DecodeResult {
//   final String hrp;
//   final List<int> words;

//   Bech32DecodeResult(this.hrp, this.words);
// }

// class Bech32 {
//   static const _charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
//   static const _lenCharset = _charset.length;
//   static const _generator = [
//     0x3b6a57b2,
//     0x26508e6d,
//     0x1ea119fa,
//     0x3d4233dd,
//     0x2a1462b3
//   ];

//   static Bech32DecodeResult decode(String bechStr) {
//     // Only ASCII characters between 33 and 126 are allowed.
//     for (var i = 0; i < bechStr.length; i++) {
//       if (bechStr.codeUnitAt(i) < 33 || bechStr.codeUnitAt(i) > 126) {
//         throw FormatException('invalid character in string: ${bechStr[i]}');
//       }
//     }

//     // The characters must be either all lowercase or all uppercase.
//     var lower = bechStr.toLowerCase();
//     var upper = bechStr.toUpperCase();
//     if (bechStr != lower && bechStr != upper) {
//       throw FormatException('string not all lowercase or all uppercase');
//     }

//     // We'll work with the lowercase string from now on.
//     final bech = lower;

//     // The string is invalid if the last '1' is non-existent, it is the
//     // first character of the string (no human-readable part) or one of the
//     // last 6 characters of the string (since checksum cannot contain '1'),
//     // or if the string is more than 90 characters in total.
//     var one = bech.lastIndexOf('1');
//     if (one < 1 || one + 7 > bech.length) {
//       throw FormatException('invalid index of 1');
//     }

//     // The human-readable part is everything before the last '1'.
//     var hrp = bech.substring(0, one);
//     var data = bech.substring(one + 1);

//     // Each character corresponds to the byte with value of the index in
//     // 'charset'.
//     var decoded = toBytes(data);
//     if (!_verifyChecksum(hrp, decoded)) {
//       var moreInfo = '';
//       var checksum = bech.substring(bech.length - 6);
//       var expected =
//           toChars(_createChecksum(hrp, decoded.sublist(0, decoded.length - 6)));
//       moreInfo = 'Expected $expected, got $checksum.';
//       throw FormatException('checksum failed. $moreInfo');
//     }

//     // We exclude the last 6 bytes, which is the checksum.
//     // return Bech32DecodeResult(hrp, decoded.sublist(0, decoded.length - 6));
//     return Bech32DecodeResult(hrp, decoded);
//   }

//   static String encode(String hrp, List<int> data) {
//     // Calculate the checksum of the data and append it at the end.
//     var checksum = _createChecksum(hrp, data);
//     final combined = <int>[...data, ...checksum];

//     // The resulting bech32 string is the concatenation of the hrp, the
//     // separator 1, data and checksum. Everything after the separator is
//     // represented using the specified charset.
//     final chars = toChars(combined);

//     return '${hrp}1$chars';
//   }

//   static List<int> _createChecksum(String hrp, List<int> data) {
//     var integers = List<int>.from(data);
//     var values = <int>[..._hrpExpand(hrp), ...integers, 0, 0, 0, 0, 0, 0];
//     var polymod = _polymod(values) ^ 1;
//     var res = <int>[];
//     for (var i = 0; i < 6; i++) {
//       res.add((polymod >> (5 * (5 - i))) & 31);
//     }

//     return res;
//   }

//   static bool _verifyChecksum(String hrp, List<int> data) {
//     var integers = List<int>.from(data);
//     var concat = <int>[..._hrpExpand(hrp), ...integers];

//     return _polymod(concat) == 1;
//   }

//   static int _polymod(List<int> values) {
//     var chk = 1;
//     for (var v in values) {
//       var b = chk >> 25;
//       chk = (chk & 0x1ffffff) << 5 ^ v;
//       for (var i = 0; i < 5; i++) {
//         if ((b >> i) & 1 == 1) {
//           chk ^= _generator[i];
//         }
//       }
//     }

//     return chk;
//   }

//   static List<int> _hrpExpand(String hrp) {
//     var v = <int>[];
//     for (var i = 0; i < hrp.length; i++) {
//       v.add(hrp.codeUnitAt(i) >> 5);
//     }
//     v.add(0);
//     for (var i = 0; i < hrp.length; i++) {
//       v.add(hrp.codeUnitAt(i) & 31);
//     }

//     return v;
//   }

//   static List<int> toBytes(String chars) {
//     var decoded = <int>[];
//     for (var i = 0; i < chars.length; i++) {
//       var index = _charset.indexOf(chars[i]);
//       if (index < 0) {
//         throw FormatException(
//             'invalid character not part of charset: ${chars[i]}');
//       }
//       decoded.add(index);
//     }

//     return decoded;
//   }

//   static String toChars(List<int> data) {
//     var result = '';

//     for (var b in data) {
//       if (b > _lenCharset) {
//         throw FormatException('invalid character not part of charset: $b');
//       }
//       final char = _charset[b];
//       result += char;
//     }

//     return result;
//   }

//   static typed.Uint8List convertBits(
//       List<int> data, int fromBits, int toBits, bool pad) {
//     if (fromBits < 1 || fromBits > 8 || toBits < 1 || toBits > 8) {
//       throw FormatException('only bit groups between 1 and 8 allowed');
//     }

//     // The final bytes, each byte encoding toBits bits.
//     var regrouped = <int>[];

//     // Keep track of the next byte we create and how many bits we have
//     // added to it out of the toBits goal.
//     var nextByte = 0;
//     var filledBits = 0;

//     for (var b in data) {
//       // Discard unused bits.
//       b = b << (8 - fromBits);

//       // How many bits remaining to extract from the input data.
//       var remFromBits = fromBits;
//       while (remFromBits > 0) {
//         // How many bits remaining to be added to the next byte.
//         var remToBits = toBits - filledBits;

//         // The number of bytes to next extract is the minimum of
//         // remFromBits and remToBits.
//         var toExtract = remFromBits;
//         if (remToBits < toExtract) {
//           toExtract = remToBits;
//         }

//         // Add the next bits to nextByte, shifting the already
//         // added bits to the left.
//         nextByte = (nextByte << toExtract) | (b >> (8 - toExtract));

//         // Discard the bits we just extracted and get ready for
//         // next iteration and mask to a valid byte value.
//         b = (b << toExtract) & 0xff;
//         remFromBits -= toExtract;
//         filledBits += toExtract;

//         // If the nextByte is completely filled, we add it to
//         // our regrouped bytes and start on the next byte.
//         if (filledBits == toBits) {
//           regrouped.add(nextByte);
//           filledBits = 0;
//           nextByte = 0;
//         }
//       }
//     }

//     // We pad any unfinished group if specified.
//     if (pad && filledBits > 0) {
//       nextByte = nextByte << (toBits - filledBits);
//       regrouped.add(nextByte);
//       filledBits = 0;
//       nextByte = 0;
//     }

//     // Any incomplete group must be <= 4 bits, and all zeroes.
//     if (filledBits > 0 && (filledBits > 4 || nextByte != 0)) {
//       throw FormatException('invalid incomplete group');
//     }

//     return typed.Uint8List.fromList(regrouped);
//   }
// }
