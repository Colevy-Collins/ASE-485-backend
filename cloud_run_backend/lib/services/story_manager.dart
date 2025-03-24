import '../models/story.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'prompt_generator.dart';

class StoryManager {
  final PromptGenerator promptGenerator;

  StoryManager({PromptGenerator? promptGenerator})
      : promptGenerator = promptGenerator ?? PromptGenerator();

  /// Initializes a new story using the provided storyData and data (from jsonDecode).
  /// For each dimension and variable, the value from data is used if available,
  /// otherwise a default value is applied.
  void initializeStory(StoryData storyData, Map<String, dynamic> data) {
    //print(data["storyLength"]);
    storyData.selectStrategyFromString(data["storyLength"]);
    storyData.dimensions = StoryDimensions(
      // Dimension 1 - Setting
      time: (data["dimensions"]?["Setting"]?["1A - Time"] as String?) ??
          "A cyclical age that repeats after catastrophic events",
      place: (data["dimensions"]?["Setting"]?["1B - Place"] as String?) ??
          "A labyrinthine underground city beneath ruins",
      physicalEnvironment:
          (data["dimensions"]?["Setting"]?["1C - Physical Environment"] as String?) ??
              "Gravity-defying landscapes where directions shift unexpectedly",
      culturalAndSocialContext:
          (data["dimensions"]?["Setting"]?["1D - Cultural & Social Context"] as String?) ??
              "A theocratic realm governed by rigid religious dogma",
      technologyAndAdvancement:
          (data["dimensions"]?["Setting"]?["1E - Technology & Level of Advancement"] as String?) ??
              "Hybrid medieval and arcane technologies coexisting",
      moodAndAtmosphere:
          (data["dimensions"]?["Setting"]?["1F - Mood & Atmosphere"] as String?) ??
              "Chaotic and unpredictable, shifting from calm to crisis",
      worldBuildingDetails:
          (data["dimensions"]?["Setting"]?["1G - World-Building Details"] as String?) ??
              "Forbidden zones that alter reality in bizarre ways",

      // Dimension 2 - Genre
      genre: (data["dimensions"]?["Genre"] as String?) ?? "Adventure",

      // Dimension 3 - Tone
      tone: (data["dimensions"]?["Tone"] as String?) ?? "Suspenseful",

      // Dimension 4 - Style
      style: (data["dimensions"]?["Style"] as String?) ??
          "Poetic, dreamlike prose focusing on atmosphere",

      // Dimension 5 - Perspective
      perspective: (data["dimensions"]?["Perspective"] as String?) ??
          "Unreliable narrator with possible hidden motives",

      // Dimension 6 - Difficulty (Encounters & Challenges)
      difficulty: (data["dimensions"]?["Difficulty (Encounters & Challenges)"] as String?) ??
          "Encounters that can be bypassed via stealth or diplomacy",

      // Dimension 7 - Protagonist Customization
      protagonistBackground: (data["dimensions"]?["Protagonist Customization"]?["Background"] as String?) ??
          "Summoned outsider from a parallel reality",
      protagonistAbilities: (data["dimensions"]?["Protagonist Customization"]?["Abilities"] as String?) ??
          "Psionic talents for telepathy or telekinesis",
      protagonistPersonality: (data["dimensions"]?["Protagonist Customization"]?["Personality"] as String?) ??
          "Quiet observer with an iron will",
      protagonistReputation: (data["dimensions"]?["Protagonist Customization"]?["Reputation"] as String?) ??
          "Enigmatic wanderer whose deeds are whispered about",

      // Dimension 8 - Antagonist Development
      antagonistDevelopment: (data["dimensions"]?["Antagonist Development"] as String?) ??
          "A shadowy mastermind manipulating events behind the scenes",

      // Dimension 9 - Theme
      theme: (data["dimensions"]?["Theme"] as String?) ?? "Fate versus free will",

      // Dimension 10 - Encounter Variations
      encounterVariations: (data["dimensions"]?["Encounter Variations"] as String?) ??
          "Spiritual or psychic showdowns in dreamlike realms",

      // Dimension 11 - Moral Dilemmas
      moralDilemmas: (data["dimensions"]?["Moral Dilemmas"] as String?) ??
          "Using forbidden power at the risk of corruption",

      // Dimension 12 - Story Pacing
      storyPacing: (data["dimensions"]?["Story Pacing"] as String?) ??
          "Constant tension with short-lived calm moments",

      // Dimension 13 - Final Objective
      finalObjective: (data["dimensions"]?["Final Objective"] as String?) ??
          "Restoring balance to an ailing ecosystem or realm",

      // Dimension 14 - Consequences of Failure
      consequencesOfFailure: (data["dimensions"]?["Consequences of Failure"] as String?) ??
          "Permanent corruption twisting the hero or the land",

      // Dimension 15 - Decision Options
      decisionOptions: (data["dimensions"]?["Decision Options"] as String?) ??
          "Subtle shifts in outcomes based on moral or ethical stances",

      // Dimension 16 - Puzzle & Final Challenge
      puzzleAndFinalChallenge:
          (data["dimensions"]?["Puzzle & Final Challenge"] as String?) ??
              "A branching-path decision maze where each turn offers multiple routes. Choosing a consistent path with correct logic yields the good ending, but straying into dead-ends accumulates errors, concluding in a fail ending.",

      // Dimension 17 - Fail States
      failStates: (data["dimensions"]?["Fail States"] as String?) ??
          "Escalating corruption that twists the protagonist’s motives, culminating in a self-inflicted collapse or villainous turn",
    );

    // Set additional story-level properties from data, or use defaults.
    storyData.optionCount = (data["optionCount"] as int?) ?? 2;
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
  /// Throws a StateError if there is only one leg in the list (the initial prompt).
  void removeLastStoryLeg(StoryData storyData) {
    // If there's only 1 leg, it's presumably the initial/system prompt.
    if (storyData.storyLegs.length <= 2) {
      throw StateError("Cannot remove the last story leg because only one leg remains.");
    }

    // Remove the most recent story leg.
    storyData.storyLegs.removeLast();

    // Update the storyTitle to whatever the new last leg's AI response has.
    final lastLeg = storyData.storyLegs.last;
    if (lastLeg.aiResponse.containsKey("storyTitle")) {
      storyData.storyTitle = lastLeg.aiResponse["storyTitle"];
    }
  }

}
