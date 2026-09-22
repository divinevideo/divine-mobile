// ignore_for_file: public_member_api_docs, Sticker names are self-documenting

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// Sticker names from the Divine design system sticker set.
///
/// The `DivineSticker` collection in Figma is the source of truth for the
/// catalog, the names and the artwork. Each value maps to a photographic
/// cutout exported from its Figma component into `assets/divine_stickers/`: a
/// lossless WebP with transparency, at most 512 px on its long edge, in its
/// original proportions.
///
/// The OpenMoji SVGs in `assets/stickers/` belong to the video editor's sticker
/// picker and are a separate set. [grandfather] is the only variant still drawn
/// from them.
enum DivineStickerName {
  /// The warning triangle. [policeSiren] and [hazardSign] are separate
  /// stickers.
  alert('alert'),

  art('art'),
  avocado('avocado'),
  balloonDog('balloon_dog'),
  banana('banana'),
  beachBall('beach_ball'),
  bicep('bicep'),
  binoculars('binoculars'),

  /// The stop-hand sign. [raisedHand] and [stopSign] are separate stickers.
  blocked('blocked'),

  bobRoss('bob_ross'),
  boom('boom'),
  brokenHeart('broken_heart'),
  cactusVase('cactus_vase'),
  cassetteTape('cassette_tape'),
  cat('cat'),
  cd('cd'),
  cellPhone('cell_phone'),
  ceramicHands('ceramic_hands'),
  chat('chat'),
  chatteringTeeth('chattering_teeth'),
  cherries('cherries'),
  chiliPepper('chili_pepper'),
  clover('clover'),
  confetti('confetti'),
  crackedPhoneScreen('cracked_phone_screen'),
  crtMonitor('crt_monitor'),

  /// Named `d&d` in Figma, which is not a valid Dart identifier.
  dAndD('d_and_d', figmaName: 'd&d'),

  dealWithItGlasses('deal_with_it_glasses'),
  detergentPod('detergent_pod'),
  devilHornsHand('devil_horns_hand'),
  discoBall('disco_ball'),
  discoHelmet('disco_helmet'),
  dogCorgi('dog_corgi'),
  dogInHoodie('dog_in_hoodie'),
  dogShibaInu('dog_shiba_inu'),
  donut('donut'),
  doubleCheeseburger('double_cheeseburger'),
  ear('ear'),
  earthGlobe('earth_globe'),
  eggplant('eggplant'),
  email('email'),
  espressoMartini('espresso_martini'),
  fingerPointing('finger_pointing'),

  /// The pool mattress. Not a variant of [unicornFloat].
  floatingLilo('floating_lilo'),

  foamFinger('foam_finger'),
  forest('forest'),
  forgotPassword('forgot_password'),
  fortuneCookie('fortune_cookie'),
  frenchBulldog('french_bulldog'),
  gameBoy('game_boy'),
  gameController('game_controller'),
  glitterLips('glitter_lips'),

  /// Legacy exception. Figma has no counterpart, so this keeps its original
  /// OpenMoji SVG until design decides. It backs the recorder's six-second
  /// explainer.
  grandfather.legacySvg('grandfather'),

  handGrip('hand_grip'),

  /// The shaka hand. [ceramicHands] is a separate sticker.
  hangLoose('hang_loose'),

  hazardSign('hazard_sign'),
  headphones('headphones'),
  heart('heart'),
  hibiscusFlower('hibiscus_flower'),
  holographicJacket('holographic_jacket'),
  holographicShape('holographic_shape'),
  horse('horse'),
  hotAirBalloon('hot_air_balloon'),
  idLicense('id_license'),
  indexFingerPointingUp('index_finger_pointing_up'),

  /// The flamingo pool float. Not a variant of [unicornFloat].
  inflatableFlamingo('inflatable_flamingo'),

