// ABOUTME: Opens the sheet that picks which of the viewer's lists hold a
// ABOUTME: video. Owns the sheet's cubit; the picks are saved with one check.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' show ScaffoldMessenger;
import 'package:models/models.dart';
import 'package:openvine/blocs/select_list/select_list_cubit.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curated_list_editor_session_provider.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_sheet.dart';
import 'package:openvine/widgets/select_list_sheet/select_list_save_button.dart';
import 'package:openvine/widgets/select_list_sheet/select_list_sheet_body.dart';
import 'package:unified_logger/unified_logger.dart';

/// Shows the sheet that picks which of the viewer's lists hold [video].
///
/// The picks are written when the check is tapped, so one visit can put the
/// video in several lists and take it out of others. Completes once the
/// sheet has closed. Reports on the screen underneath, and does not open,
/// when the lists cannot be loaded.
Future<void> showSelectListSheet(
  BuildContext context, {
  required VideoEvent video,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final container = ProviderScope.containerOf(context, listen: false);
  final session = container.read(curatedListEditorSessionProvider);
  String? currentOwner() => session.currentOwnerPubkey;
  final openingOwner = currentOwner();
  if (openingOwner == null || openingOwner.isEmpty) return;
  var loaded = false;
  try {
    await container.read(curatedListsStateProvider.future);
    loaded = true;
  } catch (error, stackTrace) {
    Log.error(
      'Lists could not be loaded for the list picker',
      name: 'SelectListSheet',
      category: LogCategory.ui,
      error: error,
      stackTrace: stackTrace,
    );
  }
  if (currentOwner() != openingOwner) return;
  final service = loaded ? session.service : null;
  if (service == null) {
    if (messenger?.mounted ?? false) {
      messenger!.showSnackBar(
        DivineSnackbarContainer.snackBar(
          l10n.listErrorLoading,
          error: true,
          actionLabel: l10n.searchTryAgain,
          onActionPressed: () {
            if (!context.mounted || currentOwner() != openingOwner) return;
            messenger.hideCurrentSnackBar();
            container.invalidate(curatedListsStateProvider);
            runDetached(
              showSelectListSheet(context, video: video),
              'retry loading list picker',
              logName: 'SelectListSheet',
              category: LogCategory.ui,
            );
          },
        ),
      );
    }
    return;
  }
  if (!context.mounted) return;

  final bodyKey = GlobalKey();

  // The sheet's default sizes, which the people-list picker uses too: it
  // opens over the lower part of the screen and can be dragged taller.
  await context.showVideoPausingVineBottomSheet<void>(
    title: Text(l10n.listAddToLists),
    headerPadding: listInfoSheetHeaderPadding,
    headerLeadingAction: DivineIconButton(
      icon: DivineIconName.x,
      type: DivineIconButtonType.secondary,
      size: DivineIconButtonSize.small,
      semanticLabel: l10n.commonClose,
      // The body's context belongs to the sheet's own route, so the pop is
      // skipped once that route is already on its way out.
      onPressed: () => bodyKey.currentContext?.popModalIfMounted(),
    ),
    trailing: const SelectListSaveButton(),
    contentWrapper: (_, sheet) => BlocProvider<SelectListCubit>(
      create: (_) => SelectListCubit(
        service: service,
        videoEventId: video.id,
        currentOwnerPubkey: currentOwner,
      ),
      child: _SelectListServiceBinding(child: sheet),
    ),
    buildScrollBody: (scrollController) =>
        SelectListSheetBody(key: bodyKey, scrollController: scrollController),
    bottomInput: SelectListCreateButton(video: video),
  );
}

/// The legacy provider remains the source of initialized services. Rebinding
/// the cubit explicitly drops staged picks belonging to the previous service.
class _SelectListServiceBinding extends ConsumerStatefulWidget {
  const _SelectListServiceBinding({required this.child});

  final Widget child;

  @override
  ConsumerState<_SelectListServiceBinding> createState() =>
      _SelectListServiceBindingState();
}

class _SelectListServiceBindingState
    extends ConsumerState<_SelectListServiceBinding> {
  @override
  void initState() {
    super.initState();
    final session = ref.read(curatedListEditorSessionProvider);
    ref.listenManual(curatedListsStateProvider, (_, next) {
      context.read<SelectListCubit>().serviceChanged(
        next.hasValue && !next.isLoading && !next.hasError
            ? session.service
            : null,
      );
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
