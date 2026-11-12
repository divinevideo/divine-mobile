// ignore_for_file: public_member_api_docs, Sticker names are self-documenting

import 'package:material_ui/material_ui.dart';

/// Sticker names from the Divine design system sticker set.
///
/// Each value maps to a photographic cutout in `assets/divine_stickers/`: a
/// near-lossless WebP with transparency, at most 512 px on its long edge, in
/// its original proportions. The artwork was generated from text prompts and
/// is dedicated to the public domain. `assets/divine_stickers/PROVENANCE.md`
/// records each sticker's prompt and file hashes, and
/// `tools/process_divine_sticker.dart` turns a generator original into the
/// shipped file.
///
/// The OpenMoji SVGs in `assets/stickers/` are a separate set. The video
/// editor's sticker picker draws from them, and some auth, account and upload
/// screens still load them by path; no variant here uses them.
enum DivineStickerName {
  acRemote('ac_remote'),

  /// The warning triangle. [policeSiren] and [hazardSign] are separate
  /// stickers.
  alert('alert'),

  ashtray('ashtray'),
  avocado('avocado'),
  babyBottle('baby_bottle'),
  babyCarSeat('baby_car_seat'),
  balloonDog('balloon_dog'),
  banana('banana'),
  baseballBat('baseball_bat'),
  basketball('basketball'),
  beachBall('beach_ball'),
  beerCan('beer_can'),
  bicep('bicep'),
  binoculars('binoculars'),

  /// The biohazard plate. Not a variant of [hazardSign].
  biohazardSign('biohazard_sign'),

  /// The stop-hand sign. [raisedHand] and [stopSign] are separate stickers.
  blocked('blocked'),

  /// The round bomb with a lit fuse. Not a variant of [boom].
  bomb('bomb'),

  /// The comic "BOOM!" burst. [bomb] is a separate sticker.
  boom('boom'),

  brokenHeart('broken_heart'),
  cactusVase('cactus_vase'),
  carKeys('car_keys'),
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
  cordlessVacuum('cordless_vacuum'),
  crackedPhoneScreen('cracked_phone_screen'),
  creditCard('credit_card'),
  crtMonitor('crt_monitor'),
  d20Die('d20_die'),
  deliveryBackpack('delivery_backpack'),
  detergentPod('detergent_pod'),
  devilHornsHand('devil_horns_hand'),
  digitalPet('digital_pet'),
  discoBall('disco_ball'),
  discoHelmet('disco_helmet'),
  djController('dj_controller'),
  dogCorgi('dog_corgi'),
  dogInHoodie('dog_in_hoodie'),
  dogLeash('dog_leash'),
  dogShibaInu('dog_shiba_inu'),
  donut('donut'),
  doubleCheeseburger('double_cheeseburger'),
  ear('ear'),
  earthGlobe('earth_globe'),
  eggplant('eggplant'),
  electricScooter('electric_scooter'),
  email('email'),

  /// The bare cardboard tube. Not a variant of [toiletPaper].
  emptyToiletRoll('empty_toilet_roll'),

  espressoMartini('espresso_martini'),
  faceMask('face_mask'),
  fidgetSpinner('fidget_spinner'),
  fingerPointing('finger_pointing'),
  flatTire('flat_tire'),
  flipFlops('flip_flops'),

  /// The pool mattress. Not a variant of [unicornFloat].
  floatingLilo('floating_lilo'),

  foamFinger('foam_finger'),
  forest('forest'),
  forgotPassword('forgot_password'),
  fortuneCookie('fortune_cookie'),
  fountainSoda('fountain_soda'),
  frenchBulldog('french_bulldog'),
  gameController('game_controller'),
  glitterLips('glitter_lips'),

  hairDryer('hair_dryer'),
  handGrip('hand_grip'),
  handSanitizer('hand_sanitizer'),
  handcuffs('handcuffs'),
  handheldConsole('handheld_console'),

  /// The shaka hand. [ceramicHands] is a separate sticker.
  hangLoose('hang_loose'),

  hazardSign('hazard_sign'),
  headphones('headphones'),
  heart('heart'),
  hibiscusFlower('hibiscus_flower'),
  holographicJacket('holographic_jacket'),
  holographicShape('holographic_shape'),
  horse('horse'),
  horseshoeMagnet('horseshoe_magnet'),
  hotAirBalloon('hot_air_balloon'),
  indexFingerPointingUp('index_finger_pointing_up'),

