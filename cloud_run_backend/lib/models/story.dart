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


/// Holds a user's story data including options, story legs, and context for section-based storytelling.
class StoryData {
  List<StoryLeg> storyLegs = [];
  String? storyTitle;
  String? genre;
  String? setting;
  String? tone;
  int? optionCount;

  // Section-based storytelling properties.
  int currentLeg = 0; // Counter for legs within the current section.
  String currentSection = "Exposition"; // Starting section.
  int currentSectionStartIndex = 0; // Index where the current section starts.

  // Instead of a single summary, store all section summaries to provide cumulative context.
  List<String> sectionSummaries = [];

  // Define leg limits for each section.
  Map<String, int> sectionLegLimits = {
    "Exposition": 2,
    "Rising Action": 2,
    "Climax": 2,
    "Falling Action": 2,
    "Resolution": 1, // Only one final leg in Resolution.
  };

  // Stores the final resolution leg once it has been generated.
  Map<String, dynamic>? finalResolution;

  DateTime? lastActivity;
  // Convert StoryData to JSON for Firestore.
  Map<String, dynamic> toJson() {
    return {
      'storyTitle': storyTitle,
      'genre': genre,
      'setting': setting,
      'tone': tone,
      'optionCount': optionCount,
      'currentLeg': currentLeg,
      'currentSection': currentSection,
      'sectionSummaries': sectionSummaries,
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
    genre = map['genre'] as String?;
    setting = map['setting'] as String?;
    tone = map['tone'] as String?;
    optionCount = map['optionCount'] as int?;
    currentLeg = map['currentLeg'] ?? 0;
    currentSection = map['currentSection'] as String? ?? "Exposition";
    sectionSummaries = map['sectionSummaries'] != null
        ? List<String>.from(map['sectionSummaries'])
        : [];
    
    if (map['storyLegs'] != null) {
      storyLegs = (map['storyLegs'] as List<dynamic>)
          .map((legmap) => StoryLeg.fromJson(Map<String, dynamic>.from(legmap)))
          .toList();
    }
    
    if (map['lastActivity'] == null) {
      lastActivity = DateTime.tryParse(map['lastActivity'] as String);
    }
    
    if (map['finalResolution'] != null) {
      finalResolution = Map<String, dynamic>.from(map['finalResolution']);
    }
  }
  
}