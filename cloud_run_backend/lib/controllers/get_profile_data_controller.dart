// lib/controllers/get_profile_data_controller.dart

import 'package:shelf/shelf.dart';
import '../firestore_client.dart';
import '../utility/controller_utils.dart';

class GetProfileDataController {
  Future<Response> handle(Request request, { String? userID }) {
    return guarded(() async {
      final userId = userID ?? request.userId;
      if (userId == null || userId.isEmpty) {
        return jsonError(403, {'message': 'User ID not provided in headers.'});
      }

      final userData = await getUserData(userId);
      if (userData == null) {
        return jsonOk({
          'message':       'No user data found',
          'userId':        userId,
          'creationDate':  null,
          'lastAccessDate':null,
          'preferredPalette': null,
          'preferredFont':    null,
        });
      }

      return jsonOk({
        'message':          'User data retrieved',
        'userId':           userId,
        'creationDate':     userData['creationDate']?.toString(),
        'lastAccessDate':   userData['lastAccessDate']?.toString(),
        'preferredPalette': userData['preferredPalette'] as String?,
        'preferredFont':    userData['preferredFont']    as String?,
      });
    });
  }
}
