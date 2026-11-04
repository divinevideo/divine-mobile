/// The votes on a NIP-88 poll, as the server counts them.
class PollVoteTally {
  /// Creates a tally.
  const PollVoteTally({required this.votes, required this.voters});

  /// Parses the poll results endpoint response.
  factory PollVoteTally.fromJson(Map<String, dynamic> json) {
    final options = json['options'];
    return PollVoteTally(
      votes: {
        if (options is List)
          for (final option in options.whereType<Map<String, dynamic>>())
            if (option['id'] is String)
              option['id'] as String: _parseCount(option['votes']),
      },
      voters: _parseCount(json['voters']),
    );
  }

  /// How many voters picked each option, by its id.
  final Map<String, int> votes;

  /// How many pubkeys have a vote that counts.
  final int voters;

  static int _parseCount(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
