import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_setup_rows.dart';

/// Asks for an image URL and returns it, or `null` when the user backs out.
///
/// Explicit Save / Cancel rather than staging whatever is in the field when
/// the sheet closes: a swipe-dismiss should leave the profile untouched. An
/// empty string is a real answer — it clears a staged image — so cancelling is
/// signalled by `null` instead.
Future<String?> showImageUrlSheet(
  BuildContext context, {
  String initialUrl = '',
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  final url = await VineBottomSheet.show<String>(
    context: context,
    scrollable: false,
    expanded: false,
    isScrollControlled: true,
    title: Text(
      context.l10n.profileSetupImageUrlTitle,
      style: VineTheme.titleMediumFont(color: context.vineColors.onSurface),
    ),
    children: [_ImageUrlForm(initialUrl: initialUrl)],
  );
  // Again on the way out: the sheet's own field held focus, and leaving it
  // focused would bounce the keyboard back up over the form.
  FocusManager.instance.primaryFocus?.unfocus();
  return url;
}

/// Owns the field's controller so it outlives the sheet's exit animation —
/// the route keeps rebuilding its subtree on the way out, and a controller
/// disposed the moment `show` completes would be read after disposal.
class _ImageUrlForm extends StatefulWidget {
  const _ImageUrlForm({required this.initialUrl});

  final String initialUrl;

  @override
  State<_ImageUrlForm> createState() => _ImageUrlFormState();
}

class _ImageUrlFormState extends State<_ImageUrlForm> {
  late final _controller = TextEditingController(text: widget.initialUrl);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => context.popModalIfMounted(_controller.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          DivineTextField(
            controller: _controller,
            labelText: context.l10n.profileSetupImageUrlTitle,
            filled: true,
            fillColor: context.vineColors.surfaceContainer,
            fillBorderRadius: profileFormCardRadius,
            primaryWhenFilled: true,
            textCapitalization: .none,
            keyboardType: TextInputType.url,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            autofocus: true,
            onSubmitted: (_) => _save(),
          ),
          Row(
            spacing: 16,
            children: [
              Expanded(
                child: DivineButton(
                  label: context.l10n.commonCancel,
                  type: DivineButtonType.secondary,
                  expanded: true,
                  onPressed: () => context.popModalIfMounted(),
                ),
              ),
              Expanded(
                child: DivineButton(
                  label: context.l10n.profileSetupSaveButton,
                  expanded: true,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Stages a banner image URL typed by the user.
///
/// The banner's counterpart to the avatar's URL flow; an empty string clears
/// any staged change.
Future<void> showBannerUrlSheet(
  BuildContext context,
  ProfileEditorBloc editorBloc,
) async {
  final url = await showImageUrlSheet(
    context,
    initialUrl: _bannerImageUrl(editorBloc.state),
  );
  if (url == null) return;
  editorBloc.add(ProfileBannerUrlSet(url));
}

/// The banner image URL the sheet should open on.
///
/// Falls back to the persisted banner the way the header preview does, so a
/// user who already has a banner image edits it rather than retyping it. A
/// persisted colour is not a URL, and a cleared banner is one the user has
/// already asked to drop.
String _bannerImageUrl(ProfileEditorState state) {
  final staged = state.pendingBannerUrl;
  if (staged != null && staged.isNotEmpty) return staged;
  final persisted = state.persistedBanner;
  if (state.bannerCleared || persisted == null) return '';
  return persisted.startsWith('http') ? persisted : '';
}
