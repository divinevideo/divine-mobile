// ABOUTME: The place step of the info sticker sheet: a search with suggestions
// ABOUTME: while typing, and the row that leads back to it.

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/info_sticker/info_sticker_cubit.dart';
import 'package:openvine/blocs/video_editor/info_sticker/info_sticker_place_search_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/repositories/info_sticker_repository.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Searches a place while the creator types and lists what it found; picking
/// one moves the sheet on to the sticker's look.
class InfoStickerPlacePicker extends StatefulWidget {
  const InfoStickerPlacePicker({super.key});

  @override
  State<InfoStickerPlacePicker> createState() => _InfoStickerPlacePickerState();
}

class _InfoStickerPlacePickerState extends State<InfoStickerPlacePicker> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Typing is the only thing to do here, so the keyboard comes up with it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final screen = MediaQuery.sizeOf(context).height;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final status = context.select(
      (InfoStickerPlaceSearchBloc bloc) => bloc.state.status,
    );
    // A steady height, so the sheet does not jump as suggestions arrive, that
    // still leaves the sheet's header in view above the keyboard.
    final height = math
        .max(
          240,
          math.min(screen * 0.72, screen - keyboard - 180),
        )
        .toDouble();
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            Padding(
              padding: const .fromLTRB(16, 8, 16, 8),
              child: DivineSearchBar(
                focusNode: _focusNode,
                hintText: l10n.videoEditorInfoStickerPlaceSearchHint,
                isLoading: status == InfoStickerPlaceSearchStatus.loading,
                onChanged: (query) => context
                    .read<InfoStickerPlaceSearchBloc>()
                    .add(InfoStickerPlaceQueryChanged(query)),
              ),
            ),
            const Expanded(child: _Suggestions()),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                8 +
                    (keyboard > 0
                        ? 0
                        : MediaQuery.viewPaddingOf(context).bottom),
              ),
              child: Text(
                '${l10n.videoEditorInfoStickerPlacePrivacyNote} '
                '${l10n.videoEditorInfoStickerPlaceAttribution}',
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.onSurfaceMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The places found so far, or why there are none.
class _Suggestions extends StatelessWidget {
  const _Suggestions();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final search = context.select(
      (InfoStickerPlaceSearchBloc bloc) => bloc.state,
    );
    final picked = context.select(
      (InfoStickerCubit cubit) => cubit.state.place,
    );
    final message = switch (search.status) {
      InfoStickerPlaceSearchStatus.failure =>
        l10n.videoEditorInfoStickerPlaceSearchFailed,
      InfoStickerPlaceSearchStatus.success when search.places.isEmpty =>
        l10n.videoEditorInfoStickerPlaceNoResults,
      _ => null,
    };
    if (message != null) {
      return Padding(
        padding: const .all(16),
        child: Text(
          message,
          style: VineTheme.bodyMediumFont(
            color: search.status == InfoStickerPlaceSearchStatus.failure
                ? context.vineColors.accentWarning
                : context.vineColors.onSurfaceMuted,
          ),
        ),
      );
    }
    // The rows are list tiles, which paint on the nearest Material; the
    // sheet's own background would hide their highlight.
    return Material(
      type: .transparency,
      child: ListView.builder(
        keyboardDismissBehavior: .onDrag,
        itemCount: search.places.length,
        itemBuilder: (context, index) {
          final place = search.places[index];
          return DivineSelectableRow(
            title: place.name,
            subtitle: place.detail,
            isSelected: place == picked,
            onTap: () => _pick(context, place),
          );
        },
      ),
    );
  }

  void _pick(BuildContext context, InfoStickerPlace place) {
    FocusManager.instance.primaryFocus?.unfocus();
    // The lookup runs while the sheet already shows the sticker's look; its
    // expected failures land in the cubit's state.
    runDetached(
      context.read<InfoStickerCubit>().placeSelected(place),
      'look up the info sticker value for a place',
      logName: 'InfoStickerPlacePicker',
      category: LogCategory.video,
    );
  }
}

/// The place the sticker shows or was read for; tapping it goes back to the
/// place search.
class InfoStickerPlaceRow extends StatelessWidget {
  const InfoStickerPlaceRow({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (place, placeName) = context.select(
      (InfoStickerCubit cubit) => (
        cubit.state.place,
        cubit.state.data.kind == InfoStickerKind.location
            ? cubit.state.data.placeName
            : null,
      ),
    );
    final name = place?.name ?? placeName;
    return Material(
      type: .transparency,
      child: DivineListTile(
        icon: DivineIconName.pushPin,
        title: name ?? l10n.videoEditorInfoStickerChangePlace,
        subtitle: name == null ? null : l10n.videoEditorInfoStickerChangePlace,
        onTap: context.read<InfoStickerCubit>().changePlaceRequested,
      ),
    );
  }
}
