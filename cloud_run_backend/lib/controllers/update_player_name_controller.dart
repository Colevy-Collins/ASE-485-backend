// controllers/update_player_name_controller.dart

import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../models/story_storage.dart';
import 'create_multiplayer_session_controller.dart'; // to access the global multiplayerSessions map
import '../models/story.dart';

class UpdatePlayerNameController {
  /// Expects a POST with JSON body:
  /// { "newDisplayName": "your new name" }
  Future<Response> handle(Request request, StoryData storyData) async {
    final sessionId = storyData.multiplayerSessionId;
    print(storyData.multiplayerSessionId);
    if (sessionId == null) {
      return Response.badRequest(
        body: jsonEncode({'message': 'Not in a multiplayer session.'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final newDisplayName = data['newDisplayName'] as String?;
    if (newDisplayName == null || newDisplayName.trim().isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'message': 'New display name is required.'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Get the session from the global sessions map.
    final session = multiplayerSessions[sessionId];
    if (session == null) {
      return Response.notFound(
        jsonEncode({'message': 'Multiplayer session not found.'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final userId = request.headers['X-User-Id']!;
    bool updated = false;
    // Iterate through the players to find the matching user
    session.players.forEach((slot, player) {
      if (player.userId == userId) {
        player.displayName = newDisplayName;
        updated = true;
      }
    });

    if (!updated) {
      return Response.notFound(
        jsonEncode({'message': 'Player not found in session.'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Broadcast the updated player list so all clients receive the change.
    session.broadcastPlayerList();

    return Response.ok(
      jsonEncode({'message': 'Display name updated successfully.'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
