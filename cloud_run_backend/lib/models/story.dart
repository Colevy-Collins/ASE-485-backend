/// Represents one exchange in the narrative (user → AI).
class StoryLeg {
  Map<String, dynamic> userMessage;
  Map<String, dynamic> aiResponse;

  StoryLeg({required this.userMessage, required this.aiResponse});

  factory StoryLeg.fromJson(Map<String, dynamic> json) => StoryLeg(
        userMessage: Map<String, dynamic>.from(json['userMessage'] ?? {}),
        aiResponse : Map<String, dynamic>.from(json['aiResponse']  ?? {}),
      );
}

/// Dynamic storage for any “dimension” selections (genre, era, etc.).
class StoryDimensions {
  Map<String, String> dimensionMap = {};

  StoryDimensions({Map<String, String>? dimensionMap}) {
    if (dimensionMap != null) this.dimensionMap = dimensionMap;
  }

  String? operator [](String key)      => dimensionMap[key];
  void    operator []=(String k, String v) => dimensionMap[k] = v;

  Map<String, dynamic> toJson() => Map<String, String>.from(dimensionMap);

  factory StoryDimensions.fromJson(Map<String, dynamic> json) {
    final map = <String, String>{};
    json.forEach((k, v) {
      if (v is String) map[k] = v;
    });
    return StoryDimensions(dimensionMap: map);
  }
}

//────────────────────────────────────────────────────────────────────────────
// Section length strategies
//────────────────────────────────────────────────────────────────────────────
abstract class SectionLengthStrategy {
  Map<String, int> getSectionLegLimits();
}

class ShortStoryStrategy implements SectionLengthStrategy {
  @override
  Map<String, int> getSectionLegLimits() => {
        "Exposition": 1,
        "Rising Action": 2,
        "Climax": 2,
        "Falling Action": 2,
        "Resolution": 2,
        "Final Resolution": 1,
      };
}

class MediumStoryStrategy implements SectionLengthStrategy {
  @override
  Map<String, int> getSectionLegLimits() => {
        "Exposition": 2,
        "Rising Action": 3,
        "Climax": 3,
        "Falling Action": 3,
        "Resolution": 3,
        "Final Resolution": 1,
      };
}

class LongStoryStrategy implements SectionLengthStrategy {
  @override
  Map<String, int> getSectionLegLimits() => {
        "Exposition": 3,
        "Rising Action": 4,
        "Climax": 4,
        "Falling Action": 4,
        "Resolution": 4,
        "Final Resolution": 1,
      };
}

//────────────────────────────────────────────────────────────────────────────
// StoryData (context object)
//────────────────────────────────────────────────────────────────────────────
class StoryData {
  // Core narrative state ----------------------------------------------------
  List<StoryLeg> storyLegs = [];
  String?        storyTitle;
  int?           optionCount;
  int?        difficulty; 
  StoryDimensions dimensions = StoryDimensions();

  // Multiplayer
  String? multiplayerSessionId;

  // Section / leg counters
  int    currentLeg               = 0;
  String currentSection           = "Exposition";
  int    currentSectionStartIndex = 0;
  int    currentNumberofWrongDecisions = 0;

  SectionLengthStrategy? _strategy;
  late Map<String, int>  sectionLegLimits;

  // Ending payload (if any)
  Map<String, dynamic>? finalResolution;

  // Timestamps
  DateTime? lastActivity;

  // Usage & billing ---------------------------------------------------------
  int    inputTokens      = 0;
  int    outputTokens     = 0;
  double estimatedCostUsd = 0.0;

  StoryData() {
    setSectionLengthStrategy(MediumStoryStrategy());
  }

  // Strategy helpers --------------------------------------------------------
  void setSectionLengthStrategy(SectionLengthStrategy s) {
    _strategy        = s;
    sectionLegLimits = s.getSectionLegLimits();
  }

  void selectStrategyFromString(String size) {
    switch (size.toLowerCase()) {
      case 'short':  setSectionLengthStrategy(ShortStoryStrategy());  break;
      case 'medium': setSectionLengthStrategy(MediumStoryStrategy()); break;
      case 'long':   setSectionLengthStrategy(LongStoryStrategy());   break;
      default:       setSectionLengthStrategy(ShortStoryStrategy());  break;
    }
  }

  // (De)serialisation -------------------------------------------------------
  Map<String, dynamic> toJson() => {
        'storyTitle'         : storyTitle,
        'optionCount'        : optionCount,
        'dimensions'         : dimensions.toJson(),
        'currentLeg'         : currentLeg,
        'currentSection'     : currentSection,
        'sectionLegLimits'   : sectionLegLimits,
        'storyLegs'          : storyLegs.map((l) => {
                                  'userMessage': l.userMessage,
                                  'aiResponse' : l.aiResponse,
                                }).toList(),
        'lastActivity'       : lastActivity?.toUtc().toIso8601String(),
        'finalResolution'    : finalResolution,
        // usage
        'inputTokens'        : inputTokens,
        'outputTokens'       : outputTokens,
        'estimatedCostUsd'   : estimatedCostUsd,
        'difficulty'         : difficulty,
        'currentNumberofWrongDecisions' : currentNumberofWrongDecisions,
      };

  void updateFromMap(Map<String, dynamic> m) {
    storyTitle       = m['storyTitle'];
    optionCount      = m['optionCount'];
    currentLeg       = m['currentLeg'] ?? 0;
    currentSection   = m['currentSection'] ?? "Exposition";
    sectionLegLimits = Map<String, int>.from(m['sectionLegLimits'] ?? {});
    difficulty       = m['difficulty'] ?? 4;
    currentNumberofWrongDecisions = m['currentNumberofWrongDecisions'] ?? 0;


    if (m['storyLegs'] != null) {
      storyLegs = (m['storyLegs'] as List<dynamic>)
          .map((v) => StoryLeg.fromJson(Map<String, dynamic>.from(v)))
          .toList();
    }

    if (m['lastActivity'] != null) {
      lastActivity = DateTime.tryParse(m['lastActivity']);
    }

    if (m['finalResolution'] != null) {
      finalResolution = Map<String, dynamic>.from(m['finalResolution']);
    }

    if (m['dimensions'] != null) {
      dimensions = StoryDimensions.fromJson(
          Map<String, dynamic>.from(m['dimensions']));
    }

    inputTokens      = m['inputTokens']      ?? 0;
    outputTokens     = m['outputTokens']     ?? 0;
    estimatedCostUsd =
        (m['estimatedCostUsd'] as num?)?.toDouble() ?? 0.0;
  }
}
