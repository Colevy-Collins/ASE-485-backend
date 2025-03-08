// api_handler.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../controllers/get_story_controller.dart';
import '../controllers/start_story_controller.dart';
import '../controllers/next_leg_controller.dart';
import '../controllers/save_story_controller.dart';
import '../controllers/get_saved_stories_controller.dart';
import '../utility/story_cleanup.dart';
import '../services/story_storage.dart';

Handler createApiHandler() {
  return (Request request) async {
    // Clean up inactive stories.
    cleanInactiveStories(stories);
    
    final userId = request.headers['X-User-Id'];
    if (userId == null) return Response.forbidden('User ID not found.');
    final path = request.requestedUri.path;

    // Get or create the story data for this user.
    final storyData = getOrCreateStory(userId);
    storyData.lastActivity = DateTime.now();

    if (path == '/story' && request.method == 'GET') {
      return GetStoryController().handle(request, storyData);
    } else if (path == '/start_story' && request.method == 'POST') {
      return StartStoryController().handle(request, storyData);
    } else if (path == '/next_leg' && request.method == 'POST') {
      return NextLegController().handle(request, storyData);
    } else if (path == '/save_story' && request.method == 'POST') {
      return SaveStoryController().handle(request, userId, storyData);
    } else if (path == '/saved_stories' && request.method == 'GET') {
      return GetSavedStoriesController().handle(request, userId);
    } else {
      return Response.notFound('Route not found');
    }
  };
}
