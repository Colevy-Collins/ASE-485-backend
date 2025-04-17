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

/// Holds the dimension variables in a dynamic map.
/// Instead of having a fixed set of fields, we store all dimension keys/values here.
class StoryDimensions {
  /// The internal map that stores key-value pairs for dimensions.
  Map<String, String> dimensionMap = {};

  StoryDimensions({Map<String, String>? dimensionMap}) {
    if (dimensionMap != null) {
      this.dimensionMap = dimensionMap;
    }
  }

  /// Operator for getting a dimension by key.
  /// Allows writing: `var dimensionValue = storyData.dimensions["Time"];`
  String? operator [](String key) => dimensionMap[key];

  /// Operator for setting a dimension by key.
  /// Allows writing: `storyData.dimensions["Time"] = "Mid-20th century";`
  void operator []=(String key, String value) {
    dimensionMap[key] = value;
  }

  /// Convert this object to JSON.
  Map<String, dynamic> toJson() {
    return Map<String, String>.from(dimensionMap);
  }

  /// Factory that builds a StoryDimensions from a JSON map.
  factory StoryDimensions.fromJson(Map<String, dynamic> json) {
    final Map<String, String> newMap = {};
    json.forEach((key, value) {
      if (value is String) {
        newMap[key] = value;
      }
    });
    return StoryDimensions(dimensionMap: newMap);
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
  /// A list of every leg in the story, from the initial system prompt through
  /// each user+AI exchange.
  List<StoryLeg> storyLegs = [];

  /// The story's main title (which can change over time, if desired).
  String? storyTitle;

  /// The number of options each story leg can present.
  int? optionCount;

  /// Dimensions is now dynamic, stored in StoryDimensions.dimensionMap.
  StoryDimensions dimensions = StoryDimensions();

  // New field that will hold the session ID if this story is participating in a multiplayer session.
  String? multiplayerSessionId;

  // Tracks the current story progression
  int currentLeg = 0; // Counter for legs within the current section
  String currentSection = "Exposition"; // Starting section
  int currentSectionStartIndex = 0; // Index where the current section starts

  // Strategy Pattern
  SectionLengthStrategy? _sectionLengthStrategy;
  late Map<String, int> sectionLegLimits;

  // If there's a final resolution (an ending) it's stored here.
  Map<String, dynamic>? finalResolution;

  // Tracks the last time the user interacted with this story.
  DateTime? lastActivity;

  /// Constructor that sets a default MediumStoryStrategy.
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

  /// Convert StoryData to JSON for storage (e.g., Firestore).
  Map<String, dynamic> toJson() {
    return {
      'storyTitle': storyTitle,
      'optionCount': optionCount,
      // Convert dimensions to JSON using the new approach:
      'dimensions': dimensions.toJson(),
      'currentLeg': currentLeg,
      'currentSection': currentSection,
      'sectionLegLimits': sectionLegLimits,
      'storyLegs': storyLegs.map((leg) => {
            'userMessage': leg.userMessage,
            'aiResponse': leg.aiResponse,
          }).toList(),
      'lastActivity': lastActivity?.toUtc().toIso8601String(),
      'finalResolution': finalResolution,
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

    // Convert the new 'dimensions' structure into our StoryDimensions class:
    if (map['dimensions'] != null) {
      dimensions = StoryDimensions.fromJson(
        Map<String, dynamic>.from(map['dimensions']),
      );
    }
  }
}
