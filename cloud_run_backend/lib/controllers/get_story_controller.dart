// controllers/get_story_controller.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../models/story.dart';
import '../utility/custom_exceptions.dart';

class GetStoryController {
  Future<Response> handle(Request request, StoryData storyData) async {
    // Build the complete narrative by concatenating all AI responses.
    try {
      String initialLeg = '';
      for (var leg in storyData.storyLegs) {
        if (leg.userMessage['content'] != null && leg.userMessage['content'] != "Start Story") {
          initialLeg += "Your Choice:" + leg.userMessage['content'] + '\n\n';
        }
        if (leg.aiResponse['storyLeg'] != null) {
          initialLeg += leg.aiResponse['storyLeg'] + '\n\n';
        }
      }
    // Get the options from the last leg (if available).
    List options = [];
    if (storyData.storyLegs.isNotEmpty &&
        storyData.storyLegs.last.aiResponse['options'] != null) {
      options = storyData.storyLegs.last.aiResponse['options'];
    }
    // Use the stored story title; if not set, fall back to "Untitled Story".
    String storyTitle = storyData.storyTitle ?? "Untitled Story";

    return Response.ok(
      jsonEncode({
        'initialLeg': initialLeg,
        'options': options,
        'storyTitle': storyTitle,
      }),
      headers: {'Content-Type': 'application/json'},
    );
        } catch (e, st) {
      // If it’s one of your custom StoryExceptions, use its 'message' property.
      if (e is StoryException) {
        print("Error retrieving story: ${e.message}\nStackTrace: $st");
        return Response.internalServerError(
          body: jsonEncode({'message': 'Error retrieving story: ${e.message}'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Otherwise, it's some other (non-custom) error. 
      print("Error retrieving story: $e\nStackTrace: $st");
      return Response.internalServerError(
        body: jsonEncode({'message': 'Error retrieving story: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
