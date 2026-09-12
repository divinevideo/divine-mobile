import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_setup_rows.dart';
import 'package:openvine/screens/verify/verify_screen.dart';
import 'package:openvine/widgets/profile/verified_accounts_row.dart';
import 'package:profile_repository/profile_repository.dart';

class VerifiedAccountsSection extends StatelessWidget {
  const VerifiedAccountsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final claims = context.select<MyProfileBloc, List<IdentityClaim>>((bloc) {
      final state = bloc.state;
      if (state is MyProfileLoaded) return state.verifiedClaims;
      if (state is MyProfileUpdated) return state.verifiedClaims;
      return const [];
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          l10n.profileEditVerifiedAccountsTitle,
          style: VineTheme.labelMediumFont(
            color: context.vineColors.mutedText,
          ),
        ),
        if (claims.isNotEmpty) VerifiedAccountsRow(claims: claims),
        const _GetVerifiedTile(),
      ],
    );
  }
}

/// The entry point into the verify flow, drawn as one of the form's cards.
///
/// Same surface, radius and height as the fields above it, with the brand
/// accent on the affordance — a row that reads as part of the form rather than
/// a list tile bolted underneath it.
class _GetVerifiedTile extends StatelessWidget {
  const _GetVerifiedTile();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSelectRow(
          label: l10n.profileEditGetVerifiedCta,
          trailingColor: VineTheme.primary,
          onTap: () => _openVerify(context),
        ),
        ProfileFieldSupportingText(l10n.profileEditGetVerifiedSubtitle),
      ],
    );
  }

  Future<void> _openVerify(BuildContext context) async {
    final myProfileBloc = context.read<MyProfileBloc>();
    await context.pushNamed(VerifyPage.routeName);
    if (myProfileBloc.isClosed) return;
    // The chip row above renders from MyProfileBloc, so a link added or
    // removed in the flow only shows up here after a re-read.
    myProfileBloc.add(const MyProfileFetchRequested());
  }
}
