// ABOUTME: Autosaving editor for private device-local sound labels and hashtags.
// ABOUTME: Keeps organization metadata inside SavedSoundsBloc and out of Nostr.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/saved_sound.dart';

/// Handle that commits a [SavedSoundDetailsEditor]'s pending edits on demand.
///
/// The editor autosaves as the user types, so this exists for the sheet's
/// Save button: it writes whatever is still sitting in the debounce window
/// instead of waiting out the delay.
class SavedSoundDetailsEditorController {
  VoidCallback? _save;

  /// Writes the current label and hashtags immediately.
  ///
  /// Does nothing when no editor is attached.
  void save() => _save?.call();
}

class SavedSoundDetailsEditor extends StatefulWidget {
  const SavedSoundDetailsEditor({
    required this.sound,
    this.controller,
    this.autosaveDelay = const Duration(milliseconds: 350),
    super.key,
  });

  final SavedSound sound;

  /// Optional handle used to flush pending edits from outside the editor.
  final SavedSoundDetailsEditorController? controller;

  final Duration autosaveDelay;

  /// Opens the editor in a bottom sheet.
  ///
  /// [context] must sit below a `SavedSoundsBloc`; the bloc is handed to the
  /// sheet explicitly because the modal route builds outside this subtree.
  static Future<void> show(
    BuildContext context, {
    required SavedSound sound,
  }) {
    final bloc = context.read<SavedSoundsBloc>();
    return VineBottomSheet.show<void>(
      context: context,
      scrollable: false,
      contentTitle: context.l10n.savedSoundDetailsSheetTitle,
      contentWrapper: (_, child) =>
          BlocProvider<SavedSoundsBloc>.value(value: bloc, child: child),
      // The sheet is fixed-mode, so nothing else lifts it clear of the
      // keyboard — without the view inset both fields sit underneath it the
      // moment one takes focus. The scroll view keeps the form reachable when
      // the keyboard plus the fields outgrow a short screen.
      body: SingleChildScrollView(
        child: VineKeyboardAwareFooter(
          includeSafeArea: false,
          child: _SavedSoundDetailsSheet(sound: sound),
        ),
      ),
    );
  }

  @override
  State<SavedSoundDetailsEditor> createState() =>
      _SavedSoundDetailsEditorState();
}

class _SavedSoundDetailsEditorState extends State<SavedSoundDetailsEditor> {
  late final TextEditingController _labelController;
  late final TextEditingController _hashtagController;
  late final FocusNode _labelFocus;
  late final FocusNode _hashtagFocus;
  late List<String> _hashtags;

  /// Captured so a pending autosave can still be flushed from [dispose],
  /// after the editor's own `BuildContext` is on its way out.
  late final SavedSoundsBloc _bloc;

