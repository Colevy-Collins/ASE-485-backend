import '../models/story.dart';

class PromptGenerator {
 
  String buildGeneralInstructions(StoryData storyData){

    return "Before generating the next story leg, reference previous decision numbers and section summaries. "
        "Craft the next leg to move the story toward its conclusion. "
        "When the current section's leg limit is reached, transition to the next section. "
        "Return your output as a JSON object with exactly these keys: 'storyTitle', 'decisionNumber', 'currentSection', 'storyLeg', and 'options'. "
        "The 'options' array must have exactly ${storyData.optionCount} entries.";
  }

    String buildFinalInstructions(StoryData storyData){

    return "Review the past five story legs and the section summaries to ensure the resolution aligns with previous decisions and narrative points. "
        "Generate the final leg that conclusively ends the story and takes the final user decision into account. "
        "Return your output as a JSON object with exactly these keys: 'storyTitle', 'decisionNumber', 'currentSection', 'storyLeg', and 'options'. "
        "The 'options' array must have exactly 1 entry, and that entry must be 'The story ends'.";
  }

  // Builds a string containing all section summaries.
  String buildSummariesText(StoryData storyData) {
    if (storyData.sectionSummaries.isNotEmpty) {
      return "Summaries of previous sections:\n" +
          storyData.sectionSummaries.join("\n") +
          "\n";
    }
    return "";
  }

  // Returns the section-specific prompt based on the current section.
  String getSectionPrompt(StoryData storyData) {
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

  // Generates a system prompt for the current section.
  Map<String, dynamic> generateSystemPrompt(StoryData storyData) {
    String summariesText = buildSummariesText(storyData);
    String sectionPrompt = getSectionPrompt(storyData);
    
    return {
      "role": "system",
      "content": summariesText +
          "You are an AI generating an interactive story divided into five sections: Exposition, Rising Action, Climax, Falling Action, and Resolution.\n"
          "Current Section: ${storyData.currentSection}.\n"
          "$sectionPrompt\n"
          "Genre: ${storyData.genre ?? 'Adventure'}. Ensure all elements align with this genre.\n"
          "Setting: ${storyData.setting ?? 'Modern'}. Fully immerse the user in this environment.\n"
          "Tone & Style: ${storyData.tone ?? 'Suspenseful'}. Maintain a consistent writing style.\n"
          "Each leg should contain at least 200 words.\n"
          "Each leg should have ${storyData.optionCount} options for the user to choose from.\n"
    };
  }
}
