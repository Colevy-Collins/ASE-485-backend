import 'dart:convert';
import 'package:shelf/shelf.dart';

import '../models/story.dart';
import '../services/gemini_service.dart';
import '../services/story_manager.dart';
import '../utility/controller_utils.dart';

class StartStoryController {
  final StoryManager  _storyManager  = StoryManager();
  final GeminiService _geminiService = GeminiService();

Future<Response> handle(Request request, StoryData storyData) {
  return guarded(() async {
    // pull the already-parsed JSON out of context:
    final body =
      request.context['jsonBody'] as Map<String, dynamic>? ??
      (throw ArgumentError('Request body missing'));

    final decision = body['decision'] as String?;
    if (decision == null || decision.trim().isEmpty) {
      return jsonError(400, {'message': 'Missing decision'});
    }

    _storyManager.initializeStory(storyData, body);
    final aiJson = await _geminiService.callGeminiAPIWithHistory(
      storyData,
      decision,
    );
    _storyManager.appendStoryLeg(storyData, decision, aiJson);

    return jsonOk({
      'aiResponse': aiJson,
      'message': 'Story initialized and first leg generated successfully.',
    });
  });
}

}
