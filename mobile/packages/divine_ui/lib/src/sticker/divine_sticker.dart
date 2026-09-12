// ignore_for_file: public_member_api_docs, Sticker names are self-documenting

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// Sticker names from the Divine design system sticker set.
///
/// Each value maps to an OpenMoji SVG asset in `assets/stickers/`.
enum DivineStickerName {
  adjustableDumbbell('adjustable_dumbbell'),
  alert('alert'),
  angryCat('angry_cat'),
  avocado('avocado'),
  ballonDog('ballon_dog'),
  bicep('bicep'),
  blocked('blocked'),
  boom('boom'),
  brokenHeart('broken_heart'),
  chatteringTeeth('chattering_teeth'),
  clover('clover'),
  confetti('confetti'),
  crackedPhoneScreen('cracked_phone_screen'),
  discoBall('disco_ball'),
  discoHelmet('disco_helmet'),
  doubleCheeseburger('double_cheeseburger'),
  donut('donut'),
  eggplant('eggplant'),
  email('email'),
  espressoMartini('espresso_martini'),
  fingerPointing('finger_pointing'),
  floatingLilo('floating_lilo'),
  foamFinger('foam_finger'),
  forgotPassword('forgot_password'),
  forgotPasswordAlt('forgot_password_alt'),
  glitterDonut('glitter_donut'),
  grandfather('grandfather'),
  hangLoose('hang_loose'),
  heart('heart'),
  hibiscusFlower('hibiscus_flower'),
  holographicJacket('holographic_jacket'),
  idLicense('id_license'),
  indexFingerPointingUp('index_finger_pointing_up'),
  inflatableFlamingo('inflatable_flamingo_pool_float'),
  knightInArmor('knight_in_armor'),
  lipPiercing('lip_piercing'),
  mapleLeaf('maple_leaf'),
  matrixMessageSign('matrix_message_sign'),
  nailPolish('nail_polish'),
  nokia3310('nokia_3310'),
  oldFashionMic('old_fashion_mic'),
  password('password'),
  pause('pause'),
  peach('peach'),
  peeledBanana('peeled_banana'),
  policeSiren('police_siren'),
  poopEmoji('poop_emoji'),
  profile('profile'),
  programmer('programmer'),
  purpleDiamond('purple_diamond'),
  radar('radar'),
  raisedHand('raised_hand'),
  samoyedDog('samoyed_dog'),
  shrimp('shrimp'),
  skeletonKey('skeleton_key'),
  sparkle('sparkle'),
  storyboard('storyboard'),
  teeth('teeth'),
  trafficCone('traffic_cone'),
  trailSign('trail_sign'),
  trollFace('troll_face'),
  underConstructionSign('under_construction_sign'),
  verified('verified'),
  videoClapBoard('video_clap_board'),
  videoCamera('video_camera'),
  videogame('videogame'),
  vintageTvTestPattern('vintage_tv_test_pattern'),
  vinylRecord('vinyl_record'),
  wavePool('wave_pool'),
  worldMap('world_map'),
  x('x');

  const DivineStickerName(this.fileName);

  /// The file name (without extension) in the assets/stickers directory.
  final String fileName;

  /// The full asset path for this sticker.
  String get assetPath => 'assets/stickers/$fileName.svg';
}

/// A sticker widget that renders OpenMoji SVG stickers from the Divine
/// design system.
///
/// [DivineSticker] loads an SVG asset by name and renders it at the
/// specified [size]. Stickers are vector SVGs from the OpenMoji set.
///
/// Example usage:
/// ```dart
/// DivineSticker(
///   sticker: DivineStickerName.boom,
///   size: 132,
/// )
/// ```
class DivineSticker extends StatelessWidget {
  /// Creates a Divine design system sticker.
  const DivineSticker({required this.sticker, this.size = 132, super.key});

  /// The sticker to display.
  final DivineStickerName sticker;

  /// The size of the sticker (width and height). Defaults to 132.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      sticker.assetPath,
      width: size,
      height: size,
    );
  }
}
