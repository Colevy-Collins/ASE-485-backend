import 'package:shelf/shelf.dart';

import '../firestore_client.dart';
import '../utility/controller_utils.dart';

class GetSavedStoriesController {
  Future<Response> handle(Request request, String userId) {
    return guarded(() async {
      final stories = await getSavedStories(userId);
      return jsonOk({'stories': stories});
    });
  }
}
