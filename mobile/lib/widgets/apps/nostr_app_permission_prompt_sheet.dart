// ABOUTME: Compact runtime permission prompt for vetted Nostr sandbox apps
// ABOUTME: Shows the requesting app, origin, and requested bridge capability

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

class NostrAppPermissionPromptSheet extends StatelessWidget {
  const NostrAppPermissionPromptSheet({
    required this.appName,
    required this.origin,
    required this.method,
    required this.capability,
    required this.onAllow,
    required this.onCancel,
    this.eventKind,
    super.key,
  });

  final String appName;
  final String origin;
  final String method;
  final String capability;
  final int? eventKind;
  final VoidCallback onAllow;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.nostrAppPermissionTitle(appName),
            style: VineTheme.titleLargeFont(
              color: context.vineColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.nostrAppPermissionDescription,
            style: VineTheme.bodyLargeFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _DetailRow(label: l10n.nostrAppPermissionOrigin, value: origin),
          const SizedBox(height: 12),
          _DetailRow(label: l10n.nostrAppPermissionMethod, value: method),
          const SizedBox(height: 12),
          _DetailRow(
            label: l10n.nostrAppPermissionCapability,
            value: capability,
          ),
          if (eventKind != null) ...[
            const SizedBox(height: 12),
            _DetailRow(
              label: l10n.nostrAppPermissionEventKind,
              value: '$eventKind',
            ),
          ],
          const SizedBox(height: 28),
          Column(
            spacing: 12,
            children: [
              DivineButton(
                label: l10n.nostrAppPermissionAllow,
                onPressed: onAllow,
                expanded: true,
              ),
              DivineButton(
                label: l10n.commonCancel,
                type: DivineButtonType.secondary,
                onPressed: onCancel,
                expanded: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.vineColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.vineColors.outlineMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: VineTheme.titleSmallFont(
              color: context.vineColors.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: VineTheme.bodyLargeFont(color: context.vineColors.onSurface),
          ),
        ],
      ),
    );
  }
}
