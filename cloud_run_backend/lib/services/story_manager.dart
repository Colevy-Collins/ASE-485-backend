import '../models/story.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'prompt_generator.dart';

class StoryManager {
  final PromptGenerator promptGenerator;

  StoryManager({PromptGenerator? promptGenerator})
      : promptGenerator = promptGenerator ?? PromptGenerator();

  // Initializes a new story with provided options.
  void initializeStory(StoryData storyData, String decision, String genre,
      String setting, String tone, int maxLegs, int optionCount) {
    storyData.genre = genre.isNotEmpty ? genre : "Adventure";
    storyData.setting = setting.isNotEmpty ? setting : "Modern";
    storyData.tone = tone.isNotEmpty ? tone : "Suspenseful";
    storyData.maxLegs = maxLegs > 0 ? maxLegs : 2;
    storyData.optionCount = optionCount > 0 ? optionCount : 2;
    storyData.currentSection = "Exposition";
    storyData.currentLeg = 0;
    storyData.currentSectionStartIndex = 0;

    // Add the initial system prompt as the first story leg.
    Map<String, dynamic> systemPrompt = promptGenerator.generateSystemPrompt(storyData);
    storyData.storyLegs.add(StoryLeg(userMessage: {}, aiResponse: systemPrompt));
  }

  // Appends a new story leg.
  void appendStoryLeg(StoryData storyData, String decision, Map<String, dynamic> aiResponse) {
    Map<String, dynamic> userMsg = {
      "role": "user",
      "content": decision,
    };
    storyData.storyLegs.add(StoryLeg(userMessage: userMsg, aiResponse: aiResponse));
    storyData.storyTitle = aiResponse["storyTitle"];
  }

  // Builds the chat history using the initial prompt and the last five legs.
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
}
