import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../models/story.dart';
import '../services/story_service.dart';
import '../firestore_client.dart';

/// Global map that stores story data for each user (keyed by user id).
Map<String, StoryData> stories = {};

/// Removes any story that has been inactive for 30 minutes or more.
void cleanInactiveStories() {
  final now = DateTime.now();
  stories.removeWhere((userId, storyData) {
    return storyData.lastActivity == null ||
        now.difference(storyData.lastActivity!) >= Duration(minutes: 30);
  });
}

/// Saves the current story data to Firestore.
Future<Response> _handleSaveStory(String userId, StoryData storyData) async {
  try {
    final storyJson = storyData.toJson(); // Ensure StoryData has a toJson() method.
    await saveStory(userId, storyJson);
    return Response.ok(
      jsonEncode({'message': 'Story saved successfully.'}),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    print("Error saving story for user $userId: $e");
    if (e.toString().contains("maximum number of saved stories")) {
      return Response(400,
        body: jsonEncode({'message': 'You have reached the maximum number of saved stories.'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    return Response.internalServerError(
      body: jsonEncode({'message': 'Error saving story: $e'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

/// Returns a Shelf handler that manages your API endpoints.
Handler createApiHandler() {
  return (Request request) async {
    cleanInactiveStories();
    final userId = request.headers['X-User-Id'];
    if (userId == null) return Response.forbidden('User ID not found.');
    final path = request.requestedUri.path;
    
    // For starting a new story, remove any active story for this user.
    if (path == '/start_story' && request.method == 'POST') {
      stories.remove(userId);
    }
    
    StoryData storyData = stories.putIfAbsent(userId, () => StoryData());
    storyData.lastActivity = DateTime.now();
    
    if (path == '/story' && request.method == 'GET') {
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
        print('Error processing /start_story request: $e');
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
        print('Error processing /next_leg request: $e');
        return Response.internalServerError(body: 'Error processing request: $e');
      }
    } else if (path == '/save_story' && request.method == 'POST') {
      return await _handleSaveStory(userId, storyData);
    } else {
      return Response.notFound('Route not found');
    }
  };
}