  knightInArmor('knight_in_armor'),
  lavaLamp('lava_lamp'),
  lipPiercing('lip_piercing'),
  lipstick('lipstick'),
  luggage('luggage'),
  mannequinHand('mannequin_hand'),
  mapleLeaf('maple_leaf'),
  matrixMessageSign('matrix_message_sign'),
  middleFinger('middle_finger'),
  mirrorBall('mirror_ball'),
  mittens('mittens'),
  nailPolish('nail_polish'),
  newsCamera('news_camera'),
  oakTree('oak_tree'),
  oldFashionMic('old_fashion_mic'),
  onAirSign('on_air_sign'),
  padlock('padlock'),
  pause('pause'),
  peaceSign('peace_sign'),
  peaceSignNeon('peace_sign_neon'),
  peach('peach'),
  pineapplePizza('pineapple_pizza'),
  pinkDumbbells('pink_dumbbells'),
  pizzaSlice('pizza_slice'),
  polaroid('polaroid'),
  polaroidCamera('polaroid_camera'),

  /// The red siren. Not a variant of [alert].
  policeSiren('police_siren'),

  poopEmoji('poop_emoji'),
  profile('profile'),
  programmer('programmer'),
  psychedelicTv('psychedelic_tv'),
  purpleDiamond('purple_diamond'),
  radar('radar'),
  rainforest('rainforest'),

  /// The open palm. Not a variant of [blocked].
  raisedHand('raised_hand'),

  rollerSkates('roller_skates'),
  rotaryPhone('rotary_phone'),
  samoyedDog('samoyed_dog'),
  schoolBackpack('school_backpack'),
  schoolNotebook('school_notebook'),
  secureVault('secure_vault'),
  serumDropper('serum_dropper'),
  shockedMan('shocked_man'),
  shrimp('shrimp'),
  skateboard('skateboard'),
  skeletonKey('skeleton_key'),
  soccerBall('soccer_ball'),
  spaceInvader('space_invader'),
  sparkle('sparkle'),
  speakers('speakers'),
  stopSign('stop_sign'),
  storyboard('storyboard'),
  sunglasses('sunglasses'),
  tamagotchi('tamagotchi'),
  tapedBanana('taped_banana'),
  teeth('teeth'),
  toaster('toaster'),
  trafficBarrel('traffic_barrel'),
  trafficCone('traffic_cone'),
  trailSign('trail_sign'),
  trollFace('troll_face'),
  tulip('tulip'),
  underConstructionSign('under_construction_sign'),
  unicornFloat('unicorn_float'),
  verified('verified'),
  videoCamera('video_camera'),
  videoClapBoard('video_clap_board'),
  vintageTvTestPattern('vintage_tv_test_pattern'),
  vinylRecord('vinyl_record'),
  wavePool('wave_pool'),
  x('x');

  const DivineStickerName(this.fileName, {String? figmaName})
    : _figmaName = figmaName,
      isLegacySvg = false;

  /// A variant with no Figma counterpart, still drawn from the OpenMoji SVGs.
  const DivineStickerName.legacySvg(this.fileName)
    : _figmaName = null,
      isLegacySvg = true;

  /// The file name, without extension, of this sticker's asset.
  final String fileName;

  /// Whether this variant is a legacy SVG rather than Figma artwork.
  final bool isLegacySvg;

  final String? _figmaName;

  /// The name of this sticker's component in Figma, or `null` when Figma has
  /// no counterpart.
  ///
  /// Equal to [name] unless the Figma name is not a valid Dart identifier.
  String? get figmaName => isLegacySvg ? null : _figmaName ?? name;

  /// The full asset path for this sticker.
  String get assetPath => isLegacySvg
      ? 'assets/stickers/$fileName.svg'
      : 'assets/divine_stickers/$fileName.webp';
}

/// A sticker from the Divine design system.
///
/// Renders [sticker] inside a [size] by [size] box. The artwork is scaled to
/// fit with its proportions kept, so a wide or tall sticker is letterboxed
/// rather than stretched.
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
    if (sticker.isLegacySvg) {
      return SvgPicture.asset(sticker.assetPath, width: size, height: size);
    }

    return Image.asset(
      sticker.assetPath,
      width: size,
      height: size,
      // Image defaults to scaleDown, which would leave artwork smaller than
      // the box unscaled. The SVG this replaced always filled its box.
      fit: BoxFit.contain,
    );
  }
}
