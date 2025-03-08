// controllers/get_story_controller.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../models/story.dart';

class GetStoryController {
  Future<Response> handle(Request request, StoryData storyData) async {
    // Build the complete narrative by concatenating all AI responses.
    String initialLeg = '';
    for (var leg in storyData.storyLegs) {
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
  }
}
