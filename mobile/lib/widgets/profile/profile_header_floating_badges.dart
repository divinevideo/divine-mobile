part of 'profile_header_widget.dart';

/// Whether the header lists badges as a static chip row instead of floating
/// them over the banner.
///
/// Reduce motion asks for exactly this motion to go away, and a screen reader
/// cannot follow targets that drift, so both get the static row.
bool _showsStaticProfileBadgeRow(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    MediaQuery.accessibleNavigationOf(context);

/// Badge chips that drift upward through the profile banner.
///
/// [ProfileBannerLayer] fills its own box with this layer, directly over the
/// banner image, so the chips share the banner's size and position and rise
/// behind the avatar, name, and username. Empty while the static badge row is
/// shown instead.
class ProfileFloatingBadgesLayer extends ConsumerWidget {
  const ProfileFloatingBadgesLayer({required this.userIdHex, super.key});

  /// The hex public key of the profile whose badges float.
  final String userIdHex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(profileAcceptedBadgesProvider(userIdHex)).value ??
        const <ProfileBadgeViewData>[];
    if (items.isEmpty || _showsStaticProfileBadgeRow(context)) {
      return const SizedBox.shrink();
    }
    // The static row carries the badges for assistive tech; these copies
    // only move.
    return ExcludeSemantics(child: _FloatingBadges(items: items));
  }
}

class _FloatingBadges extends StatefulWidget {
  const _FloatingBadges({required this.items});

  final List<ProfileBadgeViewData> items;

  @override
  State<_FloatingBadges> createState() => _FloatingBadgesState();
}

class _FloatingBadgesState extends State<_FloatingBadges>
    with SingleTickerProviderStateMixin {
  /// Longest step the drift advances in one frame.
  ///
  /// A covered route mutes the ticker without stopping its clock, so the
  /// first frame back would otherwise jump the drift ahead by however long
  /// the profile was hidden.
  static const _maxFrameSeconds = 0.1;

  final _seconds = ValueNotifier<double>(0);
  late final Ticker _ticker;
  late FloatingBadgeField _field;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _field = FloatingBadgeField(badgeCount: widget.items.length);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(_FloatingBadges oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length) {
      _field = FloatingBadgeField(badgeCount: widget.items.length);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final step = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    _seconds.value += math.min(step, _maxFrameSeconds);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return RepaintBoundary(
      child: Flow(
        delegate: _FloatingBadgesDelegate(clock: _seconds, field: _field),
        children: [
          for (var slot = 0; slot < _field.slotCount; slot++)
            _ProfileBadgeChip(
              badge: items[slot % items.length],
              compact: true,
              depthLayer: FloatingBadgeField.layerOf(slot),
            ),
        ],
      ),
    );
  }
}

/// Decides when each chip enters the banner and in which lane.
///
/// A chip rises in a straight line at a speed set by its depth, so its whole
/// path is known the moment it enters. A chip is only let in on a lane where
/// that path never covers more than [maxOverlap] of a chip already rising;
/// when no lane is clear it waits, which also caps how crowded the banner
/// gets.
@visibleForTesting
class FloatingBadgeField {
  FloatingBadgeField({required int badgeCount})
    : slotCount = math.max(badgeCount, _minSlots) {
    _idleSlots.addAll(List.generate(slotCount, (slot) => slot));
  }

  /// Steps of depth. Every chip in a layer shares its size, speed and
  /// background tint.
  static const depthLayers = 4;

  /// Depth layer of the chip in [slot], 0 for the nearest.
  ///
  /// Fixed per slot because the tint is part of the chip widget, which is
  /// built once. A low-discrepancy sequence spreads the badges evenly across
  /// the layers.
  static int layerOf(int slot) =>
      (_fraction(0.5 + slot * 0.7548776662) * depthLayers).floor();

  /// Most of a chip another chip may cover, as a share of the smaller one.
  ///
  /// A little overlap reads as depth; much more reads as clutter.
  static const maxOverlap = 0.2;

  /// Fewer badges than this are repeated, so a profile with one badge still
  /// reads as a drift rather than a lone chip.
  static const _minSlots = 6;

  static const _entrySpacingSeconds = 1.6;

  /// How soon a chip that found no clear lane tries again.
  static const _retrySeconds = 0.2;

  static const _laneCount = 12;

  /// Coprime with [_laneCount], so a blocked chip tries every lane once,
  /// hopping across the band rather than sliding along it.
  static const _laneStride = 5;

  /// Resolution of the path check.
  static const _sampleSeconds = 0.1;

  /// Chips this faint are still fading in; covering them is not clutter.
  static const visibleOpacity = 0.15;

