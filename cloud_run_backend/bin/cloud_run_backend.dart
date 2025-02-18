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

// Initialize the story with an initial leg.
void initializeStory() {
  head = StoryLeg(storyText: "Once upon a time...", decision: "");
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
    // Include decision if available.
    if (leg.decision.isNotEmpty) {
      return "Leg: ${leg.storyText}\nDecision: ${leg.decision}";
    } else {
      return "Leg: ${leg.storyText}";
    }
  }).join("\n---\n");
}

// Build the prompt to send to Gemini that includes rules, total legs, recent legs, and the new decision.
String buildGeminiPrompt(String recentLegs, String decision) {
  int totalLegs = getTotalLegs();
  // Define rules and guidelines for Gemini.
  String guidelines = "Rules and Guidelines:\n"
      "1. The generated story must be in plain text.\n"
      "2. Maintain narrative continuity and consistency with previous legs.\n"
      "3. Do not introduce contradictions or drastic changes in tone.\n"
      "4. The new leg should logically follow from the previous story legs.\n";
  
  return "Total Story Legs Created: $totalLegs\n\n"
         "$guidelines\n"
         "Recent Story Legs:\n$recentLegs\n\n"
         "New Decision: $decision\n\n"
         "Generate the next part of the story.";
}

// Calls Gemini via google_generative_ai to generate the next story leg.
Future<String> callGeminiAPI(String recentLegs, String decision) async {
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

  // Start a new chat session (without any history).
  final chat = model.startChat(history: []);
  // Build the full prompt with guidelines, recent legs, and the decision.
  final prompt = buildGeminiPrompt(recentLegs, decision);
  final content = Content.text(prompt);

  final response = await chat.sendMessage(content);
  // Await the text value and provide an empty string as fallback if null.
  final resultText = response.text ?? '';
  return resultText;
}

void main() async {
  // Initialize the in-memory story linked list.
  initializeStory();

  // Initialize Firebase Admin App.
  final app = FirebaseAdmin.instance.initializeApp(
    AppOptions(
      credential: FirebaseAdmin.instance.certFromPath('serviceAccountKey.json'),
    ),
  );

  // Get the auth instance.
  final auth = app.auth();

  // Middleware to verify Firebase ID tokens.
  Middleware verifyTokenMiddleware = (Handler innerHandler) {
    return (Request request) async {
      // Allow OPTIONS requests for CORS preflight.
      if (request.method == 'OPTIONS') {
        return Response.ok('');
      }
      try {
        final authHeader = request.headers['Authorization'];
        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return Response.forbidden('Missing authentication token');
        }
        final token = authHeader.substring('Bearer '.length).trim();
        // Verify the token.
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
    "Access-Control-Allow-Origin": "*", // Adjust as needed.
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Origin, Content-Type, Authorization",
  };

  var handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders(headers: corsHeadersConfig))
      .addMiddleware(verifyTokenMiddleware)
      .addHandler((Request request) async {
    // GET: Return the current story as a plain text summary.
    if (request.method == 'GET') {
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
    }
    // POST: Process a client decision and generate the next story leg.
    else if (request.method == 'POST') {
      try {
        final payload = await request.readAsString();
        final data = jsonDecode(payload);
        // Expect JSON with only a "decision" key from the client.
        final String decision = data['decision'] as String;
        // Build a text of the most recent 5 story legs.
        String recentLegs = buildRecentLegsText(5);
        // Call Gemini to generate the next story leg using recent legs and the decision.
        final String newLegText = await callGeminiAPI(recentLegs, decision);
        // Append the new story leg to the linked list.
        appendStoryLeg(decision, newLegText);
        // Respond with the new story leg.
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
      return Response.notFound('Unsupported method');
    }
  });

  var server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
  print('Server running on port ${server.port}');
}
