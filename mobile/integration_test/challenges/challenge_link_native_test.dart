// Requires the host to open the emitted synthetic URL and accept iOS's system
// confirmation. Does not claim that the hosted HTTPS association is deployed.
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:openvine/router/universal_link_resolver.dart';
import 'package:openvine/services/deep_link_service.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('custom scheme delivery', () {
    testWidgets('receives the full synthetic challenge link', (tester) async {
      final naddr = NIP19Tlv.encodeNaddr(
        Naddr(
          id: 'synthetic:challenge',
          author: 'ab' * 32,
          kind: 31923,
        ),
      );
      final output = await Directory(
        '${(await getApplicationDocumentsDirectory()).path}/challenge-artifacts',
      ).create(recursive: true);
      final incoming = AppLinks().uriLinkStream.first;
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await File('${output.path}/open-link.txt')
          .writeAsString('divine:///challenges/$naddr');
      final received = await incoming.timeout(const Duration(minutes: 2));
      expect(
        deepLinkRouterPath(DeepLinkService.parseDeepLink(received.toString())),
        '/challenges/$naddr',
      );
      await File('${output.path}/open-link-received.txt')
          .writeAsString(received.toString());
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
