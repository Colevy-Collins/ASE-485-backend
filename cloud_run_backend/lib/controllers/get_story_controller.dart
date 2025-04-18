// controllers/get_story_controller.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';

import '../models/story.dart';
import '../models/session_store.dart';          // ← new
import '../utility/custom_exceptions.dart';
import '../models/story_storage.dart'; // for getOrCreateStory

class GetStoryController {
  Future<Response> handle(Request request, StoryData callerStory) async {
    try {
      // ── 1. Pick the correct StoryData ────────────────────────────────
      final sessionId = request.requestedUri.queryParameters['sessionId'];
      StoryData storyData = callerStory;

      if (sessionId != null) {
        final info = SessionStore.byId(sessionId);
        if (info == null) {
          return Response.notFound(
            jsonEncode({'message': 'Session not found'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        storyData = getOrCreateStory(info.hostUserId); // host’s story
        print('StoryData: ${storyData.toJson()}');
      }

      // ── 2. Assemble the narrative ───────────────────────────────────
      String initialLeg = '';
      for (var leg in storyData.storyLegs) {
        if (leg.userMessage['content'] != null &&
            leg.userMessage['content'] != 'Start Story') {
          initialLeg += 'Your Choice: ${leg.userMessage['content']}\n\n';
        }
        if (leg.aiResponse['storyLeg'] != null) {
          initialLeg += '${leg.aiResponse['storyLeg']}\n\n';
        }
      }

      // Latest options (if any)
      List options = [];
      if (storyData.storyLegs.isNotEmpty &&
          storyData.storyLegs.last.aiResponse['options'] != null) {
        options = storyData.storyLegs.last.aiResponse['options'];
      }

      // Title
      final storyTitle = storyData.storyTitle ?? 'Untitled Story';

      return Response.ok(
        jsonEncode({
          'initialLeg': initialLeg,
          'options': options,
          'storyTitle': storyTitle,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, st) {
      if (e is StoryException) {
        print('Error retrieving story: ${e.message}\n$st');
        return Response.internalServerError(
          body: jsonEncode({'message': 'Error retrieving story: ${e.message}'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      print('Error retrieving story: $e\n$st');
      return Response.internalServerError(
        body: jsonEncode({'message': 'Error retrieving story: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
