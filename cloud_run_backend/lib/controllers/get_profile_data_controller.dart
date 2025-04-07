import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../firestore_client.dart';
import '../utility/custom_exceptions.dart';

class GetProfileDataController {
  Future<Response> handle(Request request, userID) async {
    try {
      // 1) Retrieve userId from request header or from your auth logic
      final userId = userID ?? request.headers['X-User-Id'];
      if (userId == null || userId.isEmpty) {
        return Response.forbidden(
          jsonEncode({"message": "User ID not provided in headers."}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // 2) Query Firestore
      final userData = await getUserData(userId);

      // 3) If userData == null, no doc was found
      if (userData == null) {
        return Response.ok(
          jsonEncode({
            "message": "No user data found. Possibly a new user or doc not created yet.",
            "userId": userId,
            "creationDate": null,
            "lastAccessDate": null,
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // 4) userData is a Map from Firestore. Usually fields like:
      //    { "userId": "...", "creationDate": "...", "lastAccessDate": "..." }
      //    Check for them individually (e.g., userData["creationDate"])
      //    which might be a DateTime or String
      final creationDate = userData["creationDate"]?.toString();
      final lastAccessDate = userData["lastAccessDate"]?.toString();

      // 5) Return JSON response
      return Response.ok(
        jsonEncode({
          "message": "User data retrieved",
          "userId": userId,
          "creationDate": creationDate,
          "lastAccessDate": lastAccessDate,
        }),
        headers: {'Content-Type': 'application/json'},
      );

    } on StoryException catch (e, st) {
      print("Error retrieving user data: ${e.message}\nStackTrace: $st");
      return Response.internalServerError(
        body: jsonEncode({'message': e.message}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, st) {
      print("Error retrieving user data: $e\nStackTrace: $st");
      return Response.internalServerError(
        body: jsonEncode({'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}