// controllers/save_story_controller.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';

import '../models/story.dart';
import '../models/session_store.dart';          // ← new
import '../firestore_client.dart';
import '../utility/custom_exceptions.dart';
import '../models/story_storage.dart'; // for getOrCreateStory

class SaveStoryController {
  /// Saves *caller’s* own story, **or** a copy of the host’s story when the
  /// optional `sessionId` query parameter is provided.
  Future<Response> handle(
    Request request,
    String callerUserId,
    StoryData callerStory,
  ) async {
    try {
      // ── 1. Determine which story we’re saving ───────────────────────
      final sessionId = request.requestedUri.queryParameters['sessionId'];
      StoryData storyToSave = callerStory;

      if (sessionId != null) {
        final info = SessionStore.byId(sessionId);
        if (info == null) {
          return Response.notFound(
            jsonEncode({'message': 'Session not found'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        storyToSave = getOrCreateStory(info.hostUserId); // host’s story
      }

      // ── 2. Persist under the *caller’s* userId ──────────────────────
      await saveStory(callerUserId, storyToSave.toJson());

      return Response.ok(
        jsonEncode({'message': 'Story saved successfully.'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, st) {
      if (e is StoryException) {
        print('Error saving the story: ${e.message}\n$st');
        return Response.internalServerError(
          body: jsonEncode({'message': e.message}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      print('Error saving the story: $e\n$st');
      return Response.internalServerError(
        body: jsonEncode({'message': 'Error saving the story: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
