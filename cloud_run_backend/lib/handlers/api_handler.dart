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
      // Build the complete narrative by concatenating all AI responses.
      String initialLeg = '';
      print(storyData.storyLegs[1].aiResponse['storyLeg']);
      for (var leg in storyData.storyLegs) {
        if (leg.aiResponse['storyLeg'] != null) {
          initialLeg += leg.aiResponse['storyLeg'] + '\n\n';
        }
      }
      print(initialLeg);
      // Get the options from the last leg (if available).
      List options = [];
      if (storyData.storyLegs.isNotEmpty &&
          storyData.storyLegs.last.aiResponse['options'] != null) {
        options = storyData.storyLegs.last.aiResponse['options'];
      }
      // Use the stored story title; if not set, fall back to "Untitled Story".
      String storyTitle = storyData.storyTitle ?? "Untitled Story";

      return Response.ok(
        jsonEncode({
          'initialLeg': initialLeg,
          'options': options,
          'storyTitle': storyTitle,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
    else if (path == '/start_story' && request.method == 'POST') {
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
        print(aiJson['storyTitle']);
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
    } else if (path == '/saved_stories' && request.method == 'GET') {
      try {
        final savedStories = await getSavedStories(userId);
        return Response.ok(
          jsonEncode({'stories': savedStories}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        print("Error retrieving saved stories for user $userId: $e");
        return Response.internalServerError(
          body: jsonEncode({'message': 'Error retrieving saved stories: $e'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } else {
      return Response.notFound('Route not found');
    }
  };
}
