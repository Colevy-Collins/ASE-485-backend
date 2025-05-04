import '../models/story.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'prompt_generator.dart';
// Import our custom exceptions
import '../utility/custom_exceptions.dart';

class StoryManager {
  final PromptGenerator promptGenerator;

  StoryManager({PromptGenerator? promptGenerator})
      : promptGenerator = promptGenerator ?? PromptGenerator();

  /// Initializes a new story using the provided storyData and data (from jsonDecode).
  /// The only change is that any key/value pairs in `data["dimensions"]` are now
  /// directly copied into `storyData.dimensions`.
  void initializeStory(StoryData storyData, Map<String, dynamic> data) {
    // Keep the logic for Story Length, Minimum Number of Options, etc. exactly as is.
    // For example:

    print(data["dimensions"]["Story Length"]);
    storyData.selectStrategyFromString((data["dimensions"]["Story Length"] as String?) ?? "Short");

    // Dynamically copy dimensions from the payload:
    // If data["dimensions"] is not null, treat it as a Map and copy all (key, value) pairs.
    Map<String, dynamic>? dims = data["dimensions"] as Map<String, dynamic>?;
    if (dims != null) {
      dims.forEach((key, value) {
        // In this example, we only store string values.
        // If `value` is not a string, you can skip it or handle it differently.
        if (value is String) {
          if (key == "Difficulty") {
            if(value == "Easy") {
              storyData.difficulty = 4;
            } else if(value == "Normal") {
              storyData.difficulty = 3;
            } else if(value == "Hard") {
              storyData.difficulty = 2;
            } else if(value == "Nightmare") {
              storyData.difficulty = 1;
            } else {
              storyData.difficulty = 4;
            }
          } else if (key != "Minimum Number of Options" && key != "Story Length") {
          storyData.dimensions[key] = value;
          }
        }
      });
    }

    // Keep the rest of your code the same:
    // example, maxLegs, etc.
    print(data["dimensions"]["Minimum Number of Options"]);

    final String? maybeStr = data['dimensions']['Minimum Number of Options'] as String?;
    final int minOptionsSafe = int.tryParse(maybeStr ?? '') ?? 2;
    storyData.optionCount = (minOptionsSafe);
    storyData.currentSection = (data["currentSection"] as String?) ?? "Exposition";
    storyData.currentLeg = (data["currentLeg"] as int?) ?? 0;
    storyData.currentSectionStartIndex = (data["currentSectionStartIndex"] as int?) ?? 0;

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

  // Builds the chat history using the initial prompt and the last 25 legs.
  List<Content> buildChatHistory(StoryData storyData) {
    List<Content> history = [];
    if (storyData.storyLegs.isNotEmpty) {
      // Always include the initial system prompt.
      history.add(Content.text(storyData.storyLegs.first.aiResponse['content']));
    }
    int startIndex = storyData.storyLegs.length > 25 ? storyData.storyLegs.length - 25 : 1;
    for (int i = startIndex; i < storyData.storyLegs.length; i++) {
      var leg = storyData.storyLegs[i];
      history.add(Content.text("User: ${leg.userMessage['content']}"));
      history.add(Content.text("AI: ${leg.aiResponse['content']}"));
    }
    return history;
  }

  /// Removes the last story leg from the story, effectively rolling back one step.
  /// Throws an InvalidStoryOperationException if there is only one leg in the list (the initial prompt).
  void removeLastStoryLeg(StoryData storyData) {
    if (storyData.storyLegs.length <= 2) {
      throw InvalidStoryOperationException(
          "Cannot remove the last story leg because only one leg remains.");
    }
    storyData.storyLegs.removeLast();

    // Update the storyTitle to whatever the new last leg's AI response has.
    final lastLeg = storyData.storyLegs.last;
    if (lastLeg.aiResponse.containsKey("storyTitle")) {
      storyData.storyTitle = lastLeg.aiResponse["storyTitle"];
    }
  }
}
