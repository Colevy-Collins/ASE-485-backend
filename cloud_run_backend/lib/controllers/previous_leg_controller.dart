import 'package:shelf/shelf.dart';

import '../models/story.dart';
import '../services/story_manager.dart';
import '../utility/controller_utils.dart';

class PreviousLegController {
  final StoryManager _storyManager = StoryManager();

  Future<Response> handle(Request request, StoryData storyData) {
    return guarded(() async {
      _storyManager.removeLastStoryLeg(storyData);

      final lastLeg = storyData.storyLegs.last;
      return jsonOk({
        'aiResponse': lastLeg.aiResponse,
        'message': 'Story rolled back to previous leg.',
      });
    });
  }
}
