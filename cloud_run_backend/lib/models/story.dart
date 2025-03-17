// lib/models/story.dart

/// Represents a single story leg, containing the user's message and the AI's response.
class StoryLeg {
  Map<String, dynamic> userMessage;
  Map<String, dynamic> aiResponse;

  StoryLeg({required this.userMessage, required this.aiResponse});

  /// Factory constructor that creates a StoryLeg from a JSON map.
  factory StoryLeg.fromJson(Map<String, dynamic> json) {
    return StoryLeg(
      userMessage: Map<String, dynamic>.from(json['userMessage'] ?? {}),
      aiResponse: Map<String, dynamic>.from(json['aiResponse'] ?? {}),
    );
  }
}

/// Holds the dimension variables as defined in your requirements.
class StoryDimensions {
  // Dimension 1 - Setting
  String time;
  String place;
  String physicalEnvironment;
  String culturalAndSocialContext;
  String technologyAndAdvancement;
  String moodAndAtmosphere;
  String worldBuildingDetails;

  // Dimension 2 - Genre
  String genre;
  // Dimension 3 - Tone
  String tone;
  // Dimension 4 - Style
  String style;
  // Dimension 5 - Perspective
  String perspective;
  // Dimension 6 - Difficulty (Encounters & Challenges)
  String difficulty;
  // Dimension 7 - Protagonist Customization
  String protagonistBackground;
  String protagonistAbilities;
  String protagonistPersonality;
  String protagonistReputation;
  // Dimension 8 - Antagonist Development
  String antagonistDevelopment;
  // Dimension 9 - Theme
  String theme;
  // Dimension 10 - Encounter Variations
  String encounterVariations;
  // Dimension 11 - Moral Dilemmas
  String moralDilemmas;
  // Dimension 12 - Story Pacing
  String storyPacing;
  // Dimension 13 - Final Objective
  String finalObjective;
  // Dimension 14 - Consequences of Failure
  String consequencesOfFailure;
  // Dimension 15 - Decision Options
  String decisionOptions;
  // Dimension 16 - Puzzle & Final Challenge (Abstract, Turn-Based, Good vs. Fail Ending, No Story Elements)
  String puzzleAndFinalChallenge;
  // Dimension 17 - Fail States
  String failStates;

  StoryDimensions({
    this.time = "",
    this.place = "",
    this.physicalEnvironment = "",
    this.culturalAndSocialContext = "",
    this.technologyAndAdvancement = "",
    this.moodAndAtmosphere = "",
    this.worldBuildingDetails = "",
    this.genre = "",
    this.tone = "",
    this.style = "",
    this.perspective = "",
    this.difficulty = "",
    this.protagonistBackground = "",
    this.protagonistAbilities = "",
    this.protagonistPersonality = "",
    this.protagonistReputation = "",
    this.antagonistDevelopment = "",
    this.theme = "",
    this.encounterVariations = "",
    this.moralDilemmas = "",
    this.storyPacing = "",
    this.finalObjective = "",
    this.consequencesOfFailure = "",
    this.decisionOptions = "",
    this.puzzleAndFinalChallenge = "",
    this.failStates = "",
  });

  Map<String, dynamic> toJson() {
    return {
      "Dimension 1 - Setting": {
        "1A - Time": time,
        "1B - Place": place,
        "1C - Physical Environment": physicalEnvironment,
        "1D - Cultural & Social Context": culturalAndSocialContext,
        "1E - Technology & Level of Advancement": technologyAndAdvancement,
        "1F - Mood & Atmosphere": moodAndAtmosphere,
        "1G - World-Building Details": worldBuildingDetails,
      },
      "Dimension 2 - Genre": genre,
      "Dimension 3 - Tone": tone,
      "Dimension 4 - Style": style,
      "Dimension 5 - Perspective": perspective,
      "Dimension 6 - Difficulty (Encounters & Challenges)": difficulty,
      "Dimension 7 - Protagonist Customization": {
        "Background": protagonistBackground,
        "Abilities": protagonistAbilities,
        "Personality": protagonistPersonality,
        "Reputation": protagonistReputation,
      },
      "Dimension 8 - Antagonist Development": antagonistDevelopment,
      "Dimension 9 - Theme": theme,
      "Dimension 10 - Encounter Variations": encounterVariations,
      "Dimension 11 - Moral Dilemmas": moralDilemmas,
      "Dimension 12 - Story Pacing": storyPacing,
      "Dimension 13 - Final Objective": finalObjective,
      "Dimension 14 - Consequences of Failure": consequencesOfFailure,
      "Dimension 15 - Decision Options": decisionOptions,
      "Dimension 16 - Puzzle & Final Challenge (Abstract, Turn-Based, Good vs. Fail Ending, No Story Elements)": puzzleAndFinalChallenge,
      "Dimension 17 - Fail States": failStates,
    };
  }

