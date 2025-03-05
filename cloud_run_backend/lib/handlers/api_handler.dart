// lib/handlers/api_handler.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../models/story.dart';
import '../services/story_service.dart';

/// Global map that stores story data for each user (keyed by user id).
Map<String, StoryData> stories = {};

/// Returns a Shelf handler that manages your API endpoints.
Handler createApiHandler() {
  return (Request request) async {
    final userId = request.headers['X-User-Id'];
    if (userId == null) return Response.forbidden('User ID not found.');
    
    // Retrieve or create the story data for this user.
    StoryData storyData = stories.putIfAbsent(userId, () => StoryData());
    final path = request.requestedUri.path;
    
    if (path == '/story' && request.method == 'GET') {
      // Return the conversation history.
      List<Map<String, dynamic>> conversation = [];
      for (var leg in storyData.storyLegs) {
        conversation.add({
          "user": leg.userMessage,
          "ai": leg.aiResponse,
        });
      }
      return Response.ok(jsonEncode(conversation), headers: {'Content-Type': 'application/json'});
      
    } else if (path == '/start_story' && request.method == 'POST') {
      try {
        final payload = await request.readAsString();
        final data = jsonDecode(payload);
        final String decision = (data['decision'] as String?) ?? "Start Story";
        final String genre = (data['genre'] as String?) ?? defaultGenre;
        final String setting = (data['setting'] as String?) ?? defaultSetting;
        final String tone = (data['tone'] as String?) ?? defaultTone;
        final int maxLegs = (data['maxLegs'] as int?) ?? defaultMaxLegs;
        final int optionCount = (data['optionCount'] as int?) ?? defaultOptionCount;
        
        // Initialize the story and generate the first leg.
        initializeStory(storyData, decision, genre, setting, tone, maxLegs, optionCount);
        final Map<String, dynamic> aiJson = await callGeminiAPIWithHistory(storyData, decision);
        appendStoryLeg(storyData, decision, aiJson);
        return Response.ok(
          jsonEncode({
            'aiResponse': aiJson,
            'message': 'Story initialized and first leg generated successfully.'
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        print('Error processing /start_story: $e');
        return Response.internalServerError(body: 'Error processing request: $e');
      }
    } else if (path == '/next_leg' && request.method == 'POST') {
      try {
        final payload = await request.readAsString();
        final data = jsonDecode(payload);
        final String decision = data['decision'] as String;
        if (storyData.genre == null ||
            storyData.setting == null ||
            storyData.tone == null ||
            storyData.maxLegs == null) {
          return Response.internalServerError(body: 'Story options not set.');
        }
        final Map<String, dynamic> aiJson = await callGeminiAPIWithHistory(storyData, decision);
        appendStoryLeg(storyData, decision, aiJson);
        return Response.ok(
          jsonEncode({
            'aiResponse': aiJson,
            'message': 'Next leg generated successfully.'
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        print('Error processing /next_leg: $e');
        return Response.internalServerError(body: 'Error processing request: $e');
      }
    } else {
      return Response.notFound('Route not found');
    }
  };
}
