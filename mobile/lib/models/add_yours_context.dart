// ABOUTME: The Add yours a video is recorded to answer: the chain it joins, its
// ABOUTME: prompt and the hashtag every answer in the chain shares.

import 'package:equatable/equatable.dart';

/// The Add yours sticker a video is recorded to answer.
///
/// The editor places the same sticker on the answer, so the chain goes on
/// from there, and names the chain's first video as what inspired it.
class AddYoursContext extends Equatable {
  const AddYoursContext({
    required this.chainRoot,
    required this.prompt,
    required this.hashtag,
  });

  /// The address of the chain's first video, `<kind>:<pubkey>:<d>`.
  final String chainRoot;

  /// What the sticker prompts its answers to show.
  final String prompt;

  /// The hashtag every answer in the chain carries, without its `#`.
  final String hashtag;

  @override
  List<Object?> get props => [chainRoot, prompt, hashtag];
}
