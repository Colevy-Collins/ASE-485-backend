// controllers/continue_story_controller.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';

import '../firestore_client.dart';
import '../models/story.dart';
import '../utility/controller_utils.dart';   // <‑‑ new

class ContinueStoryController {
  Future<Response> handle(
    Request request,
    String storyId,
    StoryData storyData,
  ) {
    return guarded(() async {                 // <‑‑ new
      final savedStory = await getSavedStoryById(storyId);

      storyData.updateFromMap(savedStory);

      // Build the narrative response …
      final buffer = StringBuffer();
      for (final leg in storyData.storyLegs) {
        final choice = leg.userMessage['content'];
        if (choice != null && choice != 'Start Story') {
          buffer.writeln('Your Choice: $choice\n');
        }
        final storyLeg = leg.aiResponse['storyLeg'];
        if (storyLeg != null) buffer.writeln('$storyLeg\n');
      }

      return jsonOk({
        'initialLeg': buffer.toString(),
        'options': storyData.storyLegs.last.aiResponse['options'] ?? [],
        'storyTitle': storyData.storyTitle ?? 'Untitled Story',
      });
    });
  }
}
