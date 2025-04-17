import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../models/session_store.dart';

class JoinMultiplayerSessionController {
  Future<Response> handle(Request req) async {
    final data = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final joinCode = data['joinCode'] as String?;
    if (joinCode == null) {
      return Response.badRequest(body: 'Missing joinCode');
    }

    final info = SessionStore.byCode(joinCode);
    if (info == null) {
      return Response.notFound(
        jsonEncode({'message': 'Invalid or expired join code'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    return Response.ok(
      jsonEncode({
        'sessionId' : info.sessionId,
        'hostUserId': info.hostUserId,
        // You could also return info.story.toJson() if you wish
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
