// controllers/next_leg_controller.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../models/story.dart';
import '../services/story_manager.dart';
import '../utility/custom_exceptions.dart';

class PreviousLegController {
  final StoryManager _storyManager = StoryManager();

  Future<Response> handle(Request request, StoryData storyData) async {
    try {

    _storyManager.removeLastStoryLeg(storyData);

    // Grab the new last leg
    final lastLeg = storyData.storyLegs.last;

    // Return its aiResponse so the client sees the now-current story state
    return Response.ok(
      jsonEncode({
        'aiResponse': lastLeg.aiResponse,
        'message': 'Story rolled back to previous leg.'
      }),
      headers: {'Content-Type': 'application/json'},
    );
    } catch (e, st) {
      // If it’s one of your custom StoryExceptions, use its 'message' property.
      if (e is StoryException) {
        print("Error reverting to previous leg: ${e.message}\nStackTrace: $st");
        return Response.internalServerError(
          body: jsonEncode({'message': 'Error reverting to previous leg: ${e.message}'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Otherwise, it's some other (non-custom) error. 
      print("Error reverting to previous leg: $e\nStackTrace: $st");
      return Response.internalServerError(
        body: jsonEncode({'message': 'Error reverting to previous leg: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}