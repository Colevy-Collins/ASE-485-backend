// lib/services/story_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/story.dart';

/// Default user options.
const String defaultGenre = "Adventure";
const String defaultSetting = "Modern";
const String defaultTone = "Suspenseful";
const int defaultMaxLegs = 2;

/// Generates a section-specific system prompt based on the current section and leg.
/// In the Resolution section, if the current leg is the final leg, the prompt instructs the AI to end the story.
Map<String, dynamic> generateSystemPrompt(StoryData storyData) {
  String sectionPrompt;
  if (storyData.currentSection == "Resolution") {
    // If we're in the Resolution section and on the final leg:
    if (storyData.currentLeg >= (storyData.sectionLegLimits["Resolution"] ?? defaultMaxLegs)) {
      sectionPrompt = "This is the final leg of the Resolution section. Review the past five story legs and the most recent user decisions to craft a satisfying and logical conclusion. "
                "The ending must be directly influenced by the choices the user has made throughout the story. "
                "- Reference all avalible materail to ensure continuity. "
                "- End in a way that feels natural and earned based on the user's decisions. "
                "Both 'option1' and 'option2' must be set to 'The story ends'.";
    } else {
      sectionPrompt = "Build suspense and tension, leading the narrative toward the final decision that will conclusively end the story.";
    }
  } else {
    // For all other sections, use the standard prompt
    switch (storyData.currentSection) {
      case "Exposition":
        sectionPrompt = "Begin the story by establishing the setting, introducing key characters, and setting up the initial situation.";
        break;
      case "Rising Action":
        sectionPrompt = "Develop the conflicts and obstacles, raising tension and deepening character relationships.";
        break;
      case "Climax":
        sectionPrompt = "Reach the story's turning point. Present the major conflict and critical decisions the protagonist must face.";
        break;
      case "Falling Action":
        sectionPrompt = "Begin resolving the conflicts. Start tying up loose ends and reflecting on the climax.";
        break;
      default:
        sectionPrompt = "Continue the story.";
        break;
    }
  }

  return {
    "role": "system",
    "content": "You are an AI generating an interactive story divided into five sections: Exposition, Rising Action, Climax, Falling Action, and Resolution.\n"
               "Current Section: ${storyData.currentSection}.\n"
               "$sectionPrompt\n"
               "Genre: ${storyData.genre ?? defaultGenre}. Ensure all elements align with this genre.\n"
               "Setting: ${storyData.setting ?? defaultSetting}. Fully immerse the user in this environment.\n"
               "Tone & Style: ${storyData.tone ?? defaultTone}. Maintain a consistent writing style.\n"
               //"Each leg should contain at least 200 words.\n"
  };
}

/// Initializes a new story with the provided options and adds the system prompt for the first section.
void initializeStory(StoryData storyData, String decision, String genre, String setting, String tone, int maxLegs) {
  storyData.genre = genre.isNotEmpty ? genre : defaultGenre;
  storyData.setting = setting.isNotEmpty ? setting : defaultSetting;
  storyData.tone = tone.isNotEmpty ? tone : defaultTone;
  storyData.maxLegs = maxLegs > 0 ? maxLegs : defaultMaxLegs;
  storyData.currentSection = "Exposition"; // Start with Exposition.
  storyData.currentLeg = 1; // Reset leg counter for the section.
  
  // Add the initial system prompt.
  Map<String, dynamic> systemPrompt = generateSystemPrompt(storyData);
  storyData.storyLegs.add(StoryLeg(userMessage: {}, aiResponse: systemPrompt));
}

/// Appends a new story leg to the user's story.
void appendStoryLeg(StoryData storyData, String decision, Map<String, dynamic> aiResponse) {
  Map<String, dynamic> userMsg = {
    "role": "user",
    "content": decision,
  };
  storyData.storyLegs.add(StoryLeg(userMessage: userMsg, aiResponse: aiResponse));
}

