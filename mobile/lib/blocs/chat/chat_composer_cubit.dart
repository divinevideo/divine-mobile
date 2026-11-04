// ABOUTME: Owns the chat draft, picked account bindings, and send lifecycle.
// ABOUTME: Only explicit account picks are expanded; typed names stay plain text.
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/features/chat/chat_mention_editing.dart';
import 'package:openvine/mentions/mention_text_editing.dart';
import 'package:openvine/models/caption_mention.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

class ChatComposerState extends Equatable {
  const ChatComposerState({
    this.text = '',
    this.mentions = const [],
    this.submitting = false,
    this.sendFailed = false,
    this.selectionStart,
    this.selectionEnd,
  });

  final String text;
  final List<CaptionMention> mentions;
  final bool submitting;
  final bool sendFailed;

  /// The draft's selection at the last [ChatComposerCubit.updateDraft], so the
  /// next edit can tell whether it replaced a selected range.
  final int? selectionStart;
  final int? selectionEnd;

  @override
  List<Object?> get props => [
    text,
    mentions,
    submitting,
    sendFailed,
    selectionStart,
    selectionEnd,
  ];
}

class ChatComposerCubit extends Cubit<ChatComposerState> {
  ChatComposerCubit({required Future<bool> Function(String) send})
    : _send = send,
      super(const ChatComposerState());

  final Future<bool> Function(String) _send;

  void updateDraft(String text, int cursor, {int? selectionExtent}) {
    final extent = selectionExtent ?? cursor;
    emit(
      ChatComposerState(
        text: text,
        mentions: List.unmodifiable(
          updateChatMentionBindings(
            before: state.text,
            after: text,
            cursor: cursor,
            mentions: state.mentions,
            previousSelectionStart: state.selectionStart,
            previousSelectionEnd: state.selectionEnd,
          ),
        ),
        submitting: state.submitting,
        sendFailed: state.sendFailed,
        selectionStart: cursor < extent ? cursor : extent,
        selectionEnd: cursor > extent ? cursor : extent,
      ),
    );
  }

  MentionInsertion? selectMention({
    required int cursor,
    required String pubkey,
    required String display,
  }) {
    final insertion = applyMentionSelection(
      text: state.text,
      cursor: cursor,
      display: display,
    );
    if (insertion == null) return null;
    updateDraft(insertion.text, insertion.selection);
    emit(
      ChatComposerState(
        text: state.text,
        mentions: List.unmodifiable([
          ...state.mentions.where(
            (mention) =>
                mention.end! <= insertion.start ||
                mention.start! >= insertion.end,
          ),
          CaptionMention(
            display: display,
            pubkey: pubkey,
            start: insertion.start,
            end: insertion.end,
          ),
        ]),
        submitting: state.submitting,
        sendFailed: state.sendFailed,
        selectionStart: state.selectionStart,
        selectionEnd: state.selectionEnd,
      ),
    );
    return insertion;
  }

  /// Returns true only if the submitted draft can now be cleared.
  Future<bool> submit() async {
    if (isClosed || state.submitting || state.text.trim().isEmpty) return false;
    final draft = state;
    emit(
      ChatComposerState(
        text: draft.text,
        mentions: draft.mentions,
        submitting: true,
        selectionStart: draft.selectionStart,
        selectionEnd: draft.selectionEnd,
      ),
    );
    var accepted = false;
    try {
      var body = draft.text;
      final bindings = [...draft.mentions]
        ..sort((a, b) => b.start!.compareTo(a.start!));
      var boundary = body.length;
      for (final mention in bindings) {
        final start = mention.start;
        final end = mention.end;
        if (start == null ||
            end == null ||
            start < 0 ||
            end > boundary ||
            !NostrKeyUtils.isValidKey(mention.pubkey) ||
            body.substring(start, end) != '@${mention.display}') {
          continue;
        }
        body = body.replaceRange(
          start,
          end,
          'nostr:${NostrKeyUtils.encodePubKey(mention.pubkey)}',
        );
        boundary = start;
      }
      accepted = await _send(body.trim());
    } on Object catch (error, stack) {
      addError(error, stack);
    }
    if (isClosed) return false;
    final clear =
        accepted &&
        state.text == draft.text &&
        const ListEquality<CaptionMention>().equals(
          state.mentions,
          draft.mentions,
        );
    emit(
      ChatComposerState(
        text: clear ? '' : state.text,
        mentions: clear ? const [] : state.mentions,
        sendFailed: !accepted,
        selectionStart: state.selectionStart,
        selectionEnd: state.selectionEnd,
      ),
    );
    return clear;
  }
}
