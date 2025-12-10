// ABOUTME: Handles NIP-19 TLV (Type-Length-Value) encoding/decoding for Nostr entities.
// ABOUTME: Supports nprofile, nevent, nrelay, and naddr encoding/decoding operations.

import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:bech32/bech32.dart';
import 'package:hex/hex.dart';

import 'hrps.dart';
import 'nip19.dart';
import 'tlv_util.dart';

class NIP19Tlv {
  static const noteReferences = "nostr:";

  static bool isNprofile(String text) {
    return Nip19.isKey(Hrps.nprofile, text);
  }

  static bool isNevent(String text) {
    return Nip19.isKey(Hrps.nevent, text);
  }

  static bool isNrelay(String text) {
    return Nip19.isKey(Hrps.nrelay, text);
  }

  static bool isNaddr(String text) {
    return Nip19.isKey(Hrps.naddr, text);
  }

  static List<int> _decodePreHandle(String text) {
    try {
      text = text.replaceAll(noteReferences, "");

      var decoder = Bech32Decoder();
      var bech32Result = decoder.convert(text, 1000);
      var buf = Nip19.convertBits(bech32Result.data, 5, 8, false);

      return buf;
    } catch (e) {
      return [];
    }
  }

  static Nprofile? decodeNprofile(String text) {
    List<int> buf = _decodePreHandle(text);

    String? pubkey;
    List<String> relays = [];

    int startIndex = 0;
    while (true) {
      var tlvData = TLVUtil.readTLVEntry(buf, startIndex: startIndex);
      if (tlvData == null) {
        break;
      }
      startIndex += tlvData.length + 2;

      if (tlvData.typ == TLVType.defaultType) {
        pubkey = HEX.encode(tlvData.data);
      } else if (tlvData.typ == TLVType.relay) {
        var relay = utf8.decode(tlvData.data);
        relays.add(relay);
      }
    }

    if (pubkey != null) {
      return Nprofile(pubkey: pubkey, relays: relays);
    }

    return null;
  }

  static Nevent? decodeNevent(String text) {
    List<int> buf = _decodePreHandle(text);

    String? id;
    List<String> relays = [];
    int? kind;
    String? author;

    int startIndex = 0;
    while (true) {
      var tlvData = TLVUtil.readTLVEntry(buf, startIndex: startIndex);
      if (tlvData == null) {
        break;
      }
      startIndex += tlvData.length + 2;

      if (tlvData.typ == TLVType.defaultType) {
        id = HEX.encode(tlvData.data);
      } else if (tlvData.typ == TLVType.relay) {
        var relay = utf8.decode(tlvData.data);
        relays.add(relay);
      } else if (tlvData.typ == TLVType.kind) {
        Uint8List byteList = Uint8List.fromList(tlvData.data);
        var byteData = ByteData.sublistView(byteList);
        kind = byteData.getInt32(0, Endian.big);
      } else if (tlvData.typ == TLVType.author) {
        author = HEX.encode(tlvData.data);
      }
    }

    if (id != null) {
      return Nevent(id: id, relays: relays, kind: kind, author: author);
    }

    return null;
  }

  static Nrelay? decodeNrelay(String text) {
    List<int> buf = _decodePreHandle(text);

    String? addr;

    int startIndex = 0;
    while (true) {
      var tlvData = TLVUtil.readTLVEntry(buf, startIndex: startIndex);
      if (tlvData == null) {
        break;
      }
      startIndex += tlvData.length + 2;

      if (tlvData.typ == TLVType.defaultType) {
        var relay = utf8.decode(tlvData.data);
        addr = relay;
      }
    }

    if (addr != null) {
      return Nrelay(addr);
    }

    return null;
  }

