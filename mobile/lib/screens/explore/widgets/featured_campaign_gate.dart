// ABOUTME: Keeps a featured-feed campaign bound to its exact configuration.
// ABOUTME: A withdrawn campaign feed shows an unavailable state, never another.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/featured_tabs/featured_tabs_cubit.dart';
import 'package:openvine/l10n/l10n.dart';

/// Shows [child] only while [feedId] is the resolved, enabled, in-window tab:
/// a spinner before the first answer, and an unavailable message otherwise.
class FeaturedCampaignGate extends StatefulWidget {
  const FeaturedCampaignGate({
    required this.feedId,
    required this.state,
    required this.child,
    this.now = DateTime.now,
    super.key,
  });

  final String feedId;
  final FeaturedTabsState state;
  final Widget child;
  final DateTime Function() now;

  @override
  State<FeaturedCampaignGate> createState() => _FeaturedCampaignGateState();
}

class _FeaturedCampaignGateState extends State<FeaturedCampaignGate> {
  Timer? _expiry;

  @override
  void initState() {
    super.initState();
    _scheduleExpiry();
  }

  @override
  void didUpdateWidget(FeaturedCampaignGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleExpiry();
  }

  void _scheduleExpiry() {
    _expiry?.cancel();
    final endsAt = widget.state.tab?.endsAt;
    if (endsAt == null) return;
    final remaining = endsAt.difference(widget.now().toUtc());
    if (remaining <= Duration.zero) return;
    // Keep browser timer durations bounded, as with announcement expiry.
    const maximumDelay = Duration(days: 1);
    _expiry = Timer(remaining > maximumDelay ? maximumDelay : remaining, () {
      if (!mounted) return;
      setState(_scheduleExpiry);
    });
  }

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tab = widget.state.tab;
    if (tab != null &&
        tab.id == widget.feedId &&
        tab.enabled &&
        tab.hasContent &&
        tab.isWithinWindow(widget.now().toUtc())) {
      return widget.child;
    }
    if (widget.state.status != FeaturedTabsStatus.resolved && tab == null) {
      return const Center(child: DivineCircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(context.l10n.featuredFeedUnavailable),
      ),
    );
  }
}