  final int slotCount;
  final _idleSlots = Queue<int>();
  final _rising = <FloatingBadge>[];
  double _nextEntryAt = 0;
  int _entries = 0;

  /// Chips on the banner, farthest first so nearer ones paint over them.
  List<FloatingBadge> get rising => _rising;

  /// Lets in every chip due by [seconds] and retires every chip done by then.
  ///
  /// Called from paint, the first point at which chip sizes are known. It
  /// depends only on the clock and those sizes, so a repeat call for the same
  /// [seconds] changes nothing.
  void advanceTo(double seconds, Size band, Size Function(int slot) chipSize) {
    while (_nextEntryAt <= seconds) {
      _retireBy(_nextEntryAt);
      final entered = _tryEnter(_nextEntryAt, band, chipSize);
      _nextEntryAt += entered ? _entrySpacingSeconds : _retrySeconds;
    }
    _retireBy(seconds);
  }

  void _retireBy(double seconds) {
    _rising.removeWhere((badge) {
      final done = badge.endsAt <= seconds;
      if (done) _idleSlots.add(badge.slot);
      return done;
    });
  }

  bool _tryEnter(double seconds, Size band, Size Function(int slot) chipSize) {
    if (_idleSlots.isEmpty) return false;
    final slot = _idleSlots.first;
    final layer = layerOf(slot);
    final size = chipSize(slot) * FloatingBadge.scaleFor(layer);
    const sway = FloatingBadge.swayAmplitude;
    final travel = math.max(0, band.width - size.width - sway * 2);
    final firstLane = (_fraction(0.21 + _entries * 0.6180339887) * _laneCount)
        .floor();
    for (var i = 0; i < _laneCount; i++) {
      final lane = (firstLane + i * _laneStride) % _laneCount;
      final candidate = FloatingBadge(
        slot: slot,
        enteredAt: seconds,
        left: sway + travel * lane / (_laneCount - 1),
        size: size,
        layer: layer,
        swayPhase: _fraction(0.3 + _entries * 0.6180339887),
      );
      if (!_staysClear(candidate, band)) continue;
      _idleSlots.removeFirst();
      _entries++;
      final nearer = _rising.indexWhere((badge) => badge.layer < layer);
      _rising.insert(nearer == -1 ? _rising.length : nearer, candidate);
      return true;
    }
    return false;
  }

  bool _staysClear(FloatingBadge candidate, Size band) {
    for (
      var t = candidate.enteredAt;
      t < candidate.endsAt;
      t += _sampleSeconds
    ) {
      if (candidate.opacityAt(t) < visibleOpacity) continue;
      final rect = candidate.rectAt(t, band);
      for (final other in _rising) {
        if (t >= other.endsAt || other.opacityAt(t) < visibleOpacity) {
          continue;
        }
        if (_coveredShare(rect, other.rectAt(t, band)) > maxOverlap) {
          return false;
        }
      }
    }
    return true;
  }

  static double _coveredShare(Rect a, Rect b) {
    final overlap = a.intersect(b);
    if (overlap.width <= 0 || overlap.height <= 0) return 0;
    final smaller = math.min(a.width * a.height, b.width * b.height);
    return overlap.width * overlap.height / smaller;
  }
}

/// One chip's trip up the banner, from fading in at the bottom to sliding
/// out past the top.
///
/// Nearer layers are bigger and faster, which is what sells the depth;
/// farther ones also get a lighter background. Every chip is drawn fully
/// opaque: see-through chips muddy the banner behind them.
@immutable
@visibleForTesting
class FloatingBadge {
  const FloatingBadge({
    required this.slot,
    required this.enteredAt,
    required this.left,
    required this.size,
    required this.layer,
    required this.swayPhase,
  });

  /// Side-to-side drift either side of [left].
  static const swayAmplitude = 10.0;

  static const _swaysPerRise = 1.5;

  /// Furthest the chip swings either way, at the ends of its sway.
  static const double _maxTilt = 10 * math.pi / 180;
  static const _farRiseSeconds = 15.0;
  static const _nearRiseSeconds = 9.0;

  static double scaleFor(int layer) => lerpDouble(0.78, 1, _depthOf(layer))!;

  /// 1 for the nearest layer, 0 for the farthest.
  static double _depthOf(int layer) =>
      1 - layer / (FloatingBadgeField.depthLayers - 1);

  /// Index of the [Flow] child this chip paints.
  final int slot;

  final double enteredAt;

  /// Left edge at the middle of the sway.
  final double left;

  /// Painted size, already scaled for depth.
  final Size size;

  /// Depth layer, 0 for the nearest.
  final int layer;

