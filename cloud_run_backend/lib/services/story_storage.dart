// services/story_storage.dart
import '../models/story.dart';

// Global map to store story data per user.
final Map<String, StoryData> stories = {};

StoryData getOrCreateStory(String userId) {
  return stories.putIfAbsent(userId, () => StoryData());
}
