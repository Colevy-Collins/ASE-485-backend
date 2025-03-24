// controllers/next_leg_controller.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../models/story.dart';
import '../services/story_manager.dart';
import '../services/gemini_service.dart';

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
    } catch (e) {
      print('Error processing /previous_leg request: $e');
      return Response.internalServerError(body: 'Error processing request: $e');
    }
  }
}