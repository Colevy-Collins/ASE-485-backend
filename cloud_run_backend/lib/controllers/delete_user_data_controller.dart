import 'package:shelf/shelf.dart';

import '../firestore_client.dart';
import '../utility/controller_utils.dart';

class DeleteUserDataController {
  Future<Response> handle(
    Request request, {
    String? userID,
  }) {
    return guarded(() async {
      final userId = userID ?? request.userId;
      if (userId == null || userId.isEmpty) {
        return jsonError(403, {'message': 'User ID not provided in headers.'});
      }

      await deleteUserData(userId);
      return jsonOk({'message': 'User data deleted.', 'userId': userId});
    });
  }
}
