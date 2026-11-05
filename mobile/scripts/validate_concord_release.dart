// MPL-2.0
import 'dart:io';

import 'package:openvine/features/chat/concord_configuration.dart';

void main() {
  try {
    if (!isSecureConcordRelay(
      Platform.environment['CONCORD_RELAY_URL'] ?? '',
    )) {
      throw const FormatException('Invalid relay');
    }
    validateConcordInvite(Platform.environment['CONCORD_INVITE_URL'] ?? '');
  } on Object {
    stderr.writeln('ERROR: invalid CONCORD_INVITE_URL or CONCORD_RELAY_URL');
    exitCode = 1;
  }
}
