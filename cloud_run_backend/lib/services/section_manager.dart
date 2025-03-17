import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/story.dart';

class SectionManager {
  // Updates the section summaries by summarizing the current section.

  // Handles the section transition for non-Resolution sections.
  Future<void> handleSectionTransition(StoryData storyData, GenerativeModel model, List<Content> history) async {
    
    if (storyData.currentLeg >= storyData.sectionLegLimits[storyData.currentSection]!) {
    storyData.currentSectionStartIndex = storyData.storyLegs.length;
      // Transition to the next section.
      switch (storyData.currentSection) {
        case "Exposition":
          storyData.currentSection = "Rising Action";
          break;
        case "Rising Action":
          storyData.currentSection = "Climax";
          break;
        case "Climax":
          storyData.currentSection = "Falling Action";
          break;
        case "Falling Action":
          storyData.currentSection = "Resolution";
          break;
        case "Resolution":
          storyData.currentSection = "Final Resolution";
          break;
        default:
          storyData.currentSection = "Final Resolution";
          break;
      }
      // Reset leg counter for the new section.
      storyData.currentLeg = 0;
    }
  }
}
