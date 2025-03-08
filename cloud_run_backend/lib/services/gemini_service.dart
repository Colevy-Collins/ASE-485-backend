import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/story.dart';
import 'prompt_generator.dart';
import 'story_manager.dart';
import 'section_manager.dart';

class GeminiService {
  final PromptGenerator promptGenerator;
  final StoryManager storyManager;
  final SectionManager sectionManager;

  GeminiService({PromptGenerator? promptGenerator, StoryManager? storyManager, SectionManager? sectionManager})
      : promptGenerator = promptGenerator ?? PromptGenerator(),
        storyManager = storyManager ?? StoryManager(),
        sectionManager = sectionManager ?? SectionManager();

  // Handles final resolution leg generation in the Resolution section.
  Future<Map<String, dynamic>> handleResolutionSection(StoryData storyData, List<Content> history, GenerativeModel model) async {
    final finalInstruction = promptGenerator.buildFinalInstructions(storyData);
    final chatFinal = model.startChat(history: history);
    final responseFinal = await chatFinal.sendMessage(Content.text(finalInstruction));
    final resultTextFinal = responseFinal.text ?? '';
    Map<String, dynamic> finalJsonResponse = jsonDecode(resultTextFinal);
    print("AI Final Response (Parsed JSON): ${jsonEncode(finalJsonResponse)}");
    storyData.finalResolution = finalJsonResponse;
    return finalJsonResponse;
  }

  // Calls the Gemini API using the built chat history.
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
    
    List<Content> history = storyManager.buildChatHistory(storyData);
    history.add(Content.text("User: $decision"));

    int sectionLimit = storyData.sectionLegLimits[storyData.currentSection] ?? 2; // defaultMaxLegs = 2

    // Resolution section logic.
    if (storyData.currentSection == "Resolution") {
      if (storyData.finalResolution != null) {
        return storyData.finalResolution!;
      } else {
        return await handleResolutionSection(storyData, history, model);
      }
    } else {
      // For non-resolution sections, if leg limit is reached, handle section transition.
      if (storyData.currentLeg >= sectionLimit) {
        await sectionManager.handleSectionTransition(storyData, model, history);
      }
    }

    // Increment the leg counter.
    if (storyData.currentSection != "Resolution" || storyData.finalResolution == null) {
      storyData.currentLeg++;
    }
    
    // Add an updated system prompt to the history.
    Map<String, dynamic> systemPrompt = promptGenerator.generateSystemPrompt(storyData);
    history.add(Content.text(systemPrompt["content"]));

    final instruction = promptGenerator.buildGeneralInstructions(storyData);
    final chat = model.startChat(history: history);
    final response = await chat.sendMessage(Content.text(instruction));
    final resultText = response.text ?? '';
    
    try {
      Map<String, dynamic> jsonResponse = jsonDecode(resultText);
      jsonResponse["decisionNumber"] = storyData.currentLeg;
      jsonResponse["isStoryComplete"] = (storyData.currentLeg >= (storyData.maxLegs ?? 2));
      return jsonResponse;
    } catch (e) {
      throw Exception("Failed to parse AI response as JSON: $e. Response: $resultText");
    }
  }
}
