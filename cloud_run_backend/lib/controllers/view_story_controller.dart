// controllers/view_story_controller.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../firestore_client.dart';
import '../models/story.dart';

class ViewStoryController {
  Future<Response> handle(Request request, String storyId) async {
    try {
      // Retrieve the saved story from Firestore using its ID.
      final savedStory = await getSavedStoryById(storyId);

      // Update the story data from the retrieved information.
      var storyData = StoryData();
      storyData.updateFromMap(savedStory);

      // Build the narrative response by concatenating all story legs.
      String initialLeg = '';
      for (var leg in storyData.storyLegs) {
        if (leg.userMessage['content'] != null && leg.userMessage['content'] != "Start Story") {
          initialLeg += "Your Choice:" + leg.userMessage['content'] + '\n\n';
        }
        if (leg.aiResponse['storyLeg'] != null) {
          initialLeg += leg.aiResponse['storyLeg'] + '\n\n';
        }
      }

      // Get the options from the last leg, if available.
      List options = [];
      if (storyData.storyLegs.isNotEmpty &&
          storyData.storyLegs.last.aiResponse['options'] != null) {
        options = storyData.storyLegs.last.aiResponse['options'];
      }

      // Use the stored story title or default to "Untitled Story".
      String storyTitle = storyData.storyTitle ?? "Untitled Story";

      return Response.ok(
        jsonEncode({
          'initialLeg': initialLeg,
          'options': options,
          'storyTitle': storyTitle,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print("Error viewing story: $e");
      return Response.internalServerError(
        body: jsonEncode({'message': 'Error viewing story: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
