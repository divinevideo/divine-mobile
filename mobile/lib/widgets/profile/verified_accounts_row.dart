// ABOUTME: VerifiedAccountsRow — wraps verified-account chips under a profile.

import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/profile/verified_account_chip.dart';
import 'package:profile_repository/profile_repository.dart';

/// Wrap of [VerifiedAccountChip]s for a profile's verified identity claims.
///
/// Renders nothing when [claims] is empty.
class VerifiedAccountsRow extends StatelessWidget {
  /// Creates a [VerifiedAccountsRow] for [claims].
  const VerifiedAccountsRow({
    required this.claims,
    this.padding = EdgeInsets.zero,
    this.center = false,
    super.key,
  });

  /// The verified claims to render. Each becomes one [VerifiedAccountChip].
  final List<IdentityClaim> claims;

  /// Padding around the horizontally scrolling chip row.
  final EdgeInsetsGeometry padding;

  /// Whether to center the scroll view in its parent.
  final bool center;

  @override
  Widget build(BuildContext context) {
    if (claims.isEmpty) return const SizedBox.shrink();
    final row = SingleChildScrollView(
      scrollDirection: .horizontal,
      padding: padding,
      child: Row(
        spacing: 8,
        children: [for (final c in claims) VerifiedAccountChip(claim: c)],
      ),
    );
    return center ? Center(child: row) : row;
  }
}
