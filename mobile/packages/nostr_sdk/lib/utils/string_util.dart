import 'dart:math';

class StringUtil {
  static bool isNotBlank(String? str) {
    if (str != null && str != "") {
      return true;
    }
    return false;
  }

  static bool isBlank(String? str) {
    return !isNotBlank(str);
  }

  static String breakWord(String word) {
    if (word.isEmpty) {
      return word;
    }
    String breakWord = '';
    for (var element in word.runes) {
      breakWord += String.fromCharCode(element);
      breakWord += '\u200B';
    }
    return breakWord;
  }

  static List<String> charByChar(String word) {
    // var runes = word.runes;
    // var length = runes.length;
    List<String> letters = [];
    for (var rune in word.runes) {
      var character = String.fromCharCode(rune);
      letters.add(character);
    }
    return letters;
  }

  static final List<String> _rndHex = [
    "0",
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "0",
    "A",
    "B",
    "C",
    "D",
    "E",
    "F",
    "G",
    "H",
    "I",
    "J",
    "K",
    "L",
    "M",
    "N",
    "O",
    "P",
    "Q",
    "R",
    "S",
    "T",
    "U",
    "V",
    "W",
    "X",
    "Y",
    "Z",
    "a",
    "b",
    "c",
    "d",
    "e",
    "f",
    "g",
    "h",
    "i",
    "j",
    "k",
    "l",
    "m",
    "n",
    "o",
    "p",
    "q",
    "r",
    "s",
    "t",
    "u",
    "v",
    "w",
    "x",
    "y",
    "z"
  ];

  static String rndStr(int length) {
    int l = _rndHex.length;
    var random = Random();
    String str = "";
    for (int i = 0; i < length; i++) {
      int idx = random.nextInt(l);
      str += _rndHex[idx];
    }
    return str;
  }

  static final List<String> _rndNameHex = [
    "0",
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "0",
    "a",
    "b",
    "c",
    "d",
    "e",
    "f",
    "g",
    "h",
    "i",
    "j",
    "k",
    "l",
    "m",
    "n",
    "o",
    "p",
    "q",
    "r",
    "s",
    "t",
    "u",
    "v",
    "w",
    "x",
    "y",
    "z"
  ];

  static String rndNameStr(int length) {
    int l = _rndNameHex.length;
    var random = Random();
    String str = "";
    for (int i = 0; i < length; i++) {
      int idx = random.nextInt(l);
      str += _rndNameHex[idx];
    }
    return str;
  }

  static List<int> findAllIndex(String text, String match) {
    var matchLength = match.length;
    var textLength = match.length;
    var indexStart = 0;

    List<int> indexs = [];

    var index = text.indexOf(match, indexStart);
    while (index > -1 || indexStart >= textLength) {
      indexs.add(index);
      indexStart += matchLength;
    }

    return indexs;
  }
}