  Timer? _autosaveTimer;
  bool _updatingHashtagField = false;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<SavedSoundsBloc>();
    widget.controller?._save = _saveNow;
    _labelController = TextEditingController(
      text: widget.sound.personalLabel ?? '',
    );
    _hashtagController = TextEditingController();
    _hashtags = [...widget.sound.personalHashtags];
    _labelFocus = FocusNode()..addListener(_onFocusChanged);
    _hashtagFocus = FocusNode()..addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant SavedSoundDetailsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sound.id != widget.sound.id) {
      _autosaveTimer?.cancel();
      _labelController.text = widget.sound.personalLabel ?? '';
      _hashtags = [...widget.sound.personalHashtags];
      _hashtagController.clear();
    }
  }

  void _onFocusChanged() {
    if (!_labelFocus.hasFocus && !_hashtagFocus.hasFocus) _saveNow();
  }

  void _scheduleSave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(widget.autosaveDelay, _saveNow);
  }

  void _saveNow({bool notify = true}) {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    _flushHashtagDraft(notify: notify);
    _bloc.add(
      SavedSoundDetailsChanged(
        soundId: widget.sound.id,
        label: _labelController.text,
        hashtags: _hashtags,
      ),
    );
  }

  /// Folds text still sitting in the hashtag field into [_hashtags].
  ///
  /// Only a delimiter or the Done key turns typed text into a hashtag, so
  /// without this a save — or a dismissal — drops one the user can still
  /// see in the field.
  ///
  /// [notify] is false on the teardown path, where `setState` is no longer
  /// legal and nothing is left to repaint anyway.
  void _flushHashtagDraft({required bool notify}) {
    final additions = normalizeSavedSoundHashtags(
      _hashtagController.text.split(RegExp(r'[,\s]+')),
    );
    if (additions.isEmpty) return;
    final merged = normalizeSavedSoundHashtags([..._hashtags, ...additions]);
    if (!notify) {
      _hashtags = merged;
      return;
    }
    _updatingHashtagField = true;
    _hashtagController.clear();
    _updatingHashtagField = false;
    setState(() => _hashtags = merged);
  }

  void _onHashtagChanged(String value) {
    if (_updatingHashtagField) return;
    if (!RegExp(r'[,\s]').hasMatch(value)) return;
    _commitHashtag(value);
  }

  void _commitHashtag(String raw) {
    final additions = normalizeSavedSoundHashtags(raw.split(RegExp(r'[,\s]+')));
    if (additions.isNotEmpty) {
      setState(() {
        _hashtags = [
          ...normalizeSavedSoundHashtags([..._hashtags, ...additions]),
        ];
      });
      _scheduleSave();
    }
    _updatingHashtagField = true;
    _hashtagController.clear();
    _updatingHashtagField = false;
  }

  void _removeHashtag(String hashtag) {
    setState(() => _hashtags.remove(hashtag));
    _scheduleSave();
  }

  @override
  void dispose() {
    // Dismissing the sheet must not swallow the last few keystrokes — nor a
    // hashtag still sitting uncommitted in the field.
    if ((_autosaveTimer?.isActive ?? false) ||
        _hashtagController.text.trim().isNotEmpty) {
      _saveNow(notify: false);
    }
    _autosaveTimer?.cancel();
    widget.controller?._save = null;
    _labelFocus
      ..removeListener(_onFocusChanged)
      ..dispose();
    _hashtagFocus
      ..removeListener(_onFocusChanged)
      ..dispose();
    _labelController.dispose();
    _hashtagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasSaveError = context.select<SavedSoundsBloc, bool>(
      (bloc) => bloc.state.unsavedSoundIds.contains(widget.sound.id),
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DivineTextField(
            key: const Key('saved_sound_label_field'),
            controller: _labelController,
            focusNode: _labelFocus,
            labelText: context.l10n.savedSoundYourLabel,
            // Both fields sit directly on the sheet surface and would have no
            // visible edge without a fill.
            filled: true,
            textInputAction: .next,
            spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
            onChanged: (_) => _scheduleSave(),
          ),
          const SizedBox(height: 8),
          DivineTextField(
            key: const Key('saved_sound_hashtag_field'),
            controller: _hashtagController,
            focusNode: _hashtagFocus,
            labelText: context.l10n.savedSoundAddHashtags,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            filled: true,
            spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
            onChanged: _onHashtagChanged,
            onSubmitted: _commitHashtag,
          ),
          if (_hashtags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final hashtag in _hashtags)
                  InputChip(
                    key: Key('saved_sound_hashtag_$hashtag'),
                    label: Text('#$hashtag'),
                    onDeleted: () => _removeHashtag(hashtag),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            context.l10n.savedSoundDeviceOnly,
            style: VineTheme.labelSmallFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
          if (hasSaveError)
            DivineButton(
              key: const Key('saved_sound_details_retry'),
              label: context.l10n.savedSoundDetailsRetry,
              type: DivineButtonType.link,
              size: DivineButtonSize.small,
              onPressed: _saveNow,
            ),
        ],
      ),
    );
  }
}

/// Sheet body: the editor plus an explicit Save action.
///
/// The editor autosaves, but a sheet needs a visible way to finish — the
/// button flushes the debounce window so the write happens on tap rather
/// than a beat later.
class _SavedSoundDetailsSheet extends StatefulWidget {
  const _SavedSoundDetailsSheet({required this.sound});

  final SavedSound sound;

  @override
  State<_SavedSoundDetailsSheet> createState() =>
      _SavedSoundDetailsSheetState();
}

class _SavedSoundDetailsSheetState extends State<_SavedSoundDetailsSheet> {
  final _controller = SavedSoundDetailsEditorController();

  void _onSave() {
    _controller.save();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SavedSoundDetailsEditor(sound: widget.sound, controller: _controller),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: DivineButton(
            key: const Key('saved_sound_details_save'),
            expanded: true,
            label: context.l10n.savedSoundSaveAction,
            onPressed: _onSave,
          ),
        ),
      ],
    );
  }
}
