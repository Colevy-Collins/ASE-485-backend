import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/story.dart';

/// Default user options.
const String defaultGenre = "Adventure";
const String defaultSetting = "Modern";
const String defaultTone = "Suspenseful";
const int defaultMaxLegs = 2;
const int defaultOptionCount = 2;
const String defaultstoryTitle = "New Story";

/// ------------------ PROMPT GENERATION ------------------

/// Builds a string containing all section summaries from the sectionSummaries array.
String _buildSummariesText(StoryData storyData) {
  if (storyData.sectionSummaries.isNotEmpty) {
    return "Summaries of previous sections:\n" + storyData.sectionSummaries.join("\n") + "\n";
  }
  return "";
}

/// Returns the section-specific prompt based on the current section.
String _getSectionPrompt(StoryData storyData) {
  switch (storyData.currentSection) {
    case "Exposition":
      return "Begin the story by establishing the setting, introducing key characters, and setting up the initial situation.";
    case "Rising Action":
      return "Develop the conflicts and obstacles, raising tension and deepening character relationships.";
    case "Climax":
      return "Reach the story's turning point. Present the major conflict and critical decisions the protagonist must face.";
    case "Falling Action":
      return "Begin resolving the conflicts. Start tying up loose ends and reflecting on the climax.";
    case "Resolution":
      return "This is the final leg of the story. Review past user decisions and story legs to create a conclusive ending that wraps up all conflicts. "
            "Ensure that the story ends clearly and that the user's final decision is reflected. All options must be 'The story ends'.";
    default:
      return "Continue the story.";
  }
}

/// Generates a system prompt for the current section, including any cumulative summaries.
Map<String, dynamic> generateSystemPrompt(StoryData storyData) {
  String summariesText = _buildSummariesText(storyData);
  String sectionPrompt = _getSectionPrompt(storyData);
  
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
               "Each leg should have ${storyData.optionCount} options for the user to choose from.\n"
  };
}

/// ------------------ STORY INITIALIZATION & UPDATE ------------------

/// Initializes a new story with the provided options and adds the initial system prompt.
void initializeStory(StoryData storyData, String decision, String genre, String setting, String tone, int maxLegs, int optionCount) {
  storyData.genre = genre.isNotEmpty ? genre : defaultGenre;
  storyData.setting = setting.isNotEmpty ? setting : defaultSetting;
  storyData.tone = tone.isNotEmpty ? tone : defaultTone;
  storyData.maxLegs = maxLegs > 0 ? maxLegs : defaultMaxLegs;
  storyData.optionCount = optionCount > 0 ? optionCount : defaultOptionCount;
  storyData.currentSection = "Exposition";
  storyData.currentLeg = 0;
  storyData.currentSectionStartIndex = 0;
  
  // Add the initial system prompt (this is stored as a story leg for history).
  Map<String, dynamic> systemPrompt = generateSystemPrompt(storyData);
  storyData.storyLegs.add(StoryLeg(userMessage: {}, aiResponse: systemPrompt));
}

/// Appends a new story leg.
void appendStoryLeg(StoryData storyData, String decision, Map<String, dynamic> aiResponse) {
  Map<String, dynamic> userMsg = {
    "role": "user",
    "content": decision,
  };
  storyData.storyLegs.add(StoryLeg(userMessage: userMsg, aiResponse: aiResponse));
  storyData.storyTitle = aiResponse["storyTitle"];
}

/// ------------------ CHAT HISTORY ------------------

/// Builds the chat history as a list of Content objects using only the first system prompt and last 5 legs.
List<Content> buildChatHistory(StoryData storyData) {
  List<Content> history = [];
  if (storyData.storyLegs.isNotEmpty) {
    // Always include the initial system prompt.
    history.add(Content.text(storyData.storyLegs.first.aiResponse['content']));
  }
  int startIndex = storyData.storyLegs.length > 5 ? storyData.storyLegs.length - 5 : 1;
  for (int i = startIndex; i < storyData.storyLegs.length; i++) {
    var leg = storyData.storyLegs[i];
    history.add(Content.text("User: ${leg.userMessage['content']}"));
    history.add(Content.text("AI: ${leg.aiResponse['content']}"));
  }
  return history;
}

/// ------------------ SECTION TRANSITION & SUMMARIZATION ------------------

/// Updates the section summaries without adding them to the storyLegs array.
/// This function calls summarizeSection and stores the returned summary.
Future<String> _updateSectionSummaries(StoryData storyData, GenerativeModel model) async {
  String summary = await summarizeSection(storyData, model);
  storyData.sectionSummaries.add(summary);
  return summary;
}

