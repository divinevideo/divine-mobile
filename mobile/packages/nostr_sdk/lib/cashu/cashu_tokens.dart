import 'dart:convert';

class Tokens {
  List<Token>? token;
  String? memo;

  Tokens({this.token, this.memo});

  Tokens.fromJson(Map<String, dynamic> json) {
    if (json['token'] != null) {
      token = <Token>[];
      json['token'].forEach((v) {
        token!.add(Token.fromJson(v));
      });
    }
    memo = json['memo'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (token != null) {
      data['token'] = token!.map((v) => v.toJson()).toList();
    }
    data['memo'] = memo;
    return data;
  }

  static Tokens? load(String cashuStr) {
    if (cashuStr.indexOf("cashu") == 0) {
      if (cashuStr.substring(5, 6) == "A") {
        var base64Json = cashuStr.substring(6);
        base64Json = base64Url.normalize(base64Json);
        var jsonData = base64Url.decode(base64Json);
        var jsonObj = jsonDecode(utf8.decode(jsonData));
        return Tokens.fromJson(jsonObj);
      }
    }
    return null;
  }

  int totalAmount() {
    var ta = 0;
    if (token != null) {
      for (var t in token!) {
        if (t.proofs != null) {
          for (var p in t.proofs!) {
            if (p.amount != null) {
              ta += p.amount!;
            }
          }
        }
      }
    }

    return ta;
  }
}

class Token {
  String? mint;

  List<Proof>? proofs;

  Token({this.mint, this.proofs});

  Token.fromJson(Map<String, dynamic> json) {
    mint = json['mint'];
    if (json['proofs'] != null) {
      proofs = <Proof>[];
      json['proofs'].forEach((v) {
        proofs!.add(Proof.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['mint'] = mint;
    if (proofs != null) {
      data['proofs'] = proofs!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Proof {
  String? id;
  int? amount;
  String? secret;
  String? c;

  Proof({this.id, this.amount, this.secret, this.c});

  Proof.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    amount = json['amount'];
    secret = json['secret'];
    c = json['C'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['amount'] = amount;
    data['secret'] = secret;
    data['C'] = c;
    return data;
  }
}
