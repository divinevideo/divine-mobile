import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// Splits [fullText] into spans so [actorName] can be emphasised inline.
///
/// Takes [colors] rather than a [BuildContext] because the result is a list of
/// [InlineSpan]s, which have no context of their own to resolve the palette
/// from.
List<InlineSpan> localizedActorSentenceSpans({
  required String fullText,
  required String actorName,
  required VineThemeColors colors,
}) {
  final bodyStyle = VineTheme.bodyMediumFont(color: colors.primaryText);
  final actorStart = fullText.indexOf(actorName);
  if (actorName.isEmpty || actorStart < 0) {
    return [TextSpan(text: fullText, style: bodyStyle)];
  }

  final actorEnd = actorStart + actorName.length;
  return [
    if (actorStart > 0)
      TextSpan(text: fullText.substring(0, actorStart), style: bodyStyle),
    TextSpan(
      text: actorName,
      style: VineTheme.labelLargeFont(color: colors.primaryText),
    ),
    if (actorEnd < fullText.length)
      TextSpan(text: fullText.substring(actorEnd), style: bodyStyle),
  ];
}
