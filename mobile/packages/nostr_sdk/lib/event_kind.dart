class EventKind {
  static const int METADATA = 0;

  static const int TEXT_NOTE = 1;

  static const int RECOMMEND_SERVER = 2;

  static const int CONTACT_LIST = 3;

  static const int DIRECT_MESSAGE = 4;

  static const int EVENT_DELETION = 5;

  static const int REPOST = 6;

  static const int REACTION = 7;

  static const int BADGE_AWARD = 8;

  static const int GROUP_CHAT_MESSAGE = 9;

  // @Deprecated("deprecated at nips, only query, not gen.")
  // static const int GROUP_CHAT_REPLY = 10;

  static const int GROUP_NOTE = 11;

  // @Deprecated(
  //     "deprecated at nips, only query, not gen. and use COMMENT 1111 instead")
  // static const int GROUP_NOTE_REPLY = 12;

  static const int SEAL_EVENT_KIND = 13;

  static const int PRIVATE_DIRECT_MESSAGE = 14;

  static const int GENERIC_REPOST = 16;

  static const int PICTURE = 20;

  static const int GIFT_WRAP = 1059;

  static const int FILE_HEADER = 1063;

  static const int STORAGE_SHARED_FILE = 1064;

  static const int COMMENT = 1111;

  static const int TORRENTS = 2003;

  static const int COMMUNITY_APPROVED = 4550;

  static const int POLL = 6969;

  static const int GROUP_ADD_USER = 9000;

  static const int GROUP_REMOVE_USER = 9001;

  static const int GROUP_EDIT_METADATA = 9002;

  static const int GROUP_ADD_PERMISSION = 9003;

  static const int GROUP_REMOVE_PERMISSION = 9004;

  static const int GROUP_DELETE_EVENT = 9005;

  static const int GROUP_EDIT_STATUS = 9006;

  static const int GROUP_CREATE_GROUP = 9007;

  static const int GROUP_JOIN = 9021;

  static const int ZAP_GOALS = 9041;

  static const int ZAP_REQUEST = 9734;

  static const int ZAP = 9735;

  static const int RELAY_LIST_METADATA = 10002;

  static const int BOOKMARKS_LIST = 10003;

  static const int GROUP_LIST = 10009;

  static const int EMOJIS_LIST = 10030;

  static const int NWC_INFO_EVENT = 13194;

  static const int AUTHENTICATION = 22242;

  static const int NWC_REQUEST_EVENT = 23194;

  static const int NWC_RESPONSE_EVENT = 23195;

  static const int NOSTR_REMOTE_SIGNING = 24133;

  static const int BLOSSOM_HTTP_AUTH = 24242;

  static const int HTTP_AUTH = 27235;

  static const int FOLLOW_SETS = 30000;

  static const int BADGE_ACCEPT = 30008;

  static const int BADGE_DEFINITION = 30009;

  static const int LONG_FORM = 30023;

  static const int LONG_FORM_LINKED = 30024;

  static const int LIVE_EVENT = 30311;

  static const int COMMUNITY_DEFINITION = 34550;

  static const int VIDEO_HORIZONTAL = 34235;

  static const int VIDEO_VERTICAL = 34236;

  static const int GROUP_METADATA = 39000;

  static const int GROUP_ADMINS = 39001;

  static const int GROUP_MEMBERS = 39002;
}
