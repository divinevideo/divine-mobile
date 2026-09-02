// ignore_for_file: public_member_api_docs, Icon names are self-documenting

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Icon names from the Divine design system icon set.
///
/// Each value maps to an SVG asset in `assets/icon/`.
enum DivineIconName {
  androidLogo('AndroidLogo'),
  appleLogo('AppleLogo'),
  arrowArcLeft('arrow_arc_left'),
  arrowArcRight('arrow_arc_right'),
  arrowBendDownLeft('arrow_bend_down_left'),
  arrowBendDownRight('arrow_bend_down_right'),
  arrowBendUpLeft('arrow_bend_up_left'),
  arrowBendUpRight('arrow_bend_up_right'),
  arrowClockwise('ArrowClockwise'),
  arrowCounterClockwise('arrow_counter_clockwise'),
  arrowDown('arrow_down'),
  arrowDownLeft('arrow_down_left'),
  arrowDownRight('arrow_down_right'),
  arrowFatDown('arrow_fat_down'),
  arrowFatLineDown('arrow_fat_line_down'),
  arrowFatLineUp('arrow_fat_line_up'),
  arrowFatLinesDown('arrow_fat_lines_down'),
  arrowFatLinesUp('arrow_fat_lines_up'),
  arrowFatUp('arrow_fat_up'),
  arrowLeft('arrow_left'),
  arrowRight('arrow_right'),
  arrowUp('arrow_up'),
  arrowUUpLeft('arrow_uup_left'),
  arrowUUpRight('arrow_uup_right'),
  arrowUpLeft('arrow_up_left'),
  arrowUpRight('arrow_up_right'),
  arrowsClockwise('arrows_clockwise'),
  arrowsCounterClockwise('arrows_counter_clockwise'),
  bellSimple('bell_simple'),
  bookmarkPlus('bookmark_plus'),
  bookmarkSimple('bookmark_simple'),
  bracketsAngle('brackets_angle'),
  bug('bug'),
  bugFill('bug_fill'),
  camera('camera'),
  cameraPlus('cameraPlus'),
  cameraRetro('retro-camera'),
  cameraRotate('camera_rotate'),
  cameraSlash('camera_slash'),
  caretDown('CaretDown'),
  caretDownFill('caret_down_fill'),
  caretDownDuo('caret_down_duo'),
  caretLeft('CaretLeft'),
  caretRight('caret_right'),
  caretUp('caret_up'),
  chat('chat'),
  chatCircle('chat_circle'),
  chatDuo('chat_duo'),
  chatTeardrop('chat_teardrop'),
  chats('chats'),
  chatsCircle('chats_circle'),
  chatsTeardrop('chats_teardrop'),
  check('Check'),
  checkCircle('check_circle'),
  checks('checks'),
  circleDuo('circle_duo'),
  circlesThree('circles_three'),
  clipboard('clipboard'),
  clockCountdown('clock_countdown'),
  clockCountdown10('clock_countdown_10'),
  clockCountdown3('clock_countdown_3'),
  closedCaptioning('closed_captioning'),
  closedCaptioningFill('closed_captioning_fill'),
  compass('compass'),
  copy('copy'),
  copyNpub('copy_npub'),
  copySimple('copy_simple'),
  copySimpleFill('copy_simple_fill'),
  cropSquare('crop_square'),
  cropPortrait('crop_portrait'),
  divineMark('divine_mark'),
  dotsThree('DotsThree'),
  dotsThreeCircle('dots_three_circle'),
  dotsThreeCircleDuo('dots_three_circle_duo'),
  dotsThreeDuo('dots_three_duo'),
  dotsThreeVertical('dots_three_vertical'),
  downloadSimple('download_simple'),
  envelope('envelope'),
  envelopeSimple('envelope_simple'),
  envelopeSimplePlus('envelope_simple_plus'),
  eye('eye'),
  eyeSlash('eye_slash'),
  faders('faders'),
  fadersHorizontal('faders_horizontal'),
  filmSlate('FilmSlate'),
  fingerprint('fingerprint'),
  flag('flag'),
  flipHorizontal('flip_horizontal'),
  follow('Icon-Follow'),
  folderOpen('folder_open'),
  funnelSimple('funnel_simple'),
  gear('gear'),
  gearSix('gear_six'),
  ghost('Ghost'),
  gif('gif'),
  globe('Globe'),
  graph('graph'),
  gridNine('GridNine'),
  handPointing('hand_pointing'),
  headphones('headphones'),
  heart('heart'),
  heartFill('heart_fill'),
  heartDuo('heart_duo'),
  house('house'),
  houseSimple('house_simple'),
  image('image'),
  images('images'),
  imagesSquare('imagesSquare'),
  info('info'),
  key('key'),
  lightning('lightning'),
  lightningA('lightning_a'),
  lightningSlash('lightning_slash'),
  linkSimple('linkSimple'),
  list('list'),
  listBullets('list_bullets'),
  listDashes('list_dashes'),
  listNumbers('list_numbers'),
  listPlus('list_plus'),
  lockSimple('lock_simple'),
  logo('logo'),
  menu('menu'),
  microphone('microphone'),
  minus('minus'),
  moreHoriz('more_horiz'),
  musicNote('music_note'),
  musicNotes('music_notes'),
  musicNotesSimple('music_notes_simple'),
  paintBrush('paint_brush'),
  paintBucket('paint_bucket'),
  paperPlane('paper_plane'),
  paperPlaneRight('paper_plane_right'),
  paperPlaneTilt('paper_plane_tilt'),
  pause('pause'),
  pauseFill('pause_fill'),
  pauseCircle('pause_circle'),
  pauseCircleFill('pause_circle_fill'),
  pencilSimple('pencil_simple'),
  pencilSimpleLine('pencil_simple_line'),
  pencilSimpleLineDuo('pencil_simple_line_duo'),
  play('play'),
  playFill('play_fill'),
  playCircle('play_circle'),
  playCircleFill('play_circle_fill'),
  playbackModeOff('playback_mode_off'),
  playbackModeOn('playback_mode_on'),
  playlist('playlist'),
  plus('plus'),
  prohibit('prohibit'),
  prohibitInset('prohibitInset'),
  question('question'),
  queue('queue'),
  repeat('repeat'),
  removeLastClip('undo'),
  repeatDuo('repeat_duo'),
  save('save'),
  scissors('scissors'),
  scribble('scribble'),
  sealCheck('seal_check'),
  sealCheckFill('seal_check_fill'),
  sealWarning('seal_warning'),
  search('search'),
  selection('selection'),
  selectionFill('selection_fill'),
  share('share'),
  shareFat('share_fat'),
  shareFatDuo('share_fat_duo'),
  shareNetwork('share_network'),
  shareNetworkFilled('share_network_filled'),
  shieldCheck('shield_check'),
  signIn('sign_in'),
  signOut('sign_out'),
  skull('skull'),
  sliders('sliders'),
  slidersHorizontal('sliders_horizontal'),
  sparkle('sparkle'),
  speakerHigh('speaker_high'),
  speakerSimpleHigh('speaker_simple_high'),
  speakerSimpleSlash('speaker_simple_slash'),
  speakerSimpleX('speaker_simple_x'),
  spinner('spinner'),
  squareDuo('square_duo'),
  squareFill('square_fill'),
  squaresFour('squares_four'),
  stackSimple('stack_simple'),
  sticker('sticker'),
  sun('sun'),
  sunDim('sun_dim'),
  textAa('text_aa'),
  textAlignCenter('text_align_center'),
  textAlignLeft('text_align_left'),
  textAlignRight('text_align_right'),
  textBgNone('square'),
  textBgTransparent('square_duo'),
  textBgFill('square_fill'),
  timer('timer'),
  timer3('timer_3'),
  timer10('timer_10'),
  trash('trash'),
  trashSimple('trash_simple'),
  trendUp('trend_up'),
  user('user'),
  userCheck('userCheck'),
  userCircle('userCircle'),
  userFocus('user_focus'),
  userMinus('userMinus'),
  userPlus('userPlus'),
  users('users'),
  videoCamera('video_camera'),
  warning('warning'),
  warningCircle('warning_circle'),
  waveform('waveform'),
  x('close');

