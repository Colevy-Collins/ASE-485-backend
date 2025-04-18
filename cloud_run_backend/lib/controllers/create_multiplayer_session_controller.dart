import 'dart:convert';
import 'dart:math';
import 'package:shelf/shelf.dart';

import '../models/story_storage.dart';
import '../models/story.dart';
import '../models/session_store.dart';

String _randomCode([int len = 6]) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rnd = Random();
  return List.generate(len, (_) => chars[rnd.nextInt(chars.length)]).join();
}

class CreateMultiplayerSessionController {
  Future<Response> handle(Request req) async {

      final payload = await req.readAsString();
      final data = jsonDecode(payload);
      final String isNewGame = data['isNewGame'] as String;

    final hostId = req.headers['X-User-Id'];
    if (hostId == null) {
      return Response.forbidden('User ID header missing');
    }

    // Create a *fresh* StoryData container for the host
    StoryData story = getOrCreateStory(hostId);
    String sessionId = '$hostId-${DateTime.now().millisecondsSinceEpoch}';
    story.multiplayerSessionId = sessionId; 

    if (isNewGame == 'true'){
      final StoryData story = resetStoryForUser(hostId);   
      String sessionId = '$hostId-${DateTime.now().millisecondsSinceEpoch}';
      story.multiplayerSessionId = sessionId;           // mark ownership
    } 

     // mark session ID

    // Produce a unique join code
    String joinCode;
    do { joinCode = _randomCode(); }
    while (SessionStore.byCode(joinCode) != null);

    SessionStore.createSession(
      hostUserId: hostId,
      sessionId : sessionId,
      joinCode  : joinCode,
      story     : story,
    );

    return Response.ok(
      jsonEncode({'sessionId': sessionId, 'joinCode': joinCode}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
