// controllers/join_multiplayer_session_controller.dart

import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../models/story_storage.dart';
import '../models/story.dart';
import '../models/multiplayer_session.dart';
import '../models/player_info.dart';
import '../utility/custom_exceptions.dart';
import 'create_multiplayer_session_controller.dart'; // for multiplayerSessions

class JoinMultiplayerSessionController {
  /// Expects:
  /// { "joinCode": String, "displayName": String }
  Future<Response> handle(Request request, StoryData storyData) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final joinCode    = data['joinCode']   as String?;
      final displayName = data['displayName']as String? ?? "Player";

      if (joinCode == null) {
        return Response.badRequest(
          body: jsonEncode({'message':'Missing joinCode'}),
          headers: {'Content-Type':'application/json'},
        );
      }

      // Lookup session:
      final session = multiplayerSessions.values.firstWhere(
        (s) => s.joinCode == joinCode,
        orElse: () => throw StoryException('Session not found'),
      );

      final userId = request.headers['X-User-Id']!;

      // Reset & link story:
      final newStory = resetStoryForUser(userId);
      newStory.multiplayerSessionId = session.sessionId;
      print(session.sessionId);
      print(newStory.multiplayerSessionId);

      // Determine next slot:
      final nextSlot = session.players.isEmpty
          ? 1
          : session.players.keys.reduce((a, b) => a > b ? a : b) + 1;

      // Add player & broadcast:
      session.addPlayer(nextSlot,
          PlayerInfo(userId: userId, displayName: displayName));

      final resp = {
        'sessionId':  session.sessionId,
        'joinCode':   session.joinCode,
        'storyState': session.storyState.toJson(),
        'players':    session.players.map((i,p)=> MapEntry(i.toString(), p.toJson())),
      };

      return Response.ok(jsonEncode(resp),
          headers: {'Content-Type':'application/json'});
    }
    on StoryException catch (e) {
      return Response.notFound(
        jsonEncode({'message': e.message}),
        headers: {'Content-Type':'application/json'},
      );
    }
    catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'message': e.toString()}),
        headers: {'Content-Type':'application/json'},
      );
    }
  }
}
