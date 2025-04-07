// controllers/update_last_access_controller.dart

import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../firestore_client.dart';
import '../utility/custom_exceptions.dart';

class UpdateLastAccessController {
  Future<Response> handle(Request request, userID, time) async {
    try {
      // 1) Parse JSON body
      final payload = await request.readAsString();
      final data = payload.isNotEmpty ? jsonDecode(payload) as Map<String, dynamic> : {};

      // 2) userId from header
      final userId = userID ?? request.headers['X-User-Id'];
      if (userId == null || userId.isEmpty) {
        return Response.forbidden(
          jsonEncode({"message": "User ID not provided in headers."}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // 3) For "lastAccessDate", we typically just use server time
      print(DateTime.now()); // For debugging
      final now = time ?? DateTime.now(); // Use the provided now or current time

      // 4) Call Firestore method
      await createOrUpdateUserData(
        userId,// can be null
        lastAccessDate: now,
      );

      // 5) Respond success
      return Response.ok(jsonEncode({
        "message": "User data updated"
      }), headers: {
        'Content-Type': 'application/json',
      });

    } catch (e, st) {
  // If it’s one of your custom StoryExceptions, use its 'message' property.
      if (e is StoryException) {
        print("Error continuing story: ${e.message}\nStackTrace: $st");
        return Response.internalServerError(
          body: jsonEncode({'message': 'Error continuing story: ${e.message}'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Otherwise, it's some other (non-custom) error. 
      print("Error continuing story: $e\nStackTrace: $st");
      return Response.internalServerError(
        body: jsonEncode({'message': 'Error continuing story: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
