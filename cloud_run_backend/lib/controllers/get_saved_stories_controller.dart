// controllers/get_saved_stories_controller.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../firestore_client.dart';

class GetSavedStoriesController {
  Future<Response> handle(Request request, String userId) async {
    try {
      final savedStories = await getSavedStories(userId);
      return Response.ok(
        jsonEncode({'stories': savedStories}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print("Error retrieving saved stories for user $userId: $e");
      return Response.internalServerError(
        body: jsonEncode({'message': 'Error retrieving saved stories: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
