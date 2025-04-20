import 'package:shelf/shelf.dart';

import '../firestore_client.dart';
import '../utility/controller_utils.dart';

class DeleteStoryController {
  Future<Response> handle(Request request, String storyId) {
    return guarded(() async {
      await deleteSavedStory(storyId);
      return jsonOk({'message': 'Story deleted successfully'});
    });
  }
}
