import 'package:shelf/shelf.dart';

import '../models/session_store.dart';
import '../utility/controller_utils.dart';

class JoinMultiplayerSessionController {
  Future<Response> handle(Request req) {
    return guarded(() async {
      final body = req.context['jsonBody'] as Map<String, dynamic>? ??
          <String, dynamic>{};

      final joinCode = body['joinCode'] as String?;
      if (joinCode == null) {
        return jsonError(400, {'message': 'Missing joinCode'});
      }

      final info = SessionStore.byCode(joinCode);
      if (info == null) {
        return jsonError(404, {'message': 'Invalid or expired join code'});
      }

      return jsonOk({
        'sessionId' : info.sessionId,
        'hostUserId': info.hostUserId,
      });
    });
  }
}
