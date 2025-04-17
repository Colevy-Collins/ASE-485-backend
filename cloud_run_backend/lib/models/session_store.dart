/// A **very lightweight** in‑memory store that maps
///   • `joinCode  → SessionInfo`  (for join‑code lookup)
///   • `sessionId → SessionInfo`  (for internal use)
///
/// In production you would replace this with Redis / Firestore.
import '../models/story.dart';

class SessionInfo {
  final String sessionId;
  final String hostUserId;
  final StoryData story;          // the host’s StoryData container

  SessionInfo({
    required this.sessionId,
    required this.hostUserId,
    required this.story,
  });

  Map<String, dynamic> toJson() => {
        'sessionId':  sessionId,
        'hostUserId': hostUserId,
        // optional:  story.toJson()
      };
}

class SessionStore {
  // joinCode → SessionInfo
  static final Map<String, SessionInfo> _codeMap = {};

  // sessionId → SessionInfo (convenience reverse index)
  static final Map<String, SessionInfo> _idMap   = {};

  /// Generates and registers a new session. Returns the joinCode.
  static String createSession({
    required String hostUserId,
    required String sessionId,
    required String joinCode,
    required StoryData story,
  }) {
    final info = SessionInfo(
      sessionId:  sessionId,
      hostUserId: hostUserId,
      story:     story,
    );
    _codeMap[joinCode] = info;
    _idMap[sessionId]  = info;
    return joinCode;
  }

  static SessionInfo? byCode(String joinCode) => _codeMap[joinCode];
  static SessionInfo? byId  (String sessionId) => _idMap[sessionId];

  /// Optional helpers
  static bool removeById(String sessionId) {
    final info = _idMap.remove(sessionId);
    if (info == null) return false;
    _codeMap.removeWhere((_, v) => v.sessionId == sessionId);
    return true;
  }
}
