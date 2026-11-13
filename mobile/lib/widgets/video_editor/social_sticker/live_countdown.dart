// ABOUTME: Counts a countdown sticker down every second, as the player and the
// ABOUTME: editor canvas show it, and writes the time left it shows.

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/l10n/l10n.dart';

/// The time [left] on a countdown, as its sticker shows it in the player and
/// on the editor canvas: whole days, then hours, minutes and seconds, such as
/// "12 days 04:33:10".
String countdownTimeLeft(AppLocalizations l10n, Duration left) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  final clockTime = [
    left.inHours.remainder(Duration.hoursPerDay),
    left.inMinutes.remainder(Duration.minutesPerHour),
    left.inSeconds.remainder(Duration.secondsPerMinute),
  ].map(twoDigits).join(':');
  final days = left.inDays;
  return days == 0
      ? clockTime
      : '${l10n.videoStickerCountdownDays(days)} $clockTime';
}

/// Builds a countdown to [end] with the time left, again every second until
/// it is over.
///
/// [builder] gets the time left written by [countdownTimeLeft], or `null` for
/// the countdown's date: once it is over, without an [end], and while
/// [showDate] is `true`.
class LiveCountdown extends StatefulWidget {
  const LiveCountdown({
    required this.end,
    required this.builder,
    this.showDate,
    super.key,
  });

  /// When the countdown ends.
  final DateTime? end;

  /// Whether the countdown shows its date for now instead of the time left,
  /// such as while the editor captures it for the video's frames.
  final ValueListenable<bool>? showDate;

  /// Builds the countdown with the time left, or `null` for its date.
  final Widget Function(BuildContext context, String? timeLeft) builder;

  @override
  State<LiveCountdown> createState() => _LiveCountdownState();
}

class _LiveCountdownState extends State<LiveCountdown> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _startTicking();
  }

  @override
  void didUpdateWidget(LiveCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A countdown moved to a later end ticks again, even once it was over.
    if (oldWidget.end != widget.end) _startTicking();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Duration get _left => (widget.end ?? clock.now()).difference(clock.now());

  void _startTicking() {
    _ticker?.cancel();
    _ticker = _left > Duration.zero
        ? Timer.periodic(const Duration(seconds: 1), (_) => _tick())
        : null;
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    if (_left > Duration.zero) return;
    // Over: the date stays as it is from here on.
    _ticker?.cancel();
    _ticker = null;
  }

  String? _timeLeft(BuildContext context) {
    final left = _left;
    return left > Duration.zero ? countdownTimeLeft(context.l10n, left) : null;
  }

  @override
  Widget build(BuildContext context) {
    final showDate = widget.showDate;
    if (showDate == null) return widget.builder(context, _timeLeft(context));
    return ValueListenableBuilder<bool>(
      valueListenable: showDate,
      builder: (context, dateOnly, _) =>
          widget.builder(context, dateOnly ? null : _timeLeft(context)),
    );
  }
}
