// ABOUTME: Verified navigation outcomes for an account's inbound gift wrap.

import 'dart:convert';

import 'package:db_client/db_client.dart';

/// Social state for the same account that owns the message row.
typedef DmWrapAudience = ({
  Set<String> hidden,
  Set<String> followed,
  String? supportPubkey,
});

/// A pending wrap may still arrive via normal DM ingestion.
sealed class DmWrapLookup {
  /// Common base for verified lookup results.
  const DmWrapLookup();

  /// Applies the active owner’s social policy to one SQLite snapshot.
  static DmWrapLookup fromRecord(
    DmWrapRecord row,
    String ownerPubkey,
    DmWrapAudience? audience,
  ) {
    final id = row.messageId;
    if (id == null) {
      if (row.hasAlias) return const DmWrapDeleted();
      return row.hasLedger ? const DmWrapSuppressed() : const DmWrapPending();
    }
    if (row.sender?.toLowerCase() == ownerPubkey.toLowerCase()) {
      return const DmWrapNotInbound();
    }
    if (row.isDeleted) return const DmWrapDeleted();
    if (row.isHidden || row.participantsJson == null) {
      return const DmWrapSuppressed();
    }
    if (audience == null) return const DmWrapPending();
    final sender = row.sender?.toLowerCase();
    final owner = ownerPubkey.toLowerCase();
    final Object? decoded;
    try {
      decoded = jsonDecode(row.participantsJson!);
    } on FormatException {
      return const DmWrapSuppressed();
    }
    if (decoded is! List || decoded.any((p) => p is! String)) {
      return const DmWrapSuppressed();
    }
    final peers = decoded
        .cast<String>()
        .map((key) => key.toLowerCase())
        .toSet();
    if (!peers.remove(owner) ||
        !peers.contains(sender) ||
        audience.hidden.contains(sender)) {
      return const DmWrapSuppressed();
    }
    final isSupport =
        peers.length == 1 && peers.single == audience.supportPubkey;
    return DmWrapFound(
      conversationId: row.conversationId!,
      messageId: id,
      participants: Set.unmodifiable(peers),
      isRequest:
          !row.hasSent &&
          !isSupport &&
          !peers.every(audience.followed.contains),
    );
  }
}

/// A visible inbound message in a room the account still holds.
final class DmWrapFound extends DmWrapLookup {
  /// Identifies the local row and its allowed destination.
  const DmWrapFound({
    required this.conversationId,
    required this.messageId,
    required this.participants,
    required this.isRequest,
  });

  /// The owning conversation.
  final String conversationId;

  /// The verified rumor ID at which to focus.
  final String messageId;

  /// Whether this message can only be opened in the request preview.
  final bool isRequest;

  /// The non-self participants whose DM gate must allow the open.
  final Set<String> participants;
}

/// No owner-scoped evidence has settled yet.
final class DmWrapPending extends DmWrapLookup {
  /// No owner-scoped evidence has settled yet.
  const DmWrapPending();
}

/// A terminal outcome or local privacy rule prevents navigation.
final class DmWrapSuppressed extends DmWrapLookup {
  /// A terminal outcome or local privacy rule prevents navigation.
  const DmWrapSuppressed();
}

/// The owner authored this message.
final class DmWrapNotInbound extends DmWrapLookup {
  /// The owner authored this message.
  const DmWrapNotInbound();
}

/// The verified target has been removed or retracted.
final class DmWrapDeleted extends DmWrapLookup {
  /// The verified target has been removed or retracted.
  const DmWrapDeleted();
}
