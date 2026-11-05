// MPL-2.0
import 'package:concord_protocol/concord_protocol.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';

bool isSecureConcordRelay(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'wss' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      !uri.hasFragment &&
      !value.contains(RegExp(r'\s'));
}

void validateConcordInvite(String value) {
  final uri = Uri.parse(value);
  if (uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      !uri.path.startsWith('/invite/')) {
    throw const FormatException('Invalid community invitation');
  }
  final coordinate = NIP19Tlv.decodeNaddr(
    uri.path.substring('/invite/'.length).replaceFirst(RegExp(r'/$'), ''),
  );
  if (coordinate == null ||
      coordinate.kind != 33301 ||
      coordinate.id.isNotEmpty) {
    throw const FormatException('Invalid community invite coordinate');
  }
  ConcordInviteFragment.decode(uri.fragment);
}
