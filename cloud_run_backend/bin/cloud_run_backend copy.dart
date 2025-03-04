import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:firebase_admin/firebase_admin.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

// Define a simple linked list node for story legs.
class StoryLeg {
  String storyText;
  String decision; // The decision that led to this leg.
  StoryLeg? next;

  StoryLeg({required this.storyText, required this.decision, this.next});
}

// Global variables to maintain the linked list.
StoryLeg? head;
StoryLeg? tail;

// Initializes the story by creating a head node that contains the rules/settings prompt.
void initializeHead(String decision, String genre, String setting, String tone) {
  // For a new story, there are no recent legs.
  String rulesPrompt = buildGeminiPrompt("", decision, genre, setting, tone);
  head = StoryLeg(storyText: rulesPrompt, decision: "");
  tail = head;
}

// Append a new story leg to the linked list.
void appendStoryLeg(String decision, String newLegText) {
  final newLeg = StoryLeg(storyText: newLegText, decision: decision);
  if (tail == null) {
    head = newLeg;
    tail = newLeg;
  } else {
    tail!.next = newLeg;
    tail = newLeg;
  }
}

// Retrieve the total number of story legs.
int getTotalLegs() {
  int count = 0;
  StoryLeg? current = head;
  while (current != null) {
    count++;
    current = current.next;
  }
  return count;
}

// Retrieve the most recent N story legs from the linked list.
List<StoryLeg> getRecentLegs(int count) {
  List<StoryLeg> legs = [];
  StoryLeg? current = head;
  while (current != null) {
    legs.add(current);
    current = current.next;
  }
  if (legs.length > count) {
    legs = legs.sublist(legs.length - count);
  }
  return legs;
}

// Build a text representation of the most recent N story legs.
String buildRecentLegsText(int count) {
  List<StoryLeg> legs = getRecentLegs(count);
  return legs.map((leg) {
    if (leg.decision.isNotEmpty) {
      return "Leg: ${leg.storyText}\nDecision: ${leg.decision}";
    } else {
      return "Leg: ${leg.storyText}";
    }
  }).join("\n---\n");
}

// Build the Gemini prompt to send both the rules/settings and the most recent five legs.
String buildGeminiPrompt(String recentLegs, String decision, String genre, String setting, String tone) {
  int totalLegs = getTotalLegs();
  String guidelines = "Rules and Guidelines:\n"
      "1. The generated story must be in plain text.\n"
      "2. Maintain narrative continuity and consistency with previous legs.\n"
      "3. Do not introduce contradictions or drastic changes in tone.\n"
      "4. The new leg should logically follow from the previous story legs.\n"
      "5. This story is on leg ${totalLegs + 1} out of 10.\n"
      "6. The genre of this story is $genre.\n"
      "7. The story setting is $setting.\n"
      "8. The story's tone and style are $tone.\n"
      "9. Ensure high quality narrative generation with attention to detail and creative language.\n";
  
  String context;
  if (recentLegs.trim().isEmpty) {
    context = "No previous story legs.";
  } else {
    context = "Recent Story Legs (last 5):\n$recentLegs";
  }
  
  return "Total Story Legs Created: $totalLegs\n\n"
         "$guidelines\n"
         "$context\n\n"
         "New Decision: $decision\n\n"
         "Generate the next part of the story.";
}

// Calls Gemini via google_generative_ai to generate the next story leg.
Future<String> callGeminiAPI(String recentLegs, String decision, String genre, String setting, String tone) async {
  final apiKey = Platform.environment['GEMINI_API_KEY'];
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
  
  final chat = model.startChat(history: []);
  final prompt = buildGeminiPrompt(recentLegs, decision, genre, setting, tone);
  final content = Content.text(prompt);
  
  final response = await chat.sendMessage(content);
  final resultText = response.text ?? '';
  return resultText;
}

void main() async {
  // Do not initialize the story head here; it will be created on the first request.

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
      if (request.method == 'OPTIONS') {
        return Response.ok('');
      }
      try {
        final authHeader = request.headers['Authorization'];
        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return Response.forbidden('Missing authentication token');
        }
        final token = authHeader.substring('Bearer '.length).trim();
        final idToken = await auth.verifyIdToken(token);
        final userId = idToken.claims['sub'];
        print('Authenticated user: $userId');
        return innerHandler(request);
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

  // Handler with two routes: GET /story and POST /next_leg.
  var handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders(headers: corsHeadersConfig))
      .addMiddleware(verifyTokenMiddleware)
      .addHandler((Request request) async {
    final path = request.requestedUri.path;
    
    if (path == '/story' && request.method == 'GET') {
      // GET /story: Return the current story summary.
      StringBuffer buffer = StringBuffer();
      StoryLeg? current = head;
      while (current != null) {
        buffer.writeln("Leg: ${current.storyText}");
        if (current.decision.isNotEmpty) {
          buffer.writeln("Decision: ${current.decision}");
        }
        buffer.writeln("---");
        current = current.next;
      }
      return Response.ok(buffer.toString());
      
    } else if (path == '/next_leg' && request.method == 'POST') {
      // POST /next_leg: Process a client's decision and generate the next story leg.
      try {
        final payload = await request.readAsString();
        final data = jsonDecode(payload);
        // Expect JSON with keys: decision, genre, setting, tone.
        final String decision = data['decision'] as String;
        final String genre = data['genre'] as String;
        final String setting = data['setting'] as String;
        final String tone = data['tone'] as String;
        
        // If starting a new story, initialize the head node with the rules/settings.
        if (head == null) {
          initializeHead(decision, genre, setting, tone);
        }
        
        // Build the recent legs text (includes the head node with the rules).
        String recentLegs = buildRecentLegsText(5);
        // Call Gemini to generate the next leg.
        final String newLegText = await callGeminiAPI(recentLegs, decision, genre, setting, tone);
        // Append the new story leg.
        appendStoryLeg(decision, newLegText);
        return Response.ok(
          jsonEncode({
            'newLeg': newLegText,
            'message': 'Story updated successfully.'
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        print('Error processing POST request: $e');
        return Response.internalServerError(
            body: 'Error processing request: $e');
      }
    } else {
      return Response.notFound('Route not found');
    }
  });

  var server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
  print('Server running on port ${server.port}');
}
