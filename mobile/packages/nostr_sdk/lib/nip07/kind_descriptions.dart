import '../utils/string_util.dart';

class KindDescriptions {
  static String getDes(int kind) {
    var des = _kds[kind];
    if (StringUtil.isNotBlank(des)) {
      return des!;
    }
    if (5000 <= kind || kind <= 5999) {
      return "Job Request	";
    }
    if (6000 <= kind || kind <= 6999) {
      return "Job Result";
    }
    return "Unknow Event";
  }

  static final Map<int, String> _kds = {}
    ..[0] = "Metadata"
    ..[1] = "Short Text Note"
    ..[2] = "Recommend Relay"
    ..[3] = "Contacts"
    ..[4] = "Encrypted Direct Messages"
    ..[5] = "Event Deletion"
    ..[6] = "Repost"
    ..[7] = "Reaction"
    ..[8] = "Badge Award"
    ..[16] = "Generic Repost"
    ..[40] = "Channel Creation"
    ..[41] = "Channel Metadata"
    ..[42] = "Channel Message"
    ..[43] = "Channel Hide Message"
    ..[44] = "Channel Mute User"
    ..[1063] = "File Metadata"
    ..[1311] = "Live Chat Message"
    ..[1040] = "OpenTimestamps"
    ..[1971] = "Problem Tracker"
    ..[1984] = "Reporting"
    ..[1985] = "Label"
    ..[4550] = "Community Post Approval"
    ..[7000] = "Job Feedback"
    ..[9041] = "Zap Goal"
    ..[9734] = "Zap Request"
    ..[9735] = "Zap"
    ..[9802] = "Highlights"
    ..[10000] = "Mute list"
    ..[10001] = "Pin list"
    ..[10002] = "Relay List Metadata"
    ..[10003] = "Bookmark list"
    ..[10004] = "Communities list"
    ..[10005] = "Public chats list"
    ..[10006] = "Blocked relays list"
    ..[10007] = "Search relays list"
    ..[10015] = "Interests list"
    ..[10030] = "User emoji list"
    ..[13194] = "Wallet Info"
    ..[22242] = "Client Authentication"
    ..[23194] = "Wallet Request"
    ..[23195] = "Wallet Response"
    ..[24133] = "Nostr Connect"
    ..[27235] = "HTTP Auth"
    ..[30000] = "Follow sets"
    ..[30001] = "Generic lists"
    ..[30002] = "Relay sets"
    ..[30003] = "Bookmark sets"
    ..[30004] = "Curation sets"
    ..[30008] = "Profile Badges"
    ..[30009] = "Badge Definition"
    ..[30015] = "Interest sets"
    ..[30030] = "Emoji sets"
    ..[30017] = "Create or update a stall"
    ..[30018] = "Create or update a product"
    ..[30023] = "Long-form Content"
    ..[30024] = "Draft Long-form Content"
    ..[30078] = "Application-specific Data"
    ..[30311] = "Live Event"
    ..[30315] = "User Statuses"
    ..[30402] = "Classified Listing"
    ..[30403] = "Draft Classified Listing"
    ..[31922] = "Date-Based Calendar Event"
    ..[31923] = "Time-Based Calendar Event"
    ..[31924] = "Calendar"
    ..[31925] = "Calendar Event RSVP"
    ..[31989] = "Handler recommendation"
    ..[31990] = "Handler information"
    ..[34550] = "Community Definition";
}
