import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// Widget handling title section rendering for [DiVineAppBar].
///
/// Supports simple text, custom widgets, subtitles, tappable titles,
/// and dropdown titles with caret indicators.
class DiVineAppBarTitle extends StatelessWidget {
  /// Creates a DiVineAppBar title widget.
  const DiVineAppBarTitle({
    required this.title,
    required this.titleWidget,
    required this.subtitle,
    required this.titleMode,
    required this.onTitleTap,
    required this.titleSuffix,
    required this.style,
    super.key,
  });

  /// The title text.
  final String? title;

  /// Custom title widget.
  final Widget? titleWidget;

  /// Optional subtitle text.
  final String? subtitle;

  /// Title interaction mode.
  final DiVineAppBarTitleMode titleMode;

  /// Called when title is tapped.
  final VoidCallback? onTitleTap;

  /// Widget displayed after title (e.g., EnvironmentBadge).
  final Widget? titleSuffix;

  /// Style configuration.
  final DiVineAppBarStyle style;

  /// Asset path for the dropdown caret icon.
  static const String caretDownAsset = 'assets/icon/CaretDown.svg';

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: _TitleContent(
            title: title,
            titleWidget: titleWidget,
            subtitle: subtitle,
            titleMode: titleMode,
            onTitleTap: onTitleTap,
            style: style,
          ),
        ),
        ?titleSuffix,
      ],
    );
  }
}

class _TitleContent extends StatelessWidget {
  const _TitleContent({
    required this.title,
    required this.titleWidget,
    required this.subtitle,
    required this.titleMode,
    required this.onTitleTap,
    required this.style,
  });

  final String? title;
  final Widget? titleWidget;
  final String? subtitle;
  final DiVineAppBarTitleMode titleMode;
  final VoidCallback? onTitleTap;
  final DiVineAppBarStyle style;

  @override
  Widget build(BuildContext context) {
    if (titleWidget != null) {
      return _TappableWrapper(
        titleMode: titleMode,
        onTitleTap: onTitleTap,
        child: titleWidget!,
      );
    }

    final titleText = _TitleText(title: title!, style: style);

    if (subtitle != null) {
      return _TappableWrapper(
        titleMode: titleMode,
        onTitleTap: onTitleTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleText,
            const SizedBox(height: 2),
            _SubtitleText(subtitle: subtitle!, style: style),
          ],
        ),
      );
    }

    if (titleMode == DiVineAppBarTitleMode.dropdown) {
      return _TappableWrapper(
        titleMode: titleMode,
        onTitleTap: onTitleTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: titleText),
            const SizedBox(width: 4),
            SizedBox(
              width: style.dropdownCaretSize,
              height: style.dropdownCaretSize,
              child: SvgPicture.asset(
                DiVineAppBarTitle.caretDownAsset,
                colorFilter: ColorFilter.mode(
                  style.foregroundColor ?? context.vineColors.onNav,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _TappableWrapper(
      titleMode: titleMode,
      onTitleTap: onTitleTap,
      child: titleText,
    );
  }
}

class _TitleText extends StatelessWidget {
  const _TitleText({
    required this.title,
    required this.style,
  });

  final String title;
  final DiVineAppBarStyle style;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style:
          style.titleStyle ??
          VineTheme.titleLargeFont(
            color: style.foregroundColor ?? context.vineColors.onNav,
          ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _SubtitleText extends StatelessWidget {
  const _SubtitleText({
    required this.subtitle,
    required this.style,
  });

  final String subtitle;
  final DiVineAppBarStyle style;

  @override
  Widget build(BuildContext context) {
    return Text(
      subtitle,
      style:
          style.subtitleStyle ??
          VineTheme.bodySmallFont(
            // 75% matches the dark-mode `onSurfaceVariant` this replaced.
            color: (style.foregroundColor ?? context.vineColors.onNav)
                .withValues(alpha: 0.75),
          ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _TappableWrapper extends StatelessWidget {
  const _TappableWrapper({
    required this.titleMode,
    required this.onTitleTap,
    required this.child,
  });

  final DiVineAppBarTitleMode titleMode;
  final VoidCallback? onTitleTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (titleMode == DiVineAppBarTitleMode.simple) {
      return child;
    }

    return GestureDetector(
      onTap: onTitleTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}