  factory StoryDimensions.fromJson(Map<String, dynamic> json) {
    return StoryDimensions(
      time: json["Dimension 1 - Setting"]?["1A - Time"] ?? "Random",
      place: json["Dimension 1 - Setting"]?["1B - Place"] ?? "Random",
      physicalEnvironment: json["Dimension 1 - Setting"]?["1C - Physical Environment"] ?? "Random",
      culturalAndSocialContext: json["Dimension 1 - Setting"]?["1D - Cultural & Social Context"] ?? "Random",
      technologyAndAdvancement: json["Dimension 1 - Setting"]?["1E - Technology & Level of Advancement"] ?? "Random",
      moodAndAtmosphere: json["Dimension 1 - Setting"]?["1F - Mood & Atmosphere"] ?? "Random",
      worldBuildingDetails: json["Dimension 1 - Setting"]?["1G - World-Building Details"] ?? "Random",
      genre: json["Dimension 2 - Genre"] ?? "Random",
      tone: json["Dimension 3 - Tone"] ?? "Random",
      style: json["Dimension 4 - Style"] ?? "Random",
      perspective: json["Dimension 5 - Perspective"] ?? "Random",
      difficulty: json["Dimension 6 - Difficulty (Encounters & Challenges)"] ?? "Random",
      protagonistBackground: json["Dimension 7 - Protagonist Customization"]?["Background"] ?? "Random",
      protagonistAbilities: json["Dimension 7 - Protagonist Customization"]?["Abilities"] ?? "Random",
      protagonistPersonality: json["Dimension 7 - Protagonist Customization"]?["Personality"] ?? "Random",
      protagonistReputation: json["Dimension 7 - Protagonist Customization"]?["Reputation"] ?? "Random",
      antagonistDevelopment: json["Dimension 8 - Antagonist Development"] ?? "Random",
      theme: json["Dimension 9 - Theme"] ?? "Random",
      encounterVariations: json["Dimension 10 - Encounter Variations"] ?? "Random",
      moralDilemmas: json["Dimension 11 - Moral Dilemmas"] ?? "Random",
      storyPacing: json["Dimension 12 - Story Pacing"] ?? "Random",
      finalObjective: json["Dimension 13 - Final Objective"] ?? "Random",
      consequencesOfFailure: json["Dimension 14 - Consequences of Failure"] ?? "Random",
      decisionOptions: json["Dimension 15 - Decision Options"] ?? "Random",
      puzzleAndFinalChallenge: json["Dimension 16 - Puzzle & Final Challenge (Abstract, Turn-Based, Good vs. Fail Ending, No Story Elements)"] ?? "Random",
      failStates: json["Dimension 17 - Fail States"] ?? "Random",
    );
  }
}

// -------------------------------------------------------------------
// 1. Strategy Pattern Interface & Implementations
// -------------------------------------------------------------------

/// Strategy interface defining how to get section-leg limits.
abstract class SectionLengthStrategy {
  /// Returns a map (section -> max legs) for that strategy.
  Map<String, int> getSectionLegLimits();
}

/// A short-story strategy (fewer legs per section).
class ShortStoryStrategy implements SectionLengthStrategy {
  @override
  Map<String, int> getSectionLegLimits() {
    return {
      "Exposition": 1,
      "Rising Action": 2,
      "Climax": 2,
      "Falling Action": 2,
      "Resolution": 2,
      "Final Resolution": 1
    };
  }
}

/// A medium-story strategy (a default/balanced approach).
class MediumStoryStrategy implements SectionLengthStrategy {
  @override
  Map<String, int> getSectionLegLimits() {
    return {
      "Exposition": 2,
      "Rising Action": 3,
      "Climax": 3,
      "Falling Action": 3,
      "Resolution": 3,
      "Final Resolution": 1
    };
  }
}