  const DivineIconName(this.fileName);

  /// The SVG file name (without extension) in the assets/icon directory.
  final String fileName;

  /// The full asset path for this icon.
  String get assetPath => 'assets/icon/$fileName.svg';
}

/// An icon widget that renders SVG icons from the Divine design system.
///
/// [DivineIcon] loads an SVG asset by name and renders it at the specified
/// [size] with an optional [color] tint.
///
/// Example usage:
/// ```dart
/// DivineIcon(
///   icon: DivineIconName.caretLeft,
///   size: 24,
///   color: VineTheme.onSurface,
/// )
/// ```
class DivineIcon extends StatelessWidget {
  /// Creates a Divine design system icon.
  const DivineIcon({
    required this.icon,
    this.size = 24,
    this.color,
    this.fit = BoxFit.contain,
    super.key,
  });

  /// The icon to display.
  final DivineIconName icon;

  /// The size of the icon (width and height). Defaults to 24.
  final double size;

  /// The color to apply to the icon. If null, uses the icon's original colors.
  final Color? color;

  /// How the artwork is inscribed into the [size] box. Defaults to
  /// [BoxFit.contain], which letterboxes a non-square asset.
  ///
  /// [BoxFit.cover] instead fills the box and crops the overflow, which is
  /// what a wide asset like the wordmark needs when it stands in for a square
  /// avatar.
  final BoxFit fit;

  /// Upper bound on how far [size] grows with the system text scale.
  ///
  /// Icons track the text scale so they stay proportional to the labels
  /// they sit next to, but unbounded growth breaks tight layouts — at the
  /// 2.0x platform maximum a 24px icon would render at 48px and overflow
  /// narrow rows. Callers must not pre-scale [size]; this widget owns it.
  static const maxScaleFactor = 1.3;

  /// Applies the system text scale to [size], capped at [maxScaleFactor].
  ///
  /// Use this for icon-sized chrome that [DivineIcon] does not render
  /// itself — a raw [Icon] or `SvgPicture`, a spinner standing in for an
  /// icon, or a tap target sized off one — so it grows on the same curve
  /// and stops at the same bound as the icons beside it.
  ///
  /// Do **not** use it on a [size] passed to [DivineIcon]: that scales the
  /// value twice, squaring the factor.
  static double scaleSize(BuildContext context, double size) =>
      MediaQuery.textScalerOf(
        context,
      ).clamp(maxScaleFactor: maxScaleFactor).scale(size);

  @override
  Widget build(BuildContext context) {
    final dimension = scaleSize(context, size);

    return SvgPicture.asset(
      icon.assetPath,
      width: dimension,
      height: dimension,
      fit: fit,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}
