// utils/story_cleanup.dart
import '../models/story.dart';

void cleanInactiveStories(stories) {
  final now = DateTime.now();
  stories.removeWhere((userId, storyData) {
    return storyData.lastActivity == null ||
        now.difference(storyData.lastActivity!) >= Duration(minutes: 30);
  });
}
