class PlayerVote {
  final String playerId;
  final String chosenOption;
  final DateTime timestamp;

  PlayerVote({
    required this.playerId,
    required this.chosenOption,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'chosenOption': chosenOption,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
