// ABOUTME: How the effects that hit (the shockwave, the subwoofer and the
// ABOUTME: blasts) look beyond their intensity: where, how far, how hard.

import 'package:equatable/equatable.dart';

/// How the effects that hit look beyond their intensity, stored in the
/// params of their `CustomVideoEffect` and read by the native
/// `BassHitVideoEffect` and `BlastVideoEffect` (their `HitLook`).
///
/// [shake], [punch] and [fringe] scale what the effect does on its own: 1 is
/// its default, 0 leaves it out and 2 doubles it.
class HitLookSettings extends Equatable {
  const HitLookSettings({
    this.centerX = 0.5,
    this.centerY = 0.5,
    this.reach = 1,
    this.shake = 1,
    this.punch = 1,
    this.fringe = 1,
    this.color,
  });

  /// Reads the settings from a custom effect's [params], falling back to the
  /// default for anything missing and clamping the rest into range.
  factory HitLookSettings.fromParams(Map<String, dynamic> params) {
    double read(String key, double fallback, double min, double max) =>
        ((params[key] as num?)?.toDouble() ?? fallback).clamp(min, max);
    return HitLookSettings(
      centerX: read(centerXParam, 0.5, 0, 1),
      centerY: read(centerYParam, 0.5, 0, 1),
      reach: read(reachParam, 1, minReach, 1),
      shake: read(shakeParam, 1, 0, maxScale),
      punch: read(punchParam, 1, 0, maxScale),
      fringe: read(fringeParam, 1, 0, maxScale),
      color: (params[colorParam] as num?)?.toInt(),
    );
  }

  /// The least [reach]: a blast a fifth as large, a cone a fifth as wide.
  static const minReach = 0.2;

  /// The most [shake], [punch] and [fringe] may scale up to.
  static const maxScale = 2.0;

  /// The param names, as the native renderers read them.
  static const centerXParam = 'centerX';
  static const centerYParam = 'centerY';
  static const reachParam = 'reach';
  static const shakeParam = 'shake';
  static const punchParam = 'punch';
  static const fringeParam = 'fringe';
  static const colorParam = 'color';

  /// Where the effect hits, as a share of the frame's width from its left
  /// edge and of its height from its top edge.
  final double centerX;
  final double centerY;

  /// How far the effect spreads, from [minReach] to 1: at 1 a ring passes the
  /// farthest corner, and a subwoofer's cone is half the shorter side wide.
  final double reach;

  /// How hard the picture rattles.
  final double shake;

  /// How far the picture punches in.
  final double punch;

  /// How far the shockwave splits the colours.
  final double fringe;

  /// The colour of a blast's glow, liquid or smoke as an ARGB integer, or
  /// `null` for the blast's own (see `EditorEffectType.hitColor`).
  final int? color;

  /// The params to store next to the intensity.
  Map<String, Object> toParams() => {
    centerXParam: centerX,
    centerYParam: centerY,
    reachParam: reach,
    shakeParam: shake,
    punchParam: punch,
    fringeParam: fringe,
    colorParam: ?color,
  };

  HitLookSettings copyWith({
    double? centerX,
    double? centerY,
    double? reach,
    double? shake,
    double? punch,
    double? fringe,
    int? color,
  }) {
    return HitLookSettings(
      centerX: centerX ?? this.centerX,
      centerY: centerY ?? this.centerY,
      reach: reach ?? this.reach,
      shake: shake ?? this.shake,
      punch: punch ?? this.punch,
      fringe: fringe ?? this.fringe,
      color: color ?? this.color,
    );
  }

  @override
  List<Object?> get props => [
    centerX,
    centerY,
    reach,
    shake,
    punch,
    fringe,
    color,
  ];
}