/// Builds the chat history from the story legs as a list of Content objects.
List<Content> buildChatHistory(StoryData storyData) {
  List<Content> history = [];
  if (storyData.storyLegs.isNotEmpty) {
    history.add(Content.text(storyData.storyLegs.first.aiResponse['content']));
  }
  int startIndex = storyData.storyLegs.length > 5 ? storyData.storyLegs.length - 5 : 1;
  for (int i = startIndex; i < storyData.storyLegs.length; i++) {
    var leg = storyData.storyLegs[i];
    history.add(Content.text("AI: ${leg.userMessage['content']}"));
    history.add(Content.text("User: ${leg.aiResponse['content']}"));
  }
  return history;
}

/// Calls the Gemini API using the built chat history and returns the AI’s JSON response.
/// It checks if the current section's leg limit has been reached and handles the Resolution section specially.
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
      responseMimeType: 'application/json',
    ),
  );
  
  List<Content> history = buildChatHistory(storyData);
  history.add(Content.text("User: $decision"));

  // Check if the current section's leg limit has been reached.
  int sectionLimit = storyData.sectionLegLimits[storyData.currentSection] ?? defaultMaxLegs;
  if (storyData.currentLeg >= sectionLimit) {
    if (storyData.currentSection == "Resolution") {
      // Final resolution leg: generate a concluding prompt.
      final finalInstruction = "You are in the final leg of the Resolution section. Conclude the story definitively. "
          "Return your output as a JSON object with exactly the following keys: "
          "'decisionNumber' (the current decision number), "
          "'currentSection' (the current section), "
          "'storyLeg' (the final narrative content), "
          "'option1' and 'option2' (both must be 'The story ends').";
      final chatFinal = model.startChat(history: history);
      final responseFinal = await chatFinal.sendMessage(Content.text(finalInstruction));
      final resultTextFinal = responseFinal.text ?? '';
      try {
        Map<String, dynamic> finalJsonResponse = jsonDecode(resultTextFinal);
        print("AI Final Response (Parsed JSON): ${jsonEncode(finalJsonResponse)}");
        return finalJsonResponse;
      } catch (e) {
        throw Exception("Failed to parse final AI response as JSON: $e. Response: $resultTextFinal");
      }
    } else {
      // Transition to the next section for non-final sections.
      switch (storyData.currentSection) {
        case "Exposition":
          storyData.currentSection = "Rising Action";
          break;
        case "Rising Action":
          storyData.currentSection = "Climax";
          break;
        case "Climax":
          storyData.currentSection = "Falling Action";
          break;
        case "Falling Action":
          storyData.currentSection = "Resolution";
          break;
      }
      // Reset the leg counter for the new section.
      storyData.currentLeg = 1;
      // Add a system message indicating a section transition.
      Map<String, dynamic> sectionTransitionMessage = {
        "role": "system",
        "content": "Transitioning to ${storyData.currentSection}. Please continue the story."
      };
      storyData.storyLegs.add(StoryLeg(userMessage: {}, aiResponse: sectionTransitionMessage));
    }
  } else {
    // Otherwise, simply increment the leg count.
    storyData.currentLeg++;
  }
  
  // Generate an updated system prompt for the current section (including Resolution, if not final).
  Map<String, dynamic> systemPrompt = generateSystemPrompt(storyData);
  history.add(Content.text(systemPrompt["content"]));

  final instruction = "Before making the next story leg, reference previous decisions to ensure continuity based on users decisions."
      "When the current section's leg limit is reached, transition to the next section. In the final Resolution leg, ensure that the output is a JSON object with exactly these keys: "
      "'decisionNumber', 'currentSection', 'storyLeg', 'option1', and 'option2' (both options must be 'The story ends').";
  final chat = model.startChat(history: history);
  final response = await chat.sendMessage(Content.text(instruction));
  final resultText = response.text ?? '';
  
  try {
    Map<String, dynamic> jsonResponse = jsonDecode(resultText);
    print("AI Response (Parsed JSON): ${jsonEncode(jsonResponse)}");
    return jsonResponse;
  } catch (e) {
    throw Exception("Failed to parse AI response as JSON: $e. Response: $resultText");
  }
}
