import 'package:shelf/shelf.dart';

import '../firestore_client.dart';
import '../utility/controller_utils.dart';

class GetProfileDataController {
  Future<Response> handle(
    Request request, {
    String? userID,
  }) {
    return guarded(() async {
      final userId = userID ?? request.userId;
      if (userId == null || userId.isEmpty) {
        return jsonError(403, {'message': 'User ID not provided in headers.'});
      }

      final userData = await getUserData(userId);

      if (userData == null) {
        return jsonOk({
          'message':
              'No user data found. Possibly a new user or doc not created yet.',
          'userId': userId,
          'creationDate': null,
          'lastAccessDate': null,
        });
      }

      return jsonOk({
        'message': 'User data retrieved',
        'userId': userId,
        'creationDate': userData['creationDate']?.toString(),
        'lastAccessDate': userData['lastAccessDate']?.toString(),
      });
    });
  }
}
