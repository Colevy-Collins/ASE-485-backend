// controllers/get_saved_stories_controller.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../firestore_client.dart';
import '../utility/custom_exceptions.dart';

class GetSavedStoriesController {
  Future<Response> handle(Request request, String userId) async {
    try {
      final savedStories = await getSavedStories(userId);
      return Response.ok(
        jsonEncode({'stories': savedStories}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, st) {
      // If it’s one of your custom StoryExceptions, use its 'message' property.
      if (e is StoryException) {
        print("Error retrieving saved stories: ${e.message}\nStackTrace: $st");
        return Response.internalServerError(
          body: jsonEncode({'message': 'Error retrieving saved stories: ${e.message}'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Otherwise, it's some other (non-custom) error. 
      print("Error retrieving saved stories: $e\nStackTrace: $st");
      return Response.internalServerError(
        body: jsonEncode({'message': 'Error retrieving saved stories: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
