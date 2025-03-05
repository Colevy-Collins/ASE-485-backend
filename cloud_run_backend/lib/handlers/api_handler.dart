import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../models/story.dart';
import '../services/story_service.dart';

/// Global map that stores story data for each user (keyed by user id).
Map<String, StoryData> stories = {};

/// Removes any story that has been inactive for 30 minutes or more.
void cleanInactiveStories() {
  final now = DateTime.now();
  stories.removeWhere((userId, storyData) {
    return storyData.lastActivity == null || now.difference(storyData.lastActivity!) >= Duration(minutes: 30);
  });
}

/// Returns a Shelf handler that manages your API endpoints.
Handler createApiHandler() {
  return (Request request) async {
    // Clean up inactive stories before processing the request.
    cleanInactiveStories();

    final userId = request.headers['X-User-Id'];
    if (userId == null) return Response.forbidden('User ID not found.');
    
    final path = request.requestedUri.path;
    
    // For starting a new story, remove any active story for this user.
    if (path == '/start_story' && request.method == 'POST') {
      stories.remove(userId);
    }
    
    // Retrieve or create the story data for this user.
    StoryData storyData = stories.putIfAbsent(userId, () => StoryData());
    // Update the last activity timestamp.
    storyData.lastActivity = DateTime.now();
    
    if (path == '/story' && request.method == 'GET') {
      // Return the full conversation as a JSON list.
      List<Map<String, dynamic>> conversation = [];
      for (var leg in storyData.storyLegs) {
        conversation.add({
          "user": leg.userMessage,
          "ai": leg.aiResponse,
        });
      }
      return Response.ok(jsonEncode(conversation), headers: {'Content-Type': 'application/json'});
      
    } else if (path == '/start_story' && request.method == 'POST') {
      // POST /start_story: Initialize a new story and generate the first leg.
      try {
        final payload = await request.readAsString();
        final data = jsonDecode(payload);
        // Expect JSON with keys: decision, genre, setting, tone, maxLegs, and optionCount.
        final String decision = (data['decision'] as String?) ?? "Start Story";
        final String genre = (data['genre'] as String?) ?? defaultGenre;
        final String setting = (data['setting'] as String?) ?? defaultSetting;
        final String tone = (data['tone'] as String?) ?? defaultTone;
        final int maxLegs = (data['maxLegs'] as int?) ?? defaultMaxLegs;
        final int optionCount = (data['optionCount'] as int?) ?? defaultOptionCount;
        
        // Initialize the story.
        initializeStory(storyData, decision, genre, setting, tone, maxLegs, optionCount);
        // Generate the first leg using full options.
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
        print('Error processing /start_story request: $e');
        return Response.internalServerError(body: 'Error processing request: $e');
      }
    } else if (path == '/next_leg' && request.method == 'POST') {
      // POST /next_leg: Process the user's decision to generate the next story leg.
      try {
        final payload = await request.readAsString();
        final data = jsonDecode(payload);
        // For subsequent requests, only the decision is expected.
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
        print('Error processing /next_leg request: $e');
        return Response.internalServerError(body: 'Error processing request: $e');
      }
    } else {
      return Response.notFound('Route not found');
    }
  };
}
