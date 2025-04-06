// controllers/continue_story_controller.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../firestore_client.dart';
import '../models/story.dart';
import '../utility/custom_exceptions.dart';

class ContinueStoryController {
  Future<Response> handle(Request request, String storyId, StoryData storyData) async {
    try {
      // Retrieve the saved story from Firestore using its ID.
      final savedStory = await getSavedStoryById(storyId);
      
      // Update the active story data.
      // We assume that StoryData has a fromJson() method that updates its properties.
      storyData.updateFromMap(savedStory);
      
      // Optionally, add the storyData to a global active stories list here
      // if you are tracking multiple active stories globally.
      // e.g.: activeStories[userId] = storyData;
      
      // Build the narrative response similarly to your GetStoryController.
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
    } catch (e, st) {
  // If it’s one of your custom StoryExceptions, use its 'message' property.
      if (e is StoryException) {
        print("Error continuing story: ${e.message}\nStackTrace: $st");
        return Response.internalServerError(
          body: jsonEncode({'message': 'Error continuing story: ${e.message}'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Otherwise, it's some other (non-custom) error. 
      print("Error continuing story: $e\nStackTrace: $st");
      return Response.internalServerError(
        body: jsonEncode({'message': 'Error continuing story: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
