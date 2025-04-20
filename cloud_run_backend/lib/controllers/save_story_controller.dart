import 'package:shelf/shelf.dart';

import '../firestore_client.dart';
import '../models/session_store.dart';
import '../models/story.dart';
import '../models/story_storage.dart';
import '../utility/controller_utils.dart';

class SaveStoryController {
  /// Saves the *caller’s* story, **or** a copy of the host’s story
  /// when a `sessionId` query parameter is supplied.
  Future<Response> handle(
    Request   request,
    String    callerUserId,
    StoryData callerStory,
  ) {
    return guarded(() async {
      // ── 1 · Decide which StoryData we persist ──────────────────────
      final sessionId   = request.requestedUri.queryParameters['sessionId'];
      StoryData toSave  = callerStory;

      if (sessionId != null) {
        final info = SessionStore.byId(sessionId);
        if (info == null) {
          return jsonError(404, {'message': 'Session not found'});
        }
        toSave = getOrCreateStory(info.hostUserId); // host’s story
      }

      // ── 2 · Persist under the caller’s user‑id ──────────────────────
      await saveStory(callerUserId, toSave.toJson());
      return jsonOk({'message': 'Story saved successfully.'});
    });
  }
}
