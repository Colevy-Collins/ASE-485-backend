// controllers/resolve_votes_controller.dart

import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../controllers/create_multiplayer_session_controller.dart'; // has global multiplayerSessions
import '../models/multiplayer_session.dart';
import '../models/story_storage.dart';
import '../models/story.dart';

class ResolveVotesController {
  /// POST /resolve_votes
  /// Body: { "sessionId": "..." }
  /// Only the host (slot 1) may call this.
  Future<Response> handle(Request request, StoryData storyData) async {
    final bodyJson = await request.readAsString();
    final body = jsonDecode(bodyJson) as Map<String, dynamic>? ?? {};

    final sessionId = body['sessionId'] as String?;
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

    // Check that caller is host (slot 1)
    final callerId = request.headers['X-User-Id'];
    final hostId = session.players[1]?.userId;
    if (callerId == null || callerId != hostId) {
      return Response.forbidden(
        jsonEncode({'message': 'Only the host can resolve votes'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Compute winners for every dimension
    final resolved = session.calculateResolution();
    session.applyResolved(resolved);

    return Response.ok(
      jsonEncode({'resolvedDimensions': resolved}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
