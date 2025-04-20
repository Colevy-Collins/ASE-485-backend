import 'package:shelf/shelf.dart';

import '../models/story.dart';
import '../services/story_manager.dart';
import '../services/gemini_service.dart';
import '../utility/controller_utils.dart';

class NextLegController {
  final StoryManager  _storyManager  = StoryManager();
  final GeminiService _geminiService = GeminiService();

  Future<Response> handle(Request request, StoryData storyData) {
    return guarded(() async {
      // Body was parsed by middleware ─ grab it from context
      final body = request.context['jsonBody'] as Map<String, dynamic>? ??
          <String, dynamic>{};

      final decision = body['decision'] as String?;
      if (decision == null || decision.trim().isEmpty) {
        return jsonError(400, {'message': 'Missing decision'});
      }

      // Validate that all dimension options are chosen.
      bool _allNonNull(Map<String, dynamic> m) =>
          m.values.every((v) => v is Map<String, dynamic>
              ? _allNonNull(v)
              : v != null);

      if (!_allNonNull(storyData.dimensions.toJson()) ||
          storyData.optionCount == null) {
        return jsonError(400, {'message': 'Story options not set.'});
      }

      // Generate next leg via Gemini
      final aiJson =
          await _geminiService.callGeminiAPIWithHistory(storyData, decision);
      _storyManager.appendStoryLeg(storyData, decision, aiJson);

      return jsonOk({
        'aiResponse': aiJson,
        'message': 'Next leg generated successfully.',
      });
    });
  }
}