  /// The flamingo pool float. Not a variant of [unicornFloat].
  inflatableFlamingo('inflatable_flamingo'),

  instantCamera('instant_camera'),
  instantPhoto('instant_photo'),
  knightInArmor('knight_in_armor'),
  lipPiercing('lip_piercing'),
  lipstick('lipstick'),
  lowBatteryPhone('low_battery_phone'),
  luckyCat('lucky_cat'),
  luggage('luggage'),
  mannequinHand('mannequin_hand'),
  mapleLeaf('maple_leaf'),
  massageGun('massage_gun'),
  matrixMessageSign('matrix_message_sign'),
  microwaveBurger('microwave_burger'),
  middleFinger('middle_finger'),
  milkBottle('milk_bottle'),
  mirrorBall('mirror_ball'),
  mittens('mittens'),
  mokaPot('moka_pot'),
  motionLamp('motion_lamp'),
  nailPolish('nail_polish'),
  newsCamera('news_camera'),
  oakTree('oak_tree'),
  oldFashionMic('old_fashion_mic'),
  onAirSign('on_air_sign'),
  orangeJuice('orange_juice'),
  padlock('padlock'),
  passportHolder('passport_holder'),
  pause('pause'),
  peaceSign('peace_sign'),
  peaceSignNeon('peace_sign_neon'),
  peach('peach'),
  phoneCharger('phone_charger'),
  pineapplePizza('pineapple_pizza'),
  pinkDumbbells('pink_dumbbells'),
  pixelSunglasses('pixel_sunglasses'),
  pizzaSlice('pizza_slice'),

  /// The red siren. Not a variant of [alert].
  policeSiren('police_siren'),

  poopEmoji('poop_emoji'),
  powerBank('power_bank'),
  profile('profile'),
  programmer('programmer'),
  proteinBar('protein_bar'),
  psychedelicTv('psychedelic_tv'),
  purpleDiamond('purple_diamond'),
  radar('radar'),
  rainforest('rainforest'),

  /// The open palm. Not a variant of [blocked].
  raisedHand('raised_hand'),

  rollerSkates('roller_skates'),
  rotaryPhone('rotary_phone'),
  saltLamp('salt_lamp'),
  samoyedDog('samoyed_dog'),
  schoolBackpack('school_backpack'),
  schoolNotebook('school_notebook'),
  secureVault('secure_vault'),
  serumDropper('serum_dropper'),
  shrimp('shrimp'),
  skateboard('skateboard'),
  skeletonKey('skeleton_key'),
  soapBar('soap_bar'),
  soccerBall('soccer_ball'),
  socksAndSandals('socks_and_sandals'),
  sparkle('sparkle'),
  speakers('speakers'),
  stopSign('stop_sign'),
  storyboard('storyboard'),
  sunglasses('sunglasses'),
  teeth('teeth'),
  tissueBox('tissue_box'),
  toaster('toaster'),
  toddlerBike('toddler_bike'),
  toiletPaper('toilet_paper'),
  trafficBarrel('traffic_barrel'),
  trafficCone('traffic_cone'),
  trailSign('trail_sign'),
  travelPillow('travel_pillow'),
  tulip('tulip'),

  /// The television remote. Not a variant of [acRemote].
  tvRemote('tv_remote'),

  underConstructionSign('under_construction_sign'),
  unicornFloat('unicorn_float'),
  usbStick('usb_stick'),
  venusFlytrap('venus_flytrap'),
  verified('verified'),
  videoCamera('video_camera'),
  videoClapBoard('video_clap_board'),
  vintageTvTestPattern('vintage_tv_test_pattern'),
  vinylRecord('vinyl_record'),
  vrHeadset('vr_headset'),
  wavePool('wave_pool'),
  wetWipes('wet_wipes'),
  wheyProtein('whey_protein'),
  wirelessEarbuds('wireless_earbuds'),
  x('x');

  const DivineStickerName(this.fileName);

  /// The file name, without extension, of this sticker's asset.
  final String fileName;

  /// The full asset path for this sticker.
  String get assetPath => 'assets/divine_stickers/$fileName.webp';
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
