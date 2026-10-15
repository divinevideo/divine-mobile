// ABOUTME: Gives blocked account and list recovery a supported way forward.
// ABOUTME: Opens support without clearing or exporting uncertain local evidence.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

class RecoverySupportButton extends StatelessWidget {
  const RecoverySupportButton({super.key});

  @override
  Widget build(BuildContext context) => DivineButton(
    label: context.l10n.supportContactSupport,
    expanded: true,
    type: .secondary,
    onPressed: () => runDetached(
      context.push<void>(RoutePaths.supportCenter),
      'open support for blocked recovery',
      logName: 'RecoverySupportButton',
      category: LogCategory.auth,
    ),
  );
}
