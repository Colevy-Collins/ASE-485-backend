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

/// Generates a section-specific system prompt based on the current section and includes any cumulative summaries.
Map<String, dynamic> generateSystemPrompt(StoryData storyData) {
  // Concatenate all stored summaries from previous sections.
  String summariesText = "";
  if (storyData.sectionSummaries.isNotEmpty) {
    summariesText = "Summaries of previous sections:\n" + storyData.sectionSummaries.join("\n") + "\n";
  }
  
  String sectionPrompt;
  if (storyData.currentSection == "Resolution") {
    // For Resolution, if this is the final leg, instruct a conclusive ending.
    if (storyData.currentLeg >= (storyData.sectionLegLimits["Resolution"] ?? defaultMaxLegs)) {
      sectionPrompt = "This is the final leg of the Resolution section. Review past user decisions and story legs to create a conclusive ending that wraps up all conflicts. "
                      "Ensure that the story ends clearly and that the user's final decision is reflected. "
                      "Both 'option1' and 'option2' must be 'The story ends'.";
    } else {
      sectionPrompt = "Build up suspense toward the final decision that will end the story.";
    }
  } else {
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
    "content": summariesText +
               "You are an AI generating an interactive story divided into five sections: Exposition, Rising Action, Climax, Falling Action, and Resolution.\n"
               "Current Section: ${storyData.currentSection}.\n"
               "$sectionPrompt\n"
               "Genre: ${storyData.genre ?? defaultGenre}. Ensure all elements align with this genre.\n"
               "Setting: ${storyData.setting ?? defaultSetting}. Fully immerse the user in this environment.\n"
               "Tone & Style: ${storyData.tone ?? defaultTone}. Maintain a consistent writing style.\n"
               "Each leg should contain at least 200 words.\n"
  };
}

/// Initializes a new story with the provided options and adds the system prompt for the first section.
void initializeStory(StoryData storyData, String decision, String genre, String setting, String tone, int maxLegs) {
  storyData.genre = genre.isNotEmpty ? genre : defaultGenre;
  storyData.setting = setting.isNotEmpty ? setting : defaultSetting;
  storyData.tone = tone.isNotEmpty ? tone : defaultTone;
  storyData.maxLegs = maxLegs > 0 ? maxLegs : defaultMaxLegs;
  storyData.currentSection = "Exposition"; // Start with Exposition.
  storyData.currentLeg = 1;                // Reset leg counter for the section.
  storyData.currentSectionStartIndex = 0;    // Mark the starting index for this section.
  
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

/// Summarizes all story legs in the current section to capture major details, decisions, and brief narrative summaries.
/// For each leg, include the leg number, the user's decision, and a short summary of the narrative.
/// The goal is to greatly reduce characters while preserving all important information.
Future<String> summarizeSection(StoryData storyData, GenerativeModel model) async {
  StringBuffer sectionText = StringBuffer();
  // Loop over the current section's legs.
  for (int i = storyData.currentSectionStartIndex; i < storyData.storyLegs.length; i++) {
    StoryLeg leg = storyData.storyLegs[i];
    // Assume leg numbering corresponds to their index + 1.
    int legNumber = i + 1;
    String decision = leg.userMessage['content'] ?? "";
    // For the AI response, extract a brief portion (or ask the summarizer to do that).
    String narrative = leg.aiResponse['content'] ?? "";
    sectionText.writeln("Leg $legNumber:");
    if (decision.trim().isNotEmpty) {
      sectionText.writeln("Decision: $decision");
    }
    sectionText.writeln("Summary: $narrative\n");
  }
  String summarizationPrompt = "Summarize the following section of the story. For each leg, include the leg number, the user's decision, and a brief summary (2-3 sentences) of the narrative. "
      "Keep it concise while preserving all important details:\n" + sectionText.toString();
  
  List<Content> summaryHistory = [Content.text(summarizationPrompt)];
  final summaryChat = model.startChat(history: summaryHistory);
  final summaryResponse = await summaryChat.sendMessage(Content.text(summarizationPrompt));
  final summaryResultText = summaryResponse.text ?? '';
  String summary = summaryResultText.trim();
  
  // Add the new summary to the list of summaries.
  storyData.sectionSummaries.add(summary);
  
  return summary;
}

/// Calls the Gemini API using the built chat history and returns the AI’s JSON response.
/// It checks whether the current section's leg limit has been reached. If so, it calls the summary function,
/// adds the summary to the story data, and then transitions to the next section. In the Resolution section,
/// only one final leg is allowed. Once that final leg is generated, it is stored and returned for all subsequent calls.
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

  int sectionLimit = storyData.sectionLegLimits[storyData.currentSection] ?? defaultMaxLegs;
  
  // Check if we are in the Resolution section.
  if (storyData.currentSection == "Resolution") {
    // If the final resolution leg has already been generated, return it.
    if (storyData.finalResolution != null) {
      return storyData.finalResolution!;
    }
    // Otherwise, if the leg limit is reached, generate the final resolution leg.
    if (storyData.currentLeg >= sectionLimit) {
      final finalInstruction = 
          "Review the past five story legs and the summary of the Resolution section. "
          "Generate the final leg that conclusively ends the story. "
          "Return your output as a JSON object with exactly these keys: "
          "'decisionNumber', 'currentSection', 'storyLeg', 'option1', and 'option2'. "
          "Both 'option1' and 'option2' must be 'The story ends'.";
      final chatFinal = model.startChat(history: history);
      final responseFinal = await chatFinal.sendMessage(Content.text(finalInstruction));
      final resultTextFinal = responseFinal.text ?? '';
      try {
        Map<String, dynamic> finalJsonResponse = jsonDecode(resultTextFinal);
        print("AI Final Response (Parsed JSON): ${jsonEncode(finalJsonResponse)}");
        // Store the final resolution so future calls return the same final leg.
        storyData.finalResolution = finalJsonResponse;
        return finalJsonResponse;
      } catch (e) {
        throw Exception("Failed to parse final AI response as JSON: $e. Response: $resultTextFinal");
      }
    }
  } else {
    // For non-resolution sections, if the leg limit is reached, summarize and transition.
    if (storyData.currentLeg >= sectionLimit) {
      String summary = await summarizeSection(storyData, model);
      // Update the start index for the new section.
      storyData.currentSectionStartIndex = storyData.storyLegs.length;
      
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
      Map<String, dynamic> sectionTransitionMessage = {
        "role": "system",
        "content": "Transitioning to ${storyData.currentSection}. Please continue the story."
      };
      storyData.storyLegs.add(StoryLeg(userMessage: {}, aiResponse: sectionTransitionMessage));
    }
  }

  // For non-final legs, simply increment the leg count.
  if (storyData.currentSection != "Resolution" || storyData.finalResolution == null) {
    storyData.currentLeg++;
  }
  
  // Generate an updated system prompt for the current section (including all stored summaries).
  Map<String, dynamic> systemPrompt = generateSystemPrompt(storyData);
  history.add(Content.text(systemPrompt["content"]));

  final instruction = "Before making the next story leg, reference previous decision numbers, the summaries of all previous sections, and craft the next leg to move the story toward its conclusion. "
      "When the current section's leg limit is reached, transition to the next section. "
      "In the final Resolution leg, ensure that the output is a JSON object with exactly these keys: "
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
