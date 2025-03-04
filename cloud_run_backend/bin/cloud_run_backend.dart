import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:firebase_admin/firebase_admin.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Class representing a single story leg.
class StoryLeg {
  String storyText;
  String decision; // The decision that led to this leg.

  StoryLeg({required this.storyText, required this.decision});
}

/// Class to hold a user's story data.
class StoryData {
  List<StoryLeg> storyLegs = [];
  String? genre;
  String? setting;
  String? tone;
  int? maxLegs;
}

/// Global map that stores story data for each user (keyed by user id).
Map<String, StoryData> stories = {};

/// Initializes a new story for a user by creating the head element (rules/settings prompt)
/// and storing the story options.
void initializeStory(StoryData storyData, String decision, String genre, String setting, String tone, int maxLegs) {
  storyData.genre = genre;
  storyData.setting = setting;
  storyData.tone = tone;
  storyData.maxLegs = maxLegs;
  
  String systemPrompt = "Rules and Guidelines:\n"
      "1. The generated story must be in plain text.\n"
      "2. Maintain narrative continuity and consistency with previous legs.\n"
      "3. Do not introduce contradictions or drastic changes in tone.\n"
      "4. The new leg should logically follow from the previous story legs.\n"
      "5. This story is on leg 1 out of $maxLegs.\n"
      "6. The genre of this story is $genre.\n"
      "7. The story setting is $setting.\n"
      "8. The story's tone and style are $tone.\n"
      "9. Ensure that the new leg gives 2 options to choose from in order to progress the story.\n"
      "10. Ensure high quality narrative generation with attention to detail and creative language.";
  
  storyData.storyLegs.add(StoryLeg(storyText: systemPrompt, decision: ""));
}

/// Appends a new story leg to the user's story.
void appendStoryLeg(StoryData storyData, String decision, String newLegText) {
  storyData.storyLegs.add(StoryLeg(storyText: newLegText, decision: decision));
}

/// Returns the total number of legs for a user's story.
int getTotalLegs(StoryData storyData) {
  return storyData.storyLegs.length;
}

/// Builds a text representation of the most recent [count] story legs.
String buildRecentLegsText(StoryData storyData, int count) {
  List<StoryLeg> legs = List.from(storyData.storyLegs);
  if (legs.length > count) {
    legs = legs.sublist(legs.length - count);
  }
  return legs.map((leg) {
    if (leg.decision.isNotEmpty) {
      return "Leg: ${leg.storyText}\nDecision: ${leg.decision}";
    } else {
      return "Leg: ${leg.storyText}";
    }
  }).join("\n---\n");
}

/// Builds the Gemini prompt including rules, dynamic settings, and the most recent legs.
String buildGeminiPrompt(StoryData storyData, String recentLegs, String decision) {
  int totalLegs = getTotalLegs(storyData);
  int maxLegs = storyData.maxLegs ?? 10;
  String genre = storyData.genre ?? "Unknown";
  String setting = storyData.setting ?? "Unknown";
  String tone = storyData.tone ?? "Unknown";

  String guidelines = "Rules and Guidelines:\n"
      "1. The generated story must be in plain text.\n"
      "2. Maintain narrative continuity and consistency with previous legs.\n"
      "3. Do not introduce contradictions or drastic changes in tone.\n"
      "4. The new leg should logically follow from the previous story legs.\n"
      "5. This story is on leg ${totalLegs + 1} out of $maxLegs.\n"
      "6. The genre of this story is $genre.\n"
      "7. The story setting is $setting.\n"
      "8. The story's tone and style are $tone.\n"
      "9. Ensure that the new leg gives 2 options to choose from in order to progress the story.\n"
      "10. Ensure high quality narrative generation with attention to detail and creative language.\n";
  
  String context = recentLegs.trim().isEmpty
      ? "No previous story legs."
      : "Recent Story Legs (last 5):\n$recentLegs";
  
  return "Total Story Legs Created: $totalLegs\n\n"
         "$guidelines\n"
         "$context\n\n"
         "New Decision: $decision\n\n"
         "Generate the next part of the story.";
}

