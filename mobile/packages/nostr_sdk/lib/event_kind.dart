// ABOUTME: Defines Nostr event kind constants for different event types (NIP-01 and extensions).
// ABOUTME: Maps integer kind values to semantic names like metadata, textNote, zap, etc.

class EventKind {
  static const int metadata = 0;

  static const int textNote = 1;

  static const int recommendServer = 2;

  static const int contactList = 3;

  static const int directMessage = 4;

  static const int eventDeletion = 5;

  static const int repost = 6;

  static const int reaction = 7;

  static const int badgeAward = 8;

  static const int groupChatMessage = 9;

  // @Deprecated("deprecated at nips, only query, not gen.")
  // static const int groupChatReply = 10;

  static const int groupNote = 11;

  // @Deprecated(
  //     "deprecated at nips, only query, not gen. and use comment 1111 instead")
  // static const int groupNoteReply = 12;

  static const int sealEventKind = 13;

  static const int privateDirectMessage = 14;

  static const int genericRepost = 16;

  static const int picture = 20;

  static const int giftWrap = 1059;

  static const int fileHeader = 1063;

  static const int storageSharedFile = 1064;

  static const int comment = 1111;

  static const int torrents = 2003;

  static const int communityApproved = 4550;

  static const int poll = 6969;

  static const int groupAddUser = 9000;

  static const int groupRemoveUser = 9001;

  static const int groupEditMetadata = 9002;

  static const int groupAddPermission = 9003;

  static const int groupRemovePermission = 9004;

  static const int groupDeleteEvent = 9005;

  static const int groupEditStatus = 9006;

  static const int groupCreateGroup = 9007;

  static const int groupJoin = 9021;

  static const int zapGoals = 9041;

  static const int zapRequest = 9734;

  static const int zap = 9735;

  static const int relayListMetadata = 10002;

  static const int bookmarksList = 10003;

  static const int groupList = 10009;

  static const int emojisList = 10030;

  static const int nwcInfoEvent = 13194;

  static const int authentication = 22242;

  static const int nwcRequestEvent = 23194;

  static const int nwcResponseEvent = 23195;

  static const int nostrRemoteSigning = 24133;

  static const int blossomHttpAuth = 24242;

  static const int httpAuth = 27235;

  static const int followSets = 30000;

  static const int badgeAccept = 30008;

  static const int badgeDefinition = 30009;

  static const int longForm = 30023;

  static const int longFormLinked = 30024;

  static const int liveEvent = 30311;

  static const int communityDefinition = 34550;

  static const int videoHorizontal = 34235;

  static const int videoVertical = 34236;

  static const int groupMetadata = 39000;

  static const int groupAdmins = 39001;

  static const int groupMembers = 39002;

  // ---------------------------------------------------------------------------
  // NIP-01 Replaceable Event Helpers
  // ---------------------------------------------------------------------------

  /// Checks if an event kind is replaceable (NIP-01).
  ///
  /// Replaceable event kinds: 0, 3, or 10000-19999.
  /// Only one event per pubkey+kind is stored; newer replaces older.
  static bool isReplaceable(int kind) {
    return kind == metadata ||
        kind == contactList ||
        (kind >= 10000 && kind < 20000);
  }

  /// Checks if an event kind is parameterized replaceable (NIP-01).
  ///
  /// Parameterized replaceable event kinds: 30000-39999.
  /// Only one event per pubkey+kind+d-tag is stored; newer replaces older.
  static bool isParameterizedReplaceable(int kind) {
    return kind >= 30000 && kind < 40000;
  }

  /// Checks if an event kind is any type of replaceable (standard or
  /// parameterized).
  static bool isAnyReplaceable(int kind) {
    return isReplaceable(kind) || isParameterizedReplaceable(kind);
  }
}
