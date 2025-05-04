import '../models/story.dart';

class PromptGenerator {
  /// Builds general instructions for the story.
  String buildGeneralInstructions(StoryData storyData){
    return 
      "You are a DnD Dungeon Master guiding a player through an interactive story. "
      "You tell your story until you reach a decision point from which you need a response from the player. "
      "Incorporate each of these dimensions in your story.\n"
      "1) Ensure to occasionally offer the player with wrong options and mark each wrong option with (!) so players can identify incorrect paths.\n"
      "2) Once ${storyData.difficulty} wrong choices are made in total, the story concludes in a tragic ending.\n"
      "3) Only present the number of options that are reasonable or relevant at each decision point.\n"
      "4) If the story has ended—tragically or otherwise—no further choices should be processed.\n"
      "5) When the story is in an ended state, you must display only one option which reads exactly 'The story ends'.\n";

  }

  /// Builds final instructions for the last leg of the story.
  String buildFinalInstructions(StoryData storyData){
    return 
      "You are a DnD Dungeon Master guiding a player through an interactive story. "
      "You tell your story until you reach a decision point from which you need a response from the player. "
      "Incorporate each of these dimensions in your story.\n"
      "1) This is the final prompt. The story ends here.\n"
      "2) Ensure that the story ends clearly and that the user's final decision is reflected.\n"
      "3) The story should conclude with a final resolution that reflects the user's choices and the consequences of their actions.\n"
      "4) This is the last story leg and there should only be one option which reads 'The story ends'.\n";
  }

    String buildFailInstructions(StoryData storyData){
    return 
      "You are a DnD Dungeon Master guiding a player through an interactive story. "
      "You tell your story until you reach a decision point from which you need a response from the player. "
      "Incorporate each of these dimensions in your story.\n"
      "1) This is the final prompt. The story ends here.\n"
      "2) Ensure that the story ends clearly and that the user's final decision is reflected.\n"
      "3) The story should conclude with a final resolution that reflects the user's choices and the consequences of their actions.\n"
      "4) This is the last story leg and there should only be one option which reads 'The story ends'.\n"
      '5) The story has ended tragically. The player has made too many wrong choices.\n';
  }

  /// Returns the section-specific prompt based on the current section.
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
        return "Ensure that the story ends clearly and that the user's final decision is reflected.";
      case "Final Resolution":
        return "Conclude the story with a final resolution that reflects the user's choices and the consequences of their actions. "
               "This is the last story leg and there should only be one option which reads 'The story ends'.";
      default:
        return "Continue the story.";
    }
  }

  /// Helper method that builds a string listing all current dimensions dynamically.
  /// For example, if dimensionMap contains {"Genre": "High Fantasy", "Time": "Ancient era"}, 
  /// it will produce:
  ///
  ///   Genre: High Fantasy
  ///   Time: Ancient era
  ///
  String buildDimensionDetails(StoryData storyData) {
    if (storyData.dimensions.dimensionMap.isEmpty) {
      return "No specific dimensions were provided.\n";
    }
    final buffer = StringBuffer();
    storyData.dimensions.dimensionMap.forEach((key, value) {
      buffer.writeln("$key: $value");
    });
    return buffer.toString();
  }

  /// Generates a system prompt for the current section, incorporating 
  /// dynamic dimension details and user-defined logic.
  Map<String, dynamic> generateSystemPrompt(StoryData storyData) {
    final sectionPrompt = getSectionPrompt(storyData);
    final dimensionDetails = buildDimensionDetails(storyData);

    return {
      "role": "system",
      "content": 
          "Current Section: ${storyData.currentSection}.\n"
          "$sectionPrompt\n\n"
          // Insert dynamic dimension details
          "=== DIMENSION DETAILS ===\n"
          "$dimensionDetails\n"
          "Each leg should contain at least 200 words.\n"
          "Each leg should have at least ${storyData.optionCount} option(s) for the user to choose from.\n"
    };
  }
}
