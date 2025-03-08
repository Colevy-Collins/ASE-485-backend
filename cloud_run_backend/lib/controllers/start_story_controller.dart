// controllers/start_story_controller.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../models/story.dart';
import '../services/story_manager.dart';
import '../services/gemini_service.dart';

class StartStoryController {
  final StoryManager _storyManager = StoryManager();
  final GeminiService _geminiService = GeminiService();

  Future<Response> handle(Request request, StoryData storyData) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final String decision = data['decision'] ?? "Start Story";
      final String genre = data['genre'] ?? "Adventure";
      final String setting = data['setting'] ?? "Modern";
      final String tone = data['tone'] ?? "Suspenseful";
      final int maxLegs = data['maxLegs'] ?? 2;
      final int optionCount = data['optionCount'] ?? 2;

      // Initialize the story using the StoryManager.
      _storyManager.initializeStory(
          storyData, decision, genre, setting, tone, maxLegs, optionCount);
      
      // Generate the first leg using GeminiService.
      final Map<String, dynamic> aiJson =
          await _geminiService.callGeminiAPIWithHistory(storyData, decision);
      _storyManager.appendStoryLeg(storyData, decision, aiJson);
      
      return Response.ok(
        jsonEncode({
          'aiResponse': aiJson,
          'message': 'Story initialized and first leg generated successfully.'
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('Error processing /start_story request: $e');
      return Response.internalServerError(body: 'Error processing request: $e');
    }
  }
}
