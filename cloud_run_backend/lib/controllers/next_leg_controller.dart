// controllers/next_leg_controller.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../models/story.dart';
import '../services/story_manager.dart';
import '../services/gemini_service.dart';

class NextLegController {
  final StoryManager _storyManager = StoryManager();
  final GeminiService _geminiService = GeminiService();

  Future<Response> handle(Request request, StoryData storyData) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final String decision = data['decision'] as String;
      
      // Validate that required story options are set.
      bool allValuesNonNull(Map<String, dynamic> map) {
        return map.values.every((value) {
          if (value is Map<String, dynamic>) {
            return allValuesNonNull(value);
          }
          return value != null;
        });
      }

      if (!allValuesNonNull(storyData.dimensions.toJson()) ||
          storyData.optionCount == null) {
        return Response.internalServerError(body: 'Story options not set.');
      }
      
      // Generate the next leg using GeminiService.
      final Map<String, dynamic> aiJson =
          await _geminiService.callGeminiAPIWithHistory(storyData, decision);
      _storyManager.appendStoryLeg(storyData, decision, aiJson);
      
      print(aiJson);
      return Response.ok(
        jsonEncode({
          'aiResponse': aiJson,
          'message': 'Next leg generated successfully.'
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('Error processing /next_leg request: $e');
      return Response.internalServerError(body: 'Error processing request: $e');
    }
  }
}
