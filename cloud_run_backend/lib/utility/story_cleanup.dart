// story_cleanup.dart
import '../models/story_storage.dart';                 // stories{}                 // StoryData
import '../models/session_store.dart';                  // SessionStore
import '../firestore_client.dart' show deleteLobbyRtdb; // RTDB purge helper

/// Runs periodically (cron / Cloud Scheduler) to sweep out
///   • inactive StoryData objects
///   • their SessionStore entries
///   • their Firebase RTDB lobbies
///
/// A story is “inactive” if `lastActivity` is null OR >30 min ago.
Future<void> cleanInactiveStories() async {
  final now = DateTime.now();
  final toPurge = <String>{}; // collect sessionIds to purge after stories map

  /// 1) Remove expired stories & remember their session IDs.
  stories.removeWhere((userId, story) {
    final inactive = story.lastActivity == null ||
        now.difference(story.lastActivity!) >= const Duration(minutes: 30);

    if (inactive && story.multiplayerSessionId != null) {
      toPurge.add(story.multiplayerSessionId!);
    }
    return inactive; // actually removes it from the `stories` map
  });

  if (toPurge.isEmpty) return;

  /// 2) Purge matching sessions + lobbies.
  for (final sid in toPurge) {
    // in‑memory SessionStore
    SessionStore.removeById(sid);

    // RTDB lobby via unified client helper
    try {
      await deleteLobbyRtdb(sid);
    } catch (e) {
      // log but don’t crash the sweep; maybe the lobby was already gone
      print('Failed to delete lobby $sid: $e');
    }
  }
}