import 'package:bech32/bech32.dart';
import 'package:hex/hex.dart';

import 'hrps.dart';

class Nip19 {
  // static String encodePubKey(String pubkey) {
  //   var data = hex.decode(pubkey);
  //   data = Bech32.convertBits(data, 8, 5, true);
  //   return Bech32.encode(Hrps.PUBLIC_KEY, data);
  // }

  static Map<String, int>? charMap;

  // sometimes bech32 is mix with some other chat at the end
  static int? checkBech32End(String text) {
    if (charMap == null) {
      charMap = <String, int>{};
      for (var chat in charset) {
        charMap![chat] = 1;
      }
    }

    var startIndex = text.indexOf("1");
    var length = text.length;
    for (var i = startIndex + 1; i < length; i++) {
      var char = text.substring(i, i + 1);
      if (charMap![char] == null) {
        return i;
      }
    }

    return null;
  }

  static bool isKey(String hrp, String str) {
    if (str.indexOf(hrp) == 0) {
      return true;
    } else {
      return false;
    }
  }

  static bool isPubkey(String str) {
    return isKey(Hrps.PUBLIC_KEY, str);
  }

  static String encodePubKey(String pubkey) {
    // var data = HEX.decode(pubkey);
    // data = _convertBits(data, 8, 5, true);

    // var encoder = Bech32Encoder();
    // Bech32 input = Bech32(Hrps.PUBLIC_KEY, data);
    // return encoder.convert(input);
    return _encodeKey(Hrps.PUBLIC_KEY, pubkey);
  }

  static String encodeSimplePubKey(String pubkey) {
    try {
      var code = encodePubKey(pubkey);
      var length = code.length;
      return "${code.substring(0, 6)}:${code.substring(length - 6)}";
    } catch (e) {
      if (pubkey.length > 12) {
        return pubkey.substring(0, 13);
      } else {
        return pubkey;
      }
    }
  }

  // static String decode(String npub) {
  //   var res = Bech32.decode(npub);
  //   var data = Bech32.convertBits(res.words, 5, 8, false);
  //   return hex.encode(data).substring(0, 64);
  // }
  static String decode(String npub) {
    try {
      var decoder = Bech32Decoder();
      var bech32Result = decoder.convert(npub);
      var data = convertBits(bech32Result.data, 5, 8, false);
      return HEX.encode(data);
    } catch (e) {
      print("Nip19 decode error ${e.toString()}");
      return "";
    }
  }

  static String _encodeKey(String hrp, String key) {
    var data = HEX.decode(key);
    data = convertBits(data, 8, 5, true);

    var encoder = Bech32Encoder();
    Bech32 input = Bech32(hrp, data);
    return encoder.convert(input);
  }

  static bool isPrivateKey(String str) {
    return isKey(Hrps.PRIVATE_KEY, str);
  }

  static String encodePrivateKey(String privateKey) {
    return _encodeKey(Hrps.PRIVATE_KEY, privateKey);
  }

  static bool isNoteId(String str) {
    return isKey(Hrps.NOTE_ID, str);
  }

  static String encodeNoteId(String id) {
    return _encodeKey(Hrps.NOTE_ID, id);
  }

  static List<int> convertBits(List<int> data, int from, int to, bool pad) {
    var acc = 0;
    var bits = 0;
    var result = <int>[];
    var maxv = (1 << to) - 1;

    for (var v in data) {
      if (v < 0 || (v >> from) != 0) {
        throw Exception();
      }
      acc = (acc << from) | v;
      bits += from;
      while (bits >= to) {
        bits -= to;
        result.add((acc >> bits) & maxv);
      }
    }

    if (pad) {
      if (bits > 0) {
        result.add((acc << (to - bits)) & maxv);
      }
    } else if (bits >= from) {
      throw InvalidPadding('illegal zero padding');
    } else if (((acc << (to - bits)) & maxv) != 0) {
      throw InvalidPadding('non zero');
    }

    return result;
  }
}
