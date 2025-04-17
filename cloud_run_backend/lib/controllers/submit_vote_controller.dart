// controllers/submit_vote_controller.dart

import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../models/story_storage.dart';
import '../controllers/create_multiplayer_session_controller.dart'; // for multiplayerSessions
import '../models/story.dart';

class SubmitVoteController {
  /// Expects POST { "vote": { dimensionKey: choice, … } }
  Future<Response> handle(Request request, StoryData storyData) async {
    final sessionId = storyData.multiplayerSessionId;
    if (sessionId == null) {
      return Response.badRequest(
        body: jsonEncode({'message': 'Not in a multiplayer session.'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final session = multiplayerSessions[sessionId];
    if (session == null) {
      return Response.notFound(
        jsonEncode({'message': 'Session not found'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final voteMap = Map<String, String>.from(data['vote'] ?? {});
    final userId = request.headers['X-User-Id']!;

    // Record each dimension vote
    session.submitVote(userId, voteMap);

    // Broadcast updated vote counts (and player list if desired)
    session.broadcastPlayerList();

    return Response.ok(
      jsonEncode({'message': 'Vote registered.'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
