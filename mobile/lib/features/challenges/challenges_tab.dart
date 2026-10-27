import 'package:divine_ui/divine_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/challenges/challenge_link.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_paths.dart';

/// Known-link entry only. No partial relay query masquerades as discovery.
class ChallengesTab extends StatefulWidget {
  const ChallengesTab({super.key});
  @override
  State<ChallengesTab> createState() => _ChallengesTabState();
}

class _ChallengesTabState extends State<ChallengesTab> {
  final _link = TextEditingController();
  bool _invalid = false;
  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        context.l10n.challengeTitle,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 16),
      Text(context.l10n.challengeTestNotice),
      const SizedBox(height: 24),
      TextField(
        controller: _link,
        decoration: InputDecoration(
          labelText: context.l10n.challengeLinkLabel,
          errorText: _invalid ? context.l10n.challengeUnavailable : null,
        ),
        autocorrect: false,
      ),
      const SizedBox(height: 16),
      DivineButton(
        label: context.l10n.challengeOpenLink,
        onPressed: () async {
          var value = _link.text.trim();
          final uri = Uri.tryParse(value);
          if (uri != null &&
              (uri.host == 'divine.video' || uri.host == 'www.divine.video') &&
              uri.pathSegments.length == 2 &&
              uri.pathSegments.first == 'challenges') {
            value = uri.pathSegments.last;
          }
          final link = ChallengeLink.parse(value);
          setState(() => _invalid = link == null);
          if (link != null) {
            await context.push<void>(RoutePaths.challengeFor(link.naddr));
          }
        },
      ),
    ],
  );
}
