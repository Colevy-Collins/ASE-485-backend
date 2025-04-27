// lib/controllers/update_theme_controller.dart

import 'package:shelf/shelf.dart';

import '../firestore_client.dart';           // provides updateUserPreferences
import '../utility/controller_utils.dart';  // provides jsonOk/jsonError & guarded

/// Controller for updating a user’s theme preferences.
/// Expects a JSON body with at least one of:
///   {
///     "preferredPalette": "sereneSky",
///     "preferredFont": "Kotta One"
///   }
class UpdateThemeController {
  Future<Response> handle(Request request, { String? userID }) {
    return guarded(() async {
      final uid = userID ?? request.userId;
      if (uid == null || uid.isEmpty) {
        return jsonError(403, {'message': 'User ID not provided in headers.'});
      }

      // JSON body was parsed by middleware into 'jsonBody'
      final body = request.context['jsonBody'] as Map<String, dynamic>? ?? {};
      final palette = body['preferredPalette'] as String?;
      final font    = body['preferredFont']    as String?;

      if (palette == null && font == null) {
        return jsonError(
          400,
          {'message': 'At least one of preferredPalette or preferredFont must be provided.'},
        );
      }

      // Update only the provided fields, leave others untouched
      await updateUserPreferences(
        uid,
        preferredPalette: palette,
        preferredFont:    font,
      );

      return jsonOk({'message': 'Theme preferences updated.'});
    });
  }
}
