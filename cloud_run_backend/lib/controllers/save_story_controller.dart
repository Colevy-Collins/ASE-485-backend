// controllers/save_story_controller.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../models/story.dart';
import '../firestore_client.dart';
import '../utility/custom_exceptions.dart';

class SaveStoryController {
  Future<Response> handle(Request request, String userId, StoryData storyData) async {
    try {
      final storyJson = storyData.toJson(); 
      print(storyJson);// Ensure StoryData has a toJson() method.
      await saveStory(userId, storyJson);
      return Response.ok(
        jsonEncode({'message': 'Story saved successfully.'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, st) {
      // If it’s one of your custom StoryExceptions, use its 'message' property.
      if (e is StoryException) {
        print("Error saving the story: ${e.message}\nStackTrace: $st");
        return Response.internalServerError(
          body: jsonEncode({'message':e.message}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Otherwise, it's some other (non-custom) error. 
      print("Error saving the story: $e\nStackTrace: $st");
      return Response.internalServerError(
        body: jsonEncode({'message': 'Error saving the story: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
