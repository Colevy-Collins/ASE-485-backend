// models/multiplayer_session.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../models/story.dart';
import 'player_vote.dart';
import 'player_info.dart';

class MultiplayerSession {
  final String sessionId;
  final String joinCode;
  final StoryData storyState;               // contains host defaults
  final Map<int, PlayerInfo> players;       // slot → PlayerInfo

  // Per‑player vote maps and aggregated dimension counts
  final Map<String, PlayerVote> playerVotes = {};
  final Map<String, Map<String, int>> dimensionVotes = {};

  // === NEW state ===
  bool votesResolved = false;                       // has host resolved?
  Map<String, String> resolvedDimensions = {};      // dimKey → final value
  // =================

  final _voteStreamController = StreamController<Map<String, int>>.broadcast();
  final _playerListController =
      StreamController<Map<int, PlayerInfo>>.broadcast();

  MultiplayerSession({
    required this.sessionId,
    required this.joinCode,
    required this.storyState,
    required this.players,
  });

  Stream<Map<String, int>> get voteUpdates => _voteStreamController.stream;
  Stream<Map<int, PlayerInfo>> get playerListUpdates =>
      _playerListController.stream;

  /// Replace or add an entire vote‑map for one player.
  void submitVote(String playerId, Map<String, String> voteMap) {
    // undo old votes (if any)
    final prevJson = playerVotes[playerId]?.chosenOption;
    if (prevJson != null) {
      final prev = Map<String, String>.from(jsonDecode(prevJson));
      prev.forEach((dim, opt) {
        final counts = dimensionVotes[dim];
        if (counts != null) {
          final c = counts[opt] ?? 0;
          if (c <= 1) counts.remove(opt);
          else counts[opt] = c - 1;
        }
      });
    }

    // store new vote map
    playerVotes[playerId] =
        PlayerVote(playerId: playerId, chosenOption: jsonEncode(voteMap));

    // apply new counts
    voteMap.forEach((dim, opt) {
      dimensionVotes.putIfAbsent(dim, () => {});
      final counts = dimensionVotes[dim]!;
      counts.update(opt, (v) => v + 1, ifAbsent: () => 1);
    });

    // broadcast aggregate (optional)
    _voteStreamController.add(dimensionVotes.map(
        (d, m) => MapEntry(d, m.values.fold(0, (a, b) => a + b))));
  }

  /// Compute a winner for **every** dimension (host default if 0 votes).
  Map<String, String> calculateResolution() {
    final rnd = Random();
    final result = <String, String>{};

    final hostDims =
        Map<String, dynamic>.from(storyState.toJson()['dimensions'] ?? {})
            .map((k, v) => MapEntry(k, v.toString()));

    hostDims.forEach((dim, hostDefault) {
      final counts = dimensionVotes[dim];
      if (counts == null || counts.isEmpty) {
        result[dim] = hostDefault;                   // nobody voted
      } else if (counts.length == 1) {
        result[dim] = counts.keys.first;             // single choice
      } else {
        final max = counts.values.reduce(maxInt);
        final winners =
            counts.entries.where((e) => e.value == max).map((e) => e.key).toList();
        result[dim] = winners[rnd.nextInt(winners.length)]; // tie‑break
      }
    });

    return result;
  }

  /// Persist final winners into session & story; mark as resolved.
  void applyResolved(Map<String, String> resolved) {
    resolvedDimensions = resolved;
    votesResolved = true;
    storyState.dimensions = StoryDimensions.fromJson(resolved);
  }

  void broadcastPlayerList() => _playerListController.add(Map.from(players));

  void addPlayer(int slot, PlayerInfo info) {
    players[slot] = info;
    broadcastPlayerList();
  }

  void removePlayerById(String userId) {
    players.removeWhere((_, info) => info.userId == userId);
    broadcastPlayerList();
  }

  void dispose() {
    _voteStreamController.close();
    _playerListController.close();
  }

  // helper
  int maxInt(int a, int b) => a > b ? a : b;
}
