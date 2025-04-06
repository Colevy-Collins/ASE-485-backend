// controllers/delete_story_controller.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../firestore_client.dart';
import '../utility/custom_exceptions.dart';

class DeleteStoryController {
  Future<Response> handle(Request request, String storyId) async {
    try {
      print("storyId: $storyId");
      await deleteSavedStory(storyId);
      return Response.ok(
        jsonEncode({'message': 'Story deleted successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, st) {
      // If it’s one of your custom StoryExceptions, use its 'message' property.
      if (e is StoryException) {
        print("Error deleting story: ${e.message}\nStackTrace: $st");
        return Response.internalServerError(
          body: jsonEncode({'message': 'Error deleting story: ${e.message}'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Otherwise, it's some other (non-custom) error. 
      print("Error deleting story: $e\nStackTrace: $st");
      return Response.internalServerError(
        body: jsonEncode({'message': 'Error deleting story: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
