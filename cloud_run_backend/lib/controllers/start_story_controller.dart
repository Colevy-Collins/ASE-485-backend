// controllers/start_story_controller.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../models/story.dart';
import '../services/story_manager.dart';
import '../services/gemini_service.dart';
import '../utility/custom_exceptions.dart';

class StartStoryController {
  final StoryManager _storyManager = StoryManager();
  final GeminiService _geminiService = GeminiService();

  Future<Response> handle(Request request, StoryData storyData) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final decision = data['decision'] as String;


      // Initialize the story using the StoryManager.
      _storyManager.initializeStory(storyData, data);
      
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
    } catch (e, st) {
      // If it’s one of your custom StoryExceptions, use its 'message' property.
      if (e is StoryException) {
        print("Error starting the story: ${e.message}\nStackTrace: $st");
        return Response.internalServerError(
          body: jsonEncode({'message': 'Error starting the story: ${e.message}'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Otherwise, it's some other (non-custom) error. 
      print("Error starting the story: $e\nStackTrace: $st");
      return Response.internalServerError(
        body: jsonEncode({'message': 'Error starting the story: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
