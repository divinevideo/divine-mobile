enum LiveRole {
  host,
  moderator,
  speaker,
  audience;

  static LiveRole fromNostrRole(String? rawRole) {
    final normalized = rawRole?.trim().toLowerCase();
    switch (normalized) {
      case 'host':
      case 'owner':
        return LiveRole.host;
      case 'moderator':
        return LiveRole.moderator;
      case 'speaker':
        return LiveRole.speaker;
      case 'participant':
      case 'audience':
      default:
        return LiveRole.audience;
    }
  }

  bool get canModerate => this == LiveRole.host || this == LiveRole.moderator;

  bool get canPublish => this == LiveRole.host || this == LiveRole.speaker;

  String get nostrRoleLabel {
    switch (this) {
      case LiveRole.host:
        return 'Host';
      case LiveRole.moderator:
        return 'Moderator';
      case LiveRole.speaker:
        return 'Speaker';
      case LiveRole.audience:
        return 'Participant';
    }
  }
}
