import 'package:bech32/bech32.dart';

class ZapCoder {
  static Bech32 decode(String text) {
    var decoder = Bech32Decoder();
    var bech32Result = decoder.convert(text, 1000);
    return bech32Result;
  }
}
