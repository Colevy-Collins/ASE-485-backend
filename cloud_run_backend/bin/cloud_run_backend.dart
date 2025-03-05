import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:firebase_admin/firebase_admin.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Default user options.
const String defaultGenre = "Adventure";
const String defaultSetting = "Modern";
const String defaultTone = "Suspenseful";
const int defaultMaxLegs = 10;

/// Class representing a single story leg, storing both the user’s message and AI’s response as JSON.
class StoryLeg {
  Map<String, dynamic> userMessage;
  Map<String, dynamic> aiResponse;

  StoryLeg({required this.userMessage, required this.aiResponse});
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

/// Initializes a new story for a user by storing story options and adding a system prompt as the first message.
void initializeStory(StoryData storyData, String decision, String genre, String setting, String tone, int maxLegs) {
  // Use provided values or defaults.
  storyData.genre = genre.isNotEmpty ? genre : defaultGenre;
  storyData.setting = setting.isNotEmpty ? setting : defaultSetting;
  storyData.tone = tone.isNotEmpty ? tone : defaultTone;
  storyData.maxLegs = maxLegs > 0 ? maxLegs : defaultMaxLegs;
  
  // Build a system prompt instructing the AI to respond in JSON.
  Map<String, dynamic> systemPrompt = {
    "role": "system",
    "content": "You are an AI generating an interactive story. Follow these rules:\n"
    "1. Maintain narrative continuity and consistency with previous legs. Ensure events logically flow from one to the next.\n"
    "2. Do not introduce contradictions, sudden tone shifts, or drastic changes in character behavior.\n"
    "3. Genre: ${storyData.genre}. Keep all elements aligned with this genre.\n"
    "4. Setting: ${storyData.setting}. Fully immerse the user in this environment by describing its unique details.\n"
    "5. Tone & Style: ${storyData.tone}. Maintain a consistent writing style that aligns with this tone.\n"
    "6. This is a branching narrative where users make choices that meaningfully affect the story.\n"
    "7. This story has a total of $maxLegs legs. The story must conclude at leg $maxLegs with a satisfying ending.\n"
    "8. Return a JSON object with:\n"
    "   - 'legNumber': The current leg number.\n"
    "   - 'storyLeg': The next part of the story.\n"
    "   - 'option1': The first decision option.\n"
    "   - 'option2': The second decision option.\n"
    "9. Provide rich, immersive world-building with detailed descriptions of surroundings, objects, and sensory experiences.\n"
    "10. Explore character emotions deeply, revealing their thoughts, fears, and motivations.\n"
    "11. Give characters distinct personalities, appearances, and mannerisms to make them feel real.\n"
    "12. Describe character actions vividly, ensuring movements and interactions are engaging.\n"
    "13. Introduce a sense of danger, tension, or urgency at key moments to keep the story exciting.\n"
    "14. If the user is approaching the final leg, begin setting up a logical and meaningful conclusion. \n"
    "15. A story leg should have at least 200 words.\n"
  };

  // Add the system prompt as the first message.
  storyData.storyLegs.add(StoryLeg(userMessage: {}, aiResponse: systemPrompt));
}

/// Appends a new story leg to the user's story.
void appendStoryLeg(StoryData storyData, String decision, Map<String, dynamic> aiResponse) {
  Map<String, dynamic> userMsg = {
    "role": "user",
    "content": decision
  };
  storyData.storyLegs.add(StoryLeg(userMessage: userMsg, aiResponse: aiResponse));
}

/// Builds chat history from the stored JSON communications as a list of Content objects.
List<Content> buildChatHistory(StoryData storyData) {
  List<Content> history = [];

  if (storyData.storyLegs.isNotEmpty) {
    // **Always include the first leg (system message)**
    history.add(Content.text(storyData.storyLegs.first.aiResponse['content']));
  }

  // **Get the last 5 legs if they exist**
  int startIndex = storyData.storyLegs.length > 5 ? storyData.storyLegs.length - 5 : 1;
  for (int i = startIndex; i < storyData.storyLegs.length; i++) {
    var leg = storyData.storyLegs[i];
    history.add(Content.text("AI: ${leg.userMessage['content']}"));
    history.add(Content.text("User: ${leg.aiResponse['content']}"));
  }

  return history;
}


/// Uses Gemini API built-in chat history to generate the next story leg as a JSON object.
Future<Map<String, dynamic>> callGeminiAPIWithHistory(StoryData storyData, String decision) async {
  final apiKey = Platform.environment['GEMINI_API_KEY'] ?? 'AIzaSyBeOVu5VnoOyQVMRBNRc4MuIMVhkQaB8_0';
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
      // Request the response as JSON.
      responseMimeType: 'application/json',
    ),
  );
  
  // Build conversation history from the user's story.
  List<Content> history = buildChatHistory(storyData);
  int currentLeg = storyData.storyLegs.length + 1;
   int maxLegs = storyData.maxLegs ?? 10;
  // Append the new decision.
  history.add(Content.text("User: $decision"));
  
  // Instruct the AI to return its response as a JSON object with keys "option1" and "option2".
  final instruction = "You are on leg $currentLeg out of $maxLegs. Return your response as a JSON object with keys:"   
      "- 'legNumber': The current leg number.\n"
      "   - 'storyLeg': The next part of the story.\n"
      "   - 'option1': The first decision option.\n"
      "   - 'option2': The second decision option.";
  final chat = model.startChat(history: history);
  final response = await chat.sendMessage(Content.text(instruction));
  final resultText = response.text ?? '';
  
  // Parse the AI response as JSON.
  try {
    Map<String, dynamic> jsonResponse = jsonDecode(resultText);
    print("AI Response (Parsed JSON): ${jsonEncode(jsonResponse)}");
    return jsonResponse;
  } catch (e) {
    throw Exception("Failed to parse AI response as JSON: $e. Response: $resultText");
  }
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
      // Initialize a new story and generate the first leg.
      try {
        final payload = await request.readAsString();
        final data = jsonDecode(payload);
        // Use defaults if keys are not provided.
        final String decision = (data['decision'] as String?) ?? "Start Story";
        final String genre = (data['genre'] as String?) ?? defaultGenre;
        final String setting = (data['setting'] as String?) ?? defaultSetting;
        final String tone = (data['tone'] as String?) ?? defaultTone;
        final int maxLegs = (data['maxLegs'] as int?) ?? defaultMaxLegs;
        
        initializeStory(storyData, decision, genre, setting, tone, maxLegs);
        // Generate the first leg using the full options.
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
      // Process the user's decision to generate the next story leg.
      try {
        final payload = await request.readAsString();
        final data = jsonDecode(payload);
        // For subsequent requests, only the decision is expected.
        final String decision = data['decision'] as String;
        if (storyData.genre == null || storyData.setting == null || storyData.tone == null || storyData.maxLegs == null) {
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
  });

  var server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
  print('Server running on port ${server.port}');
}
