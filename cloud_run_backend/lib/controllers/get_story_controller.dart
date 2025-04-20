import 'package:shelf/shelf.dart';

import '../models/story.dart';
import '../models/session_store.dart';
import '../models/story_storage.dart';
import '../utility/controller_utils.dart';

class GetStoryController {
  Future<Response> handle(Request request, StoryData callerStory) {
    return guarded(() async {
      // ── 1 · Pick the correct StoryData (solo or multiplayer host) ─────────
      final sessionId = request.requestedUri.queryParameters['sessionId'];
      StoryData storyData = callerStory;

      if (sessionId != null) {
        final info = SessionStore.byId(sessionId);
        if (info == null) {
          return jsonError(404, {'message': 'Session not found'});
        }
        storyData = getOrCreateStory(info.hostUserId);
      }

      // ── 2 · Assemble the narrative so far ─────────────────────────────────
      final buffer = StringBuffer();
      for (final leg in storyData.storyLegs) {
        final choice = leg.userMessage['content'];
        if (choice != null && choice != 'Start Story') {
          buffer.writeln('Your Choice: $choice\n');
        }
        final storyLeg = leg.aiResponse['storyLeg'];
        if (storyLeg != null) buffer.writeln('$storyLeg\n');
      }

      final options = (storyData.storyLegs.isNotEmpty)
          ? (storyData.storyLegs.last.aiResponse['options'] ?? [])
          : [];

      return jsonOk({
        'initialLeg': buffer.toString(),
        'options': options,
        'storyTitle': storyData.storyTitle ?? 'Untitled Story',
      });
    });
  }
}