/// Handles section transition for non-Resolution sections.
Future<void> _handleSectionTransition(StoryData storyData, GenerativeModel model, List<Content> history) async {
  await _updateSectionSummaries(storyData, model);
  storyData.currentSectionStartIndex = storyData.storyLegs.length;
  
  // Transition to the next section.
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
  // Reset leg counter for the new section.
  storyData.currentLeg = 1;
  // Optionally, add a system transition message (this is not a summary).
  Map<String, dynamic> transitionMsg = {
    "role": "system",
    "content": "Transitioning to ${storyData.currentSection}. Please continue the story."
  };
  storyData.storyLegs.add(StoryLeg(userMessage: {}, aiResponse: transitionMsg));
}

/// Summarizes the current section.
Future<String> summarizeSection(StoryData storyData, GenerativeModel model) async {
  StringBuffer sectionText = StringBuffer();
  for (int i = storyData.currentSectionStartIndex; i < storyData.storyLegs.length; i++) {
    StoryLeg leg = storyData.storyLegs[i];
    int legNumber = i + 1;
    String decision = leg.userMessage['content'] ?? "";
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
  return summaryResponse.text?.trim() ?? "";
}

/// ------------------ GEMINI API CALL ------------------

/// Handles final resolution leg generation in the Resolution section.
Future<Map<String, dynamic>> _handleResolutionSection(StoryData storyData, List<Content> history, GenerativeModel model) async {
  final finalInstruction = 
      "Review the past five story legs and the section summaries to ensure the resolution aligns with previous decisions and narrative points. "
      "Generate the final leg that conclusively ends the story and takes the final user desition into account. "
      "Return your output as a JSON object with exactly these keys: 'storyTitle', decisionNumber', 'currentSection', 'storyLeg', and 'options'. "
      "The 'options' array must have exactly 1 entry, and that entry must be 'The story ends'.";
  final chatFinal = model.startChat(history: history);
  final responseFinal = await chatFinal.sendMessage(Content.text(finalInstruction));
  final resultTextFinal = responseFinal.text ?? '';
  Map<String, dynamic> finalJsonResponse = jsonDecode(resultTextFinal);
  print("AI Final Response (Parsed JSON): ${jsonEncode(finalJsonResponse)}");
  storyData.finalResolution = finalJsonResponse;
  return finalJsonResponse;
}

/// Calls the Gemini API using the built chat history and returns the AI’s JSON response.
/// It handles section transitions and resolution logic.
Future<Map<String, dynamic>> callGeminiAPIWithHistory(StoryData storyData, String decision) async {
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
      responseMimeType: 'application/json',
    ),
  );
  
  List<Content> history = buildChatHistory(storyData);
  history.add(Content.text("User: $decision"));

  int sectionLimit = storyData.sectionLegLimits[storyData.currentSection] ?? defaultMaxLegs;

  // Resolution section logic.
  if (storyData.currentSection == "Resolution") {
    if (storyData.finalResolution != null) {
      return storyData.finalResolution!;
    } else {
      return await _handleResolutionSection(storyData, history, model);
    }
  } else {
    // For non-resolution sections, if leg limit is reached, handle section transition.
    if (storyData.currentLeg >= sectionLimit) {
      await _handleSectionTransition(storyData, model, history);
    }
  }

  // For non-final legs, increment the leg counter.
  if (storyData.currentSection != "Resolution" || storyData.finalResolution == null) {
    storyData.currentLeg++;
  }
  
  // Add an updated system prompt to the history.
  Map<String, dynamic> systemPrompt = generateSystemPrompt(storyData);
  history.add(Content.text(systemPrompt["content"]));

  final instruction = "Before generating the next story leg, reference previous decision numbers and section summaries. "
      "Craft the next leg to move the story toward its conclusion. "
      "When the current section's leg limit is reached, transition to the next section. "
      "Return your output as a JSON object with exactly these keys: 'storyTitle' 'decisionNumber', 'currentSection', 'storyLeg', and 'options'. "
      "The 'options' array must have exactly ${storyData.optionCount} entries.";
  final chat = model.startChat(history: history);
  final response = await chat.sendMessage(Content.text(instruction));
  final resultText = response.text ?? '';
  
  try {
    Map<String, dynamic> jsonResponse = jsonDecode(resultText);
    //print("AI Response (Parsed JSON): ${jsonEncode(jsonResponse)}");
    jsonResponse["decisionNumber"] = storyData.currentLeg;
    jsonResponse["isStoryComplete"] = (storyData.currentLeg >= (storyData.maxLegs ?? defaultMaxLegs));
    return jsonResponse;
  } catch (e) {
    throw Exception("Failed to parse AI response as JSON: $e. Response: $resultText");
  }
}
