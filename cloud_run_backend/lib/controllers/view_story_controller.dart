import 'package:shelf/shelf.dart';

import '../firestore_client.dart';
import '../models/story.dart';
import '../utility/controller_utils.dart';

class ViewStoryController {
  Future<Response> handle(Request request, String storyId) {
    return guarded(() async {
      final raw    = await getSavedStoryById(storyId);
      final data   = StoryData()..updateFromMap(raw);

      // Build narrative text
      final buffer = StringBuffer();
      for (final leg in data.storyLegs) {
        final choice = leg.userMessage['content'];
        if (choice != null && choice != 'Start Story') {
          buffer.writeln('Your Choice: $choice\n');
        }
        final storyLeg = leg.aiResponse['storyLeg'];
        if (storyLeg != null) buffer.writeln('$storyLeg\n');
      }

      final options = (data.storyLegs.isNotEmpty)
          ? (data.storyLegs.last.aiResponse['options'] ?? [])
          : [];

      return jsonOk({
        'initialLeg': buffer.toString(),
        'options'   : options,
        'storyTitle': data.storyTitle ?? 'Untitled Story',
      });
    });
  }
}
