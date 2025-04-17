// controllers/create_multiplayer_session_controller.dart

import 'dart:convert';
import 'dart:math';
import 'package:shelf/shelf.dart';
import '../models/story_storage.dart';
import '../models/story.dart';
import '../models/multiplayer_session.dart';
import '../models/player_vote.dart';
import '../models/player_info.dart';
import '../utility/custom_exceptions.dart';
import '../services/story_manager.dart';

// Global in‐memory sessions map.
final Map<String, MultiplayerSession> multiplayerSessions = {};

String generateRandomJoinCode([int length = 6]) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rnd = Random();
  return List.generate(length, (_) => chars[rnd.nextInt(chars.length)])
      .join();
}

class CreateMultiplayerSessionController {
  final StoryManager _storyManager = StoryManager();

  /// Expects:
  /// {
  ///   "decision": String,
  ///   "dimensions": { ... },
  ///   "maxLegs": int,
  ///   "optionCount": int,
  ///   "storyLength": String,
  ///   "vote": { ... },
  ///   "hostName": String?
  /// }
  Future<Response> handle(Request request, StoryData storyData) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      // Solo payload fields:
      final dimensions  = Map<String, dynamic>.from(data['dimensions'] ?? {});

      // Host vote:
      final voteMap = Map<String, String>.from(data['vote'] ?? {});

      final hostName = data['hostName'] as String? ?? "Host";

      // Identify user:
      final userId = request.headers['X-User-Id']!;

      // Tear down old session if any:
      final oldId = storyData.multiplayerSessionId;
      if (oldId != null) {
        final old = multiplayerSessions.remove(oldId);
        if (old != null) {
          final hostInfo = old.players[1];
          if (hostInfo != null && hostInfo.userId != userId) {
            // they were participant: re‐insert without them
            old.removePlayerById(userId);
            multiplayerSessions[oldId] = old;
          }
        }
      }

      // New session IDs:
      final sessionId = '$userId-${DateTime.now().millisecondsSinceEpoch}';
      final joinCode  = generateRandomJoinCode();

      // Reset & link story:
      final newStory = resetStoryForUser(userId);
      newStory.multiplayerSessionId = sessionId;
      print(sessionId);
      print(newStory.multiplayerSessionId);

      // Initialize the solo story first leg/options:
      _storyManager.initializeStory(
        newStory, data
      );

      newStory.dimensions = StoryDimensions.fromJson(
        dimensions.map((k, v) => MapEntry(k, v.toString())),
      );

      // Create session with host in slot #1:
      final session = MultiplayerSession(
        sessionId:  sessionId,
        joinCode:   joinCode,
        storyState: newStory,
        players:    {1: PlayerInfo(userId: userId, displayName: hostName)},
      );

      // Broadcast initial player list:
      session.broadcastPlayerList();


      // Record host vote:
      session.submitVote(userId, voteMap);

      multiplayerSessions[sessionId] = session;

      final resp = {
        'sessionId':  sessionId,
        'joinCode':   joinCode,
        'storyState': newStory.toJson(),
        'players':    session.players.map((i,p)=> MapEntry(i.toString(), p.toJson())),
      };

      return Response.ok(jsonEncode(resp),
          headers: {'Content-Type': 'application/json'});
    }
    on StoryException catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'message': e.message}),
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