  static Naddr? decodeNaddr(String text) {
    try {
      List<int> buf = _decodePreHandle(text);

      String? id;
      String? author;
      int? kind;

      Map<String, int> relayMap = {};

      int startIndex = 0;
      while (true) {
        var tlvData = TLVUtil.readTLVEntry(buf, startIndex: startIndex);
        if (tlvData == null) {
          break;
        }
        startIndex += tlvData.length + 2;

        if (tlvData.typ == TLVType.defaultType) {
          id = utf8.decode(tlvData.data);
        } else if (tlvData.typ == TLVType.relay) {
          var relay = utf8.decode(tlvData.data);
          relayMap[relay] = 1;
        } else if (tlvData.typ == TLVType.kind) {
          Uint8List byteList = Uint8List.fromList(tlvData.data);
          var byteData = ByteData.sublistView(byteList);
          kind = byteData.getInt32(0, Endian.big);
        } else if (tlvData.typ == TLVType.author) {
          author = HEX.encode(tlvData.data);
        }
      }

      if (id != null && author != null && kind != null) {
        return Naddr(
          id: id,
          author: author,
          kind: kind,
          relays: relayMap.keys.toList(),
        );
      }

      return null;
    } catch (e) {
      log('$e');
    }
    return null;
  }

  static String _handleEncodeResult(String hrp, List<int> buf) {
    var encoder = Bech32Encoder();
    Bech32 input = Bech32(hrp, buf);
    return encoder.convert(input, 2000);
  }

  static String encodeNprofile(Nprofile o) {
    List<int> buf = [];
    TLVUtil.writeTLVEntry(buf, TLVType.defaultType, HEX.decode(o.pubkey));
    if (o.relays != null) {
      for (var relay in o.relays!) {
        TLVUtil.writeTLVEntry(buf, TLVType.relay, utf8.encode(relay));
      }
    }

    buf = Nip19.convertBits(buf, 8, 5, true);

    return _handleEncodeResult(Hrps.nprofile, buf);
  }

  static String encodeNevent(Nevent o) {
    List<int> buf = [];
    TLVUtil.writeTLVEntry(buf, TLVType.defaultType, HEX.decode(o.id));
    if (o.relays != null) {
      for (var relay in o.relays!) {
        TLVUtil.writeTLVEntry(buf, TLVType.relay, utf8.encode(relay));
      }
    }
    if (o.author != null) {
      TLVUtil.writeTLVEntry(buf, TLVType.author, HEX.decode(o.author!));
    }

    buf = Nip19.convertBits(buf, 8, 5, true);

    return _handleEncodeResult(Hrps.nevent, buf);
  }

  static String encodeNrelay(Nrelay o) {
    List<int> buf = [];
    TLVUtil.writeTLVEntry(buf, TLVType.defaultType, utf8.encode(o.addr));

    buf = Nip19.convertBits(buf, 8, 5, true);

    return _handleEncodeResult(Hrps.nrelay, buf);
  }

  static String encodeNaddr(Naddr o) {
    List<int> buf = [];
    TLVUtil.writeTLVEntry(buf, TLVType.defaultType, utf8.encode(o.id));
    TLVUtil.writeTLVEntry(buf, TLVType.author, HEX.decode(o.author));
    TLVUtil.writeTLVEntry(
      buf,
      TLVType.kind,
      Uint8List(4)..buffer.asByteData().setInt32(0, o.kind, Endian.big),
    );
    if (o.relays != null) {
      for (var relay in o.relays!) {
        TLVUtil.writeTLVEntry(buf, TLVType.relay, utf8.encode(relay));
      }
    }

    buf = Nip19.convertBits(buf, 8, 5, true);

    return _handleEncodeResult(Hrps.naddr, buf);
  }
}

class Nprofile {
  String pubkey;

  List<String>? relays;

  Nprofile({required this.pubkey, this.relays});
}

class Nevent {
  String id;

  List<String>? relays;

  int? kind;

  String? author;

  Nevent({required this.id, this.relays, this.kind, this.author});

  @override
  String toString() {
    return "$kind $id $author ${relays != null ? relays!.join(",") : ""}";
  }
}

class Nrelay {
  String addr;

  Nrelay(this.addr);
}

class Naddr {
  String id;

  String author;

  int kind;

  List<String>? relays;

  Naddr({
    required this.id,
    required this.author,
    required this.kind,
    this.relays,
  });

  @override
  String toString() {
    return "naddr ($kind $author $id ${relays != null ? relays!.join(",") : ""})";
  }
}
