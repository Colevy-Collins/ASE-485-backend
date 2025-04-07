// controllers/delete_user_data_controller.dart

import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../firestore_client.dart';
import '../utility/custom_exceptions.dart';

class DeleteUserDataController {
  Future<Response> handle(Request request, userID) async {
    try {
      // 1) userId from header
      final userId = userID ?? request.headers['X-User-Id'];
      if (userId == null || userId.isEmpty) {
        return Response.forbidden(
          jsonEncode({"message": "User ID not provided in headers."}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // 2) Delete doc in Firestore
      await deleteUserData(userId);

      // 3) Return success
      return Response.ok(
        jsonEncode({"message": "User data deleted.", "userId": userId}),
        headers: {'Content-Type': 'application/json'},
      );

    } on StoryException catch (e, st) {
      print("Error deleting user data: ${e.message}\nStackTrace: $st");
      return Response.internalServerError(
        body: jsonEncode({"message": e.message}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, st) {
      print("Error deleting user data: $e\nStackTrace: $st");
      return Response.internalServerError(
        body: jsonEncode({"message": e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
