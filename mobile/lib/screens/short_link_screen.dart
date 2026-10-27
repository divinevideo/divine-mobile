// ABOUTME: Displays bounded short-link loading and a retryable error before guarded navigation.
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/short_link/short_link_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/universal_link_resolver.dart';
import 'package:openvine/widgets/branded_loading_scaffold.dart';

class ShortLinkScreen extends StatelessWidget {
  static const routeName = 'short-link';
  const ShortLinkScreen({required this.uri, super.key});
  final Uri uri;

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<ShortLinkCubit, ShortLinkState>(
        listener: (context, state) {
          if (state is! ShortLinkReady ||
              ModalRoute.of(context)?.isCurrent != true) {
            return;
          }
          final target = deepLinkRouterPath(state.link);
          if (target != null) context.go(target);
        },
        builder: (context, state) {
          if (state is ShortLinkLoading) return const BrandedLoadingScaffold();
          return Scaffold(
            backgroundColor: context.vineColors.background,
            appBar: DiVineAppBar(
              title: context.l10n.routeErrorTitle,
              showBackButton: true,
              onBackPressed: () => context.safePop(),
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 24,
                children: [
                  Text(context.l10n.commonSomethingWentWrong),
                  DivineButton(
                    label: context.l10n.commonRetry,
                    onPressed: () =>
                        context.read<ShortLinkCubit>().resolve(uri),
                  ),
                ],
              ),
            ),
          );
        },
      );
}