/// Uses Gemini API built-in chat history to generate the next story leg for a user.
Future<String> callGeminiAPIWithHistory(StoryData storyData, String decision) async {
  final apiKey = 'AIzaSyBeOVu5VnoOyQVMRBNRc4MuIMVhkQaB8_0';
  if (apiKey == null) {
    throw Exception('No GEMINI_API_KEY environment variable');
  }
  
  final model = GenerativeModel(
    model: 'gemini-2.0-flash',
    apiKey: apiKey,
    generationConfig: GenerationConfig(
      temperature: 1,
      topK: 40,
      topP: 0.95,
      maxOutputTokens: 8192,
      responseMimeType: 'text/plain',
    ),
  );
  
  // Build chat history from the user's story.
  List<Content> history = [];
  if (storyData.storyLegs.isNotEmpty) {
    history.add(Content.text(storyData.storyLegs.first.storyText));
  }
  if (storyData.storyLegs.length > 1) {
    for (int i = 1; i < storyData.storyLegs.length; i++) {
      history.add(Content.text("Decision: ${storyData.storyLegs[i].decision}"));
      history.add(Content.text("Leg: ${storyData.storyLegs[i].storyText}"));
    }
  }
  
  final chat = model.startChat(history: history);
  final response = await chat.sendMessage(Content.text("New Decision: $decision"));
  final resultText = response.text ?? '';
  return resultText;
}

void main() async {
  // Do not initialize any story here; stories are created per user on the first request.

  // Initialize Firebase Admin App.
  final app = FirebaseAdmin.instance.initializeApp(
    AppOptions(
      credential: FirebaseAdmin.instance.certFromPath('serviceAccountKey.json'),
    ),
  );
  final auth = app.auth();

  // Middleware to verify Firebase ID tokens.
  Middleware verifyTokenMiddleware = (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') return Response.ok('');
      try {
        final authHeader = request.headers['Authorization'];
        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return Response.forbidden('Missing authentication token');
        }
        final token = authHeader.substring('Bearer '.length).trim();
        final idToken = await auth.verifyIdToken(token);
        final userId = idToken.claims['sub'] as String;
        // Pass the user id in a custom header for downstream handlers.
        return innerHandler(request.change(headers: {'X-User-Id': userId}));
      } catch (e) {
        print('Token verification failed: $e');
        return Response.forbidden('Invalid authentication token');
      }
    };
  };

  // CORS headers configuration.
  final corsHeadersConfig = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Origin, Content-Type, Authorization",
  };

  // Handler with three routes: GET /story, POST /start_story, and POST /next_leg.
  var handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders(headers: corsHeadersConfig))
      .addMiddleware(verifyTokenMiddleware)
      .addHandler((Request request) async {
    // Retrieve the user id from the custom header.
    final userId = request.headers['X-User-Id'];
    if (userId == null) return Response.forbidden('User ID not found.');
    
    // Get or create the user's story data.
    StoryData storyData = stories.putIfAbsent(userId, () => StoryData());
    final path = request.requestedUri.path;
    
    if (path == '/story' && request.method == 'GET') {
      // GET /story: Return a summary of the user's current story.
      StringBuffer buffer = StringBuffer();
      for (var leg in storyData.storyLegs) {
        buffer.writeln("Leg: ${leg.storyText}");
        if (leg.decision.isNotEmpty) {
          buffer.writeln("Decision: ${leg.decision}");
        }
        buffer.writeln("---");
      }
      return Response.ok(buffer.toString());
      
    } else if (path == '/start_story' && request.method == 'POST') {
      // POST /start_story: Initialize a new story and generate the first leg.
      try {
        final payload = await request.readAsString();
        final data = jsonDecode(payload);
        // Expect JSON with keys: decision, genre, setting, tone, and maxLegs.
        final String decision = data['decision'] as String;
        final String genre = data['genre'] as String;
        final String setting = data['setting'] as String;
        final String tone = data['tone'] as String;
        final int maxLegs = data['maxLegs'] as int;
        
        // Initialize the story.
        initializeStory(storyData, decision, genre, setting, tone, maxLegs);
        // Generate the first leg using full options.
        final String newLegText = await callGeminiAPIWithHistory(storyData, decision);
        appendStoryLeg(storyData, decision, newLegText);
        return Response.ok(
          jsonEncode({
            'newLeg': newLegText,
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
        if (storyData.genre == null || storyData.setting == null || storyData.tone == null || storyData.maxLegs == null) {
          return Response.internalServerError(body: 'Story options not set.');
        }
        final String newLegText = await callGeminiAPIWithHistory(storyData, decision);
        appendStoryLeg(storyData, decision, newLegText);
        return Response.ok(
          jsonEncode({
            'newLeg': newLegText,
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
  });

  var server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
  print('Server running on port ${server.port}');
}
