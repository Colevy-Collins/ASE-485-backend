// models/player_info.dart

class PlayerInfo {
  final String userId;
  String displayName;

  PlayerInfo({required this.userId, required this.displayName});

  factory PlayerInfo.fromJson(Map<String, dynamic> json) {
    return PlayerInfo(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'displayName': displayName,
      };
}
