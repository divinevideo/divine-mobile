// ABOUTME: The sheet where a creator sets up an info sticker: first the place
// ABOUTME: for the stickers that need one, then its look and what it shows.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/info_sticker/info_sticker_cubit.dart';
import 'package:openvine/blocs/video_editor/info_sticker/info_sticker_place_search_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/repositories/info_sticker_repository.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/video_editor/info_sticker/info_sticker_inputs.dart';
import 'package:openvine/widgets/video_editor/info_sticker/info_sticker_labels.dart';
import 'package:openvine/widgets/video_editor/info_sticker/info_sticker_place_picker.dart';
import 'package:openvine/widgets/video_editor/info_sticker/info_sticker_view.dart';
import 'package:openvine/widgets/video_editor/info_sticker/sticker_sheet_controls.dart';
import 'package:unified_logger/unified_logger.dart';

/// Opens the info sticker sheet and resolves with the sticker as the creator
/// set it up, or `null` when they closed the sheet.
///
/// [isNew] is true for a sticker that is not on the canvas yet; [clip] is the
/// clip a new time, date or weather sticker takes its time from. Without a
/// [repository] the sheet makes its own and closes it when it is done.
Future<InfoStickerData?> showInfoStickerSheet(
  BuildContext context, {
  required InfoStickerData initial,
  bool isNew = false,
  DivineVideoClip? clip,
  InfoStickerRepository? repository,
}) async {
  final owned = repository == null ? InfoStickerRepository() : null;
  final lookups = repository ?? owned!;
  try {
    return await VineBottomSheet.show<InfoStickerData>(
      context: context,
      title: Text(context.l10n.infoStickerKindLabel(initial.kind)),
      expanded: false,
      scrollable: false,
      isScrollControlled: true,
      body: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) {
              final cubit = InfoStickerCubit(
                repository: lookups,
                initial: initial,
                clip: clip,
              );
              runDetached(
                cubit.load(),
                'load info sticker values',
                logName: 'InfoStickerSheet',
                category: LogCategory.video,
              );
              return cubit;
            },
          ),
          BlocProvider(
            create: (_) => InfoStickerPlaceSearchBloc(
              repository: lookups,
              languageCode: initial.locale.languageCode,
            )..add(const InfoStickerPlaceSearchStarted()),
          ),
        ],
        child: InfoStickerSheet(isNew: isNew),
      ),
    );
  } finally {
    owned?.close();
  }
}

/// Lets the creator pick a place where the sticker needs one, then set up
/// its look while a preview shows it, and pops with the result.
class InfoStickerSheet extends StatelessWidget {
  const InfoStickerSheet({required this.isNew, super.key});

  /// Whether the sticker is not on the canvas yet, which names the button.
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final step = context.select((InfoStickerCubit cubit) => cubit.state.step);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 220),
      child: switch (step) {
        InfoStickerStep.place => const InfoStickerPlacePicker(
          key: ValueKey(InfoStickerStep.place),
        ),
        InfoStickerStep.design => _DesignStep(
          key: const ValueKey(InfoStickerStep.design),
          isNew: isNew,
        ),
      },
    );
  }
}

/// The preview, the look and what the sticker shows, above the button that
/// places or saves it.
class _DesignStep extends StatelessWidget {
  const _DesignStep({required this.isNew, super.key});

  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final kind = context.select(
      (InfoStickerCubit cubit) => cubit.state.data.kind,
    );
    // The options scroll on a short screen, between the preview above them
    // and the button below them.
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        const Padding(padding: .fromLTRB(16, 8, 16, 0), child: _Preview()),
        Flexible(
          child: SingleChildScrollView(
            padding: const .symmetric(vertical: 16),
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              spacing: 16,
              children: [
                if (kind.searchesPlace) const InfoStickerPlaceRow(),
                const InfoStickerStylePicker(),
                ...switch (kind) {
                  InfoStickerKind.time => const [
                    InfoStickerTimeChoice(),
                    InfoStickerDateTimeWheel(mode: .time),
                  ],
                  InfoStickerKind.date => const [
                    InfoStickerDateFormatPicker(),
                    InfoStickerTimeChoice(),
                    InfoStickerDateTimeWheel(mode: .date),
                  ],
                  InfoStickerKind.moon => const [
                    InfoStickerTimeChoice(),
                    InfoStickerDateTimeWheel(mode: .date),
                  ],
                  InfoStickerKind.dayCount => const [
                    InfoStickerDayCountFields(),
                  ],
                  InfoStickerKind.location => const [
                    InfoStickerSymbolChoice(),
                  ],
                  InfoStickerKind.weather => const [
                    InfoStickerWeatherChoice(),
                    InfoStickerValueField(),
                  ],
                  InfoStickerKind.altitude => const [InfoStickerValueField()],
                  InfoStickerKind.sun => const [InfoStickerLookupNote()],
                  InfoStickerKind.battery => const [InfoStickerBatterySlider()],
                  InfoStickerKind.recTimer => const <Widget>[],
                },
              ],
            ),
          ),
        ),
        StickerSheetFooter(child: _ConfirmButton(isNew: isNew)),
      ],
    );
  }
}

/// The sticker as it will look, on a dark ground like a video's.
class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    final (data, isLoading) = context.select(
      (InfoStickerCubit cubit) => (
        cubit.state.data,
        cubit.state.valueStatus == InfoStickerValueStatus.loading,
      ),
    );
    return SizedBox(
      height: 140,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VineTheme.surfaceBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const .all(20),
          child: switch ((data.isComplete, isLoading)) {
            (true, _) => FittedBox(child: InfoStickerView(data: data)),
            (false, true) => const Center(
              child: DivineCircularProgressIndicator(),
            ),
            // Nothing to show yet: a value is still to be entered.
            (false, false) => Center(
              child: Text(
                context.l10n.infoStickerKindLabel(data.kind),
                style: VineTheme.titleMediumFont(
                  color: VineTheme.whiteText.withValues(alpha: 0.6),
                ),
              ),
            ),
          },
        ),
      ),
    );
  }
}

/// Places or saves the sticker once it has everything it shows.
class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({required this.isNew});

  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final (data, isLoading) = context.select(
      (InfoStickerCubit cubit) => (
        cubit.state.data,
        cubit.state.valueStatus == InfoStickerValueStatus.loading,
      ),
    );
    final l10n = context.l10n;
    return DivineButton(
      label: isNew ? l10n.videoEditorInfoStickerAdd : l10n.videoEditorDoneLabel,
      expanded: true,
      onPressed: data.isComplete && !isLoading
          ? () => Navigator.of(context).pop(data)
          : null,
    );
  }
}
