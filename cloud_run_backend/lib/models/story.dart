// lib/models/story.dart

/// Represents a single story leg, containing the user's message and the AI's response.
class StoryLeg {
  Map<String, dynamic> userMessage;
  Map<String, dynamic> aiResponse;

  StoryLeg({required this.userMessage, required this.aiResponse});
}

/// Holds a user's story data including options, a list of story legs, and section tracking.
class StoryData {
  List<StoryLeg> storyLegs = [];
  String? genre;
  String? setting;
  String? tone;
  int? maxLegs;

  // Section-based storytelling properties.
  int currentLeg = 1; // Counter for legs within the current section.
  String currentSection = "Exposition"; // Starting section.
  Map<String, int> sectionLegLimits = {
    "Exposition": 2,
    "Rising Action": 2,
    "Climax": 2,
    "Falling Action": 2,
    "Resolution": 2,
  };
}