  /// Where in its sway the chip enters, as a share of one sway.
  final double swayPhase;

  double get scale => scaleFor(layer);

  double get riseSeconds =>
      lerpDouble(_farRiseSeconds, _nearRiseSeconds, _depthOf(layer))!;

  double get endsAt => enteredAt + riseSeconds;

  double _progressAt(double seconds) =>
      ((seconds - enteredAt) / riseSeconds).clamp(0.0, 1.0);

  /// Where the chip is in its sway at [seconds]: -1 at the far left, 1 at the
  /// far right. Drives both the drift and the swing, so they stay in step.
  double _swayAt(double seconds) => math.sin(
    (_progressAt(seconds) * _swaysPerRise + swayPhase) * 2 * math.pi,
  );

  Offset topLeftAt(double seconds, Size band) {
    return Offset(
      left + _swayAt(seconds) * swayAmplitude,
      lerpDouble(
        band.height - size.height,
        -size.height,
        _progressAt(seconds),
      )!,
    );
  }

  /// Rotation about the chip's centre, in radians, clockwise as it swings
  /// right and counter-clockwise as it swings left.
  double tiltAt(double seconds) => _swayAt(seconds) * _maxTilt;

  Rect rectAt(double seconds, Size band) => topLeftAt(seconds, band) & size;

  /// Fades in over the first stretch so a chip never pops in at the bottom.
  ///
  /// There is no fade at the top: the chip slides fully out past the band's
  /// edge instead, since chips overlapping while half transparent read as
  /// a smudge.
  double opacityAt(double seconds) {
    final progress = _progressAt(seconds);
    final fadeIn = Curves.easeOut.transform((progress / 0.15).clamp(0.0, 1.0));
    return fadeIn;
  }
}

double _fraction(double value) => value - value.floorToDouble();

class _FloatingBadgesDelegate extends FlowDelegate {
  _FloatingBadgesDelegate({required this.clock, required this.field})
    : super(repaint: clock);

  /// Widest a chip may lay out, as a share of the band width.
  static const _maxChipWidthFraction = 0.6;

  final ValueListenable<double> clock;
  final FloatingBadgeField field;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) {
    return BoxConstraints(
      maxWidth: constraints.maxWidth * _maxChipWidthFraction,
    );
  }

  @override
  void paintChildren(FlowPaintingContext context) {
    final seconds = clock.value;
    final band = context.size;
    field.advanceTo(seconds, band, (slot) => context.getChildSize(slot)!);
    for (final badge in field.rising) {
      final opacity = badge.opacityAt(seconds);
      if (opacity <= 0) continue;
      final center = badge.topLeftAt(seconds, band) + badge.size.center(.zero);
      context.paintChild(
        badge.slot,
        transform: Matrix4.translationValues(center.dx, center.dy, 0)
          ..rotateZ(badge.tiltAt(seconds))
          ..translateByDouble(
            -badge.size.width / 2,
            -badge.size.height / 2,
            0,
            1,
          )
          ..scaleByDouble(badge.scale, badge.scale, 1, 1),
        opacity: opacity,
      );
    }
  }

  @override
  bool shouldRepaint(_FloatingBadgesDelegate oldDelegate) =>
      oldDelegate.clock != clock || oldDelegate.field != field;

  @override
  bool shouldRelayout(_FloatingBadgesDelegate oldDelegate) =>
      oldDelegate.field.slotCount != field.slotCount;
}

/// Opacity of the white coat laid over a chip's background per depth layer.
///
/// Strong on purpose: on the dark chip background, overlay at 50% lifts each
/// layer by half again, enough for every step to read. White labels keep
/// better than 10:1 contrast even on the farthest layer.
const double _depthCoatOpacity = 0.5;

/// [background] under one white coat, blended with overlay, for every depth
/// layer behind the nearest.
///
/// Overlay with white doubles a dark channel rather than mixing it toward
/// white, so a dark green gets lighter while staying green.
Color _depthTintedBackground(Color background, int layer) {
  var tinted = background;
  for (var coat = 0; coat < layer; coat++) {
    tinted = tinted.withValues(
      red: _overlayWhite(tinted.r),
      green: _overlayWhite(tinted.g),
      blue: _overlayWhite(tinted.b),
    );
  }
  return tinted;
}

/// Overlay blend of a white coat onto [channel], at the coat's opacity.
double _overlayWhite(double channel) {
  const white = 1.0;
  final overlaid = channel < 0.5
      ? 2 * channel * white
      : 1 - 2 * (1 - channel) * (1 - white);
  return channel + _depthCoatOpacity * (overlaid - channel);
}
