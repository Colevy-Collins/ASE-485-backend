import '../models/story.dart';

class PromptGenerator {
 
  String buildGeneralInstructions(StoryData storyData){

    return "You are a DnD Dungeon Master guiding a player through an interactive story. You tell your story until you reach a decision  point from which you need a response from the player. Incorporate each of these dimensions in your story."
              "1) Mark each wrong option with (!) so players can identify incorrect paths."
              "2) Once three wrong choices are made in total, the story concludes in a tragic ending."
              "3) Only present the number of options that are reasonable or relevant at each decision point."
              "4) If the story has ended—tragically or otherwise—no further choices should be processed."
              "5) When the story is in an ended state, display only one option labeled 'The story ends'.";
  }

    String buildFinalInstructions(StoryData storyData){

    return "You are a DnD Dungeon Master guiding a player through an interactive story. You tell your story until you reach a decision  point from which you need a response from the player. Incorporate each of these dimensions in your story."
              "1) This is the final prompt. The story ends here."
              "2) Ensure that the story ends clearly and that the user's final decision is reflected."
              "3) The story should conclude with a final resolution that reflects the user's choices and the consequences of their actions."
              "4) This is the last story leg and there should only be one options which reads 'The story ends'.";

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
        return "Ensure that the story ends clearly and that the user's final decision is reflected.";
      case "Final Resolution":
        return "Conclude the story with a final resolution that reflects the user's choices and the consequences of their actions. This is the last stroy leg and there should only be one options which reads 'The story ends'.";
      default:
        return "Continue the story.";
    }
  }

  // Generates a system prompt for the current section.
  Map<String, dynamic> generateSystemPrompt(StoryData storyData) {
    String sectionPrompt = getSectionPrompt(storyData);
    
return {
  "role": "system",
  "content": 
      "Current Section: ${storyData.currentSection}.\n"
      "$sectionPrompt\n"
      "Genre: ${storyData.dimensions.genre}. Ensure all elements align with this genre.\n"
      "Setting: ${storyData.dimensions.place}. Fully immerse the user in this environment.\n"
      "Time: ${storyData.dimensions.time}.\n"
      "Physical Environment: ${storyData.dimensions.physicalEnvironment}.\n"
      "Cultural & Social Context: ${storyData.dimensions.culturalAndSocialContext}.\n"
      "Technology & Advancement: ${storyData.dimensions.technologyAndAdvancement}.\n"
      "Mood & Atmosphere: ${storyData.dimensions.moodAndAtmosphere}.\n"
      "World Building Details: ${storyData.dimensions.worldBuildingDetails}.\n"
      "Tone: ${storyData.dimensions.tone}.\n"
      "Style: ${storyData.dimensions.style}.\n"
      "Perspective: ${storyData.dimensions.perspective}.\n"
      "Difficulty: ${storyData.dimensions.difficulty}.\n"
      "Protagonist Background: ${storyData.dimensions.protagonistBackground}.\n"
      "Protagonist Abilities: ${storyData.dimensions.protagonistAbilities}.\n"
      "Protagonist Personality: ${storyData.dimensions.protagonistPersonality}.\n"
      "Protagonist Reputation: ${storyData.dimensions.protagonistReputation}.\n"
      "Antagonist Development: ${storyData.dimensions.antagonistDevelopment}.\n"
      "Theme: ${storyData.dimensions.theme}.\n"
      "Encounter Variations: ${storyData.dimensions.encounterVariations}.\n"
      "Moral Dilemmas: ${storyData.dimensions.moralDilemmas}.\n"
      "Story Pacing: ${storyData.dimensions.storyPacing}.\n"
      "Final Objective: ${storyData.dimensions.finalObjective}.\n"
      "Consequences of Failure: ${storyData.dimensions.consequencesOfFailure}.\n"
      "Decision Options: ${storyData.dimensions.decisionOptions}.\n"
      "Puzzle & Final Challenge: ${storyData.dimensions.puzzleAndFinalChallenge}.\n"
      "Fail States: ${storyData.dimensions.failStates}.\n"
      "Each leg should contain at least 200 words.\n"
      "Each leg should have at least ${storyData.optionCount} options for the user to choose from.\n"
};
  }
}
