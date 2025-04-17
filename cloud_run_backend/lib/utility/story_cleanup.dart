// story_cleanup.dart

import '../models/story_storage.dart';      // for stories map
import '../controllers/create_multiplayer_session_controller.dart'; // for multiplayerSessions map

void cleanInactiveStories() {
  final now = DateTime.now();

  // 1) Clean up individual stories.
  stories.removeWhere((userId, storyData) {
    return storyData.lastActivity == null ||
        now.difference(storyData.lastActivity!) >= Duration(minutes: 30);
  });

  // 2) Clean up multiplayer sessions whose host (player 1) is inactive.
  //multiplayerSessions.removeWhere((sessionId, session) {
  //  final hostStory = session.storyState;
  //  return hostStory.lastActivity == null ||
  //      now.difference(hostStory.lastActivity!) >= Duration(minutes: 30);
  //});
}
