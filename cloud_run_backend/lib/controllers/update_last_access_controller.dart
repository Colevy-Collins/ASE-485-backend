import 'package:shelf/shelf.dart';

import '../firestore_client.dart';
import '../utility/controller_utils.dart';

class UpdateLastAccessController {
  /// [userID] and [time] are optional overrides (useful for tests).
  Future<Response> handle(
    Request request, {
    String?  userID,
    DateTime? time,
  }) {
    return guarded(() async {
      final userId = userID ?? request.userId;
      if (userId == null || userId.isEmpty) {
        return jsonError(403, {'message': 'User ID not provided in headers.'});
      }

      final now = time ?? DateTime.now();
      await createOrUpdateUserData(userId, lastAccessDate: now);

      return jsonOk({'message': 'User data updated'});
    });
  }
}
