import 'dart:math';
import 'package:shelf/shelf.dart';

import '../models/story_storage.dart';
import '../models/story.dart';
import '../models/session_store.dart';
import '../utility/controller_utils.dart';

String _randomCode([int len = 6]) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rnd = Random();
  return List.generate(len, (_) => chars[rnd.nextInt(chars.length)]).join();
}

class CreateMultiplayerSessionController {
  Future<Response> handle(Request req) {
    return guarded(() async {
      final hostId = req.userId;
      if (hostId == null) {
        return jsonError(403, {'message': 'User ID header missing'});
      }

      // Parsed JSON from middleware
      final body = req.context['jsonBody'] as Map<String, dynamic>? ??
          <String, dynamic>{};

      final isNewGame = body['isNewGame'] == true ||
                        body['isNewGame']?.toString() == 'true';

      var story = getOrCreateStory(hostId);
      if (isNewGame) story = resetStoryForUser(hostId);

      final sessionId = '$hostId-${DateTime.now().millisecondsSinceEpoch}';
      story.multiplayerSessionId = sessionId;
      print(story.multiplayerSessionId);

      String joinCode;
      do {
        joinCode = _randomCode();
      } while (SessionStore.byCode(joinCode) != null);

      SessionStore.createSession(
        hostUserId: hostId,
        sessionId: sessionId,
        joinCode: joinCode,
        story: story,
      );

      return jsonOk({'sessionId': sessionId, 'joinCode': joinCode});
    });
  }
}
