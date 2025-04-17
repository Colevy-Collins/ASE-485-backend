// controllers/fetch_lobby_state_controller.dart

import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../controllers/create_multiplayer_session_controller.dart'; // holds multiplayerSessions
import '../models/story.dart';

class FetchLobbyStateController {
  /// GET /lobby_state?sessionId=...
  Future<Response> handle(Request request, StoryData _) async {
    final sessionId = request.requestedUri.queryParameters['sessionId'];
    if (sessionId == null) {
      return Response.badRequest(
        body: jsonEncode({'message': 'Missing sessionId'}),
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

    final playersJson = session.players.map(
      (slot, p) => MapEntry(slot.toString(), {
        'userId':      p.userId,
        'displayName': p.displayName,
      }),
    );

    final resp = {
      'sessionId':          session.sessionId,
      'joinCode':           session.joinCode,
      'players':            playersJson,
      'votesResolved':      session.votesResolved,
      'resolvedDimensions': session.resolvedDimensions,
    };

    return Response.ok(
      jsonEncode(resp),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
