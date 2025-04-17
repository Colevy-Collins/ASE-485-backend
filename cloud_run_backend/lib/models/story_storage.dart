// services/story_storage.dart
import 'story.dart';

// Global map to store story data per user.
final Map<String, StoryData> stories = {};

// Returns the existing story for the user or creates one if not present.
StoryData getOrCreateStory(String userId) {
  return stories.putIfAbsent(userId, () => StoryData());
}

// Resets the story for the given user by creating a new StoryData object,
// updates the lastActivity to now, and stores it in the global map.
StoryData resetStoryForUser(String userId) {
  final newStory = StoryData();
  newStory.lastActivity = DateTime.now();
  stories[userId] = newStory;
  return newStory;
}
