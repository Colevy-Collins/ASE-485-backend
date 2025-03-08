// controllers/delete_story_controller.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../firestore_client.dart';

class DeleteStoryController {
  Future<Response> handle(Request request, String storyId) async {
    try {
      print("storyId: $storyId");
      await deleteSavedStory(storyId);
      return Response.ok(
        jsonEncode({'message': 'Story deleted successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print("Error deleting story: $e");
      return Response.internalServerError(
        body: jsonEncode({'message': 'Error deleting story: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