/// A long-story strategy (more legs per section).
class LongStoryStrategy implements SectionLengthStrategy {
  @override
  Map<String, int> getSectionLegLimits() {
    return {
      "Exposition": 3,
      "Rising Action": 4,
      "Climax": 4,
      "Falling Action": 4,
      "Resolution": 4,
      "Final Resolution": 1
    };
  }
}

// -------------------------------------------------------------------
// StoryData (Context) that uses a SectionLengthStrategy
// -------------------------------------------------------------------

/// Holds a user's story data including options, story legs, dimensions,
/// and context for section-based storytelling.
class StoryData {
  List<StoryLeg> storyLegs = [];
  String? storyTitle;
  int? optionCount;

  // Dimensions (genre, setting, tone, etc.)
  StoryDimensions dimensions = StoryDimensions();

  // Tracks the current story progression
  int currentLeg = 0; // Counter for legs within the current section
  String currentSection = "Exposition"; // Starting section
  int currentSectionStartIndex = 0; // Index where the current section starts

  // Strategy Pattern
  SectionLengthStrategy? _sectionLengthStrategy;
  late Map<String, int> sectionLegLimits;

  // Once the final resolution is generated, stored here.
  Map<String, dynamic>? finalResolution;
  DateTime? lastActivity;

  /// Constructor that sets a default MediumStoryStrategy
  StoryData() {
    setSectionLengthStrategy(MediumStoryStrategy());
  }

  /// Allows changing the strategy at runtime.
  void setSectionLengthStrategy(SectionLengthStrategy strategy) {
    _sectionLengthStrategy = strategy;
    sectionLegLimits = strategy.getSectionLegLimits();
  }

  /// Helper method that lets you pick a strategy by name (e.g. "short", "medium", "long").
  void selectStrategyFromString(String size) {
    switch (size.toLowerCase()) {
      case 'short':
        setSectionLengthStrategy(ShortStoryStrategy());
        break;
      case 'medium':
        setSectionLengthStrategy(MediumStoryStrategy());
        break;
      case 'long':
        setSectionLengthStrategy(LongStoryStrategy());
        break;
      default:
        // If no match, keep the default or handle as you wish
        setSectionLengthStrategy(ShortStoryStrategy());
        break;
    }
  }

  /// Convert StoryData to JSON for Firestore.
  Map<String, dynamic> toJson() {
    return {
      'storyTitle': storyTitle,
      'optionCount': optionCount,
      'dimensions': dimensions.toJson(),
      'currentLeg': currentLeg,
      'currentSection': currentSection,
      'sectionLegLimits': sectionLegLimits,
      'storyLegs': storyLegs.map((leg) => {
            'userMessage': leg.userMessage,
            'aiResponse': leg.aiResponse,
          }).toList(),
      'lastActivity': lastActivity?.toIso8601String(),
    };
  }

  /// Updates the current StoryData instance with values from the provided JSON map.
  void updateFromMap(Map<String, dynamic> map) {
    storyTitle = map['storyTitle'] as String?;
    optionCount = map['optionCount'] as int?;
    currentLeg = map['currentLeg'] ?? 0;
    currentSection = map['currentSection'] as String? ?? "Exposition";
    sectionLegLimits = Map<String, int>.from(map['sectionLegLimits'] ?? {
      "Exposition": 1,
      "Rising Action": 2,
      "Climax": 2,
      "Falling Action": 2,
      "Resolution": 1,
    });

    if (map['storyLegs'] != null) {
      storyLegs = (map['storyLegs'] as List<dynamic>)
          .map((legMap) => StoryLeg.fromJson(Map<String, dynamic>.from(legMap)))
          .toList();
    }

    if (map['lastActivity'] != null) {
      lastActivity = DateTime.tryParse(map['lastActivity'] as String);
    }

    if (map['finalResolution'] != null) {
      finalResolution = Map<String, dynamic>.from(map['finalResolution']);
    }

    if (map['dimensions'] != null) {
      dimensions = StoryDimensions.fromJson(
        Map<String, dynamic>.from(map['dimensions']),
      );
    }
  }
}
