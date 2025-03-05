// lib/models/story.dart

/// Represents a single story leg, containing the user's message and the AI's response.
class StoryLeg {
  Map<String, dynamic> userMessage;
  Map<String, dynamic> aiResponse;

  StoryLeg({required this.userMessage, required this.aiResponse});
}

/// Holds a user's story data including options, story legs, and context for section-based storytelling.
class StoryData {
  List<StoryLeg> storyLegs = [];
  String? genre;
  String? setting;
  String? tone;
  int? maxLegs;
  int? optionCount;

  // Section-based storytelling properties.
  int currentLeg = 1; // Counter for legs within the current section.
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
}
