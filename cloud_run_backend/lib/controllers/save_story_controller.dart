// controllers/save_story_controller.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../models/story.dart';
import '../firestore_client.dart';

class SaveStoryController {
  Future<Response> handle(Request request, String userId, StoryData storyData) async {
    try {
      final storyJson = storyData.toJson(); // Ensure StoryData has a toJson() method.
      await saveStory(userId, storyJson);
      return Response.ok(
        jsonEncode({'message': 'Story saved successfully.'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print("Error saving story for user $userId: $e");
      if (e.toString().contains("maximum number of saved stories")) {
        return Response(
          400,
          body: jsonEncode({'message': 'You have reached the maximum number of saved stories.'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
      return Response.internalServerError(
        body: jsonEncode({'message': 'Error saving story: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
