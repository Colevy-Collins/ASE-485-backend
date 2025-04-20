// controllers/delete_all_stories_controller.dart
import 'package:shelf/shelf.dart';

import '../firestore_client.dart';
import '../utility/controller_utils.dart';   // <‑‑ new

class DeleteAllStoriesController {
  Future<Response> handle(Request req, {String? userIdOverride}) {
    return guarded(() async {               // <‑‑ new
      final userId = userIdOverride ?? req.userId;
      if (userId == null || userId.isEmpty) {
        return jsonError(403, {'message': 'User ID missing'});
      }

      await deleteAllStories(userId);
      return jsonOk({'message': 'All stories deleted for userId $userId'});
    });
  }
}
