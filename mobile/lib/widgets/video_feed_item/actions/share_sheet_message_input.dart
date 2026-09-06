part of 'share_action_button.dart';

// ---------------------------------------------------------------------------
// Message input (shown when a recipient is selected)
// ---------------------------------------------------------------------------

class _MessageInput extends StatelessWidget {
  const _MessageInput({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              // Selection reveals the composer; pop the keyboard right away
              // so compose-and-send is a single uninterrupted gesture.
              autofocus: true,
              style: TextStyle(
                color: context.vineColors.primaryText,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: context.l10n.shareMessageHint,
                hintStyle: TextStyle(color: context.vineColors.secondaryText),
                filled: true,
                fillColor: context.vineColors.containerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
              ),
              maxLines: 4,
              minLines: 1,
              maxLength: 500,
              buildCounter:
                  (
                    context, {
                    required currentLength,
                    required isFocused,
                    required maxLength,
                  }) => null,
            ),
          ),
          _SendButton(isSending: isSending, onTap: onSend),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.isSending, required this.onTap});

  final bool isSending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSending ? null : onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSending
              ? VineTheme.vineGreen.withValues(alpha: 0.5)
              : VineTheme.vineGreen,
          shape: BoxShape.circle,
        ),
        child: isSending
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: DivineCircularProgressIndicator(
                  strokeWidth: 2,
                  color: VineTheme.onPrimary,
                ),
              )
            // Center loosens the Container's tight 40x40 constraints —
            // without it the SvgPicture is forced to fill the circle and
            // the size below is silently ignored. The arrow glyph fills
            // only ~66%x78% of its SVG viewBox, so 28 renders a ~18x22pt
            // glyph (device-tuned; Figma spec draws ~18x20).
            : const Center(
                child: DivineIcon(
                  icon: DivineIconName.arrowUp,
                  size: 28,
                  color: VineTheme.onPrimary,
                ),
              ),
      ),
    );
  }
}
