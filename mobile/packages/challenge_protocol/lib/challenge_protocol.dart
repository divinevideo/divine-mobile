/// Verified, immutable Divine challenge convention v1 projections.
///
/// This application convention builds on Nostr; it does not define a new NIP.
/// Builders return unsigned templates and do not authorize or publish them.
library;

import 'dart:convert';

import 'package:bech32/bech32.dart';
import 'package:bip340/bip340.dart' as schnorr;
import 'package:challenge_protocol/src/time_zones.dart';
import 'package:characters/characters.dart';
import 'package:crypto/crypto.dart';

part 'src/builders.dart';
part 'src/coordinate.dart';
part 'src/models.dart';
part 'src/reducer.dart';
part 'src/signed_event.dart';
part 'src/validation.dart';
