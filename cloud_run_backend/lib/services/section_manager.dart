import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/story.dart';

class SectionManager {
  // Updates the section summaries by summarizing the current section.
  Future<String> updateSectionSummaries(StoryData storyData, GenerativeModel model) async {
    String summary = await summarizeSection(storyData, model);
    storyData.sectionSummaries.add(summary);
    return summary;
  }

  // Handles the section transition for non-Resolution sections.
  Future<void> handleSectionTransition(StoryData storyData, GenerativeModel model, List<Content> history) async {
    await updateSectionSummaries(storyData, model);
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
    }
    // Reset leg counter for the new section.
    storyData.currentLeg = 1;
    // Optionally, add a system transition message.
    Map<String, dynamic> transitionMsg = {
      "role": "system",
      "content": "Transitioning to ${storyData.currentSection}. Please continue the story."
    };
    storyData.storyLegs.add(StoryLeg(userMessage: {}, aiResponse: transitionMsg));
  }

  // Summarizes the current section.
  Future<String> summarizeSection(StoryData storyData, GenerativeModel model) async {
    StringBuffer sectionText = StringBuffer();
    for (int i = storyData.currentSectionStartIndex; i < storyData.storyLegs.length; i++) {
      StoryLeg leg = storyData.storyLegs[i];
      int legNumber = i + 1;
      String decision = leg.userMessage['content'] ?? "";
      String narrative = leg.aiResponse['content'] ?? "";
      sectionText.writeln("Leg $legNumber:");
      if (decision.trim().isNotEmpty) {
        sectionText.writeln("Decision: $decision");
      }
      sectionText.writeln("Summary: $narrative\n");
    }
    String summarizationPrompt = "Summarize the following section of the story. For each leg, include the leg number, the user's decision, and a brief summary (2-3 sentences) of the narrative. "
        "Keep it concise while preserving all important details:\n" + sectionText.toString();
    List<Content> summaryHistory = [Content.text(summarizationPrompt)];
    final summaryChat = model.startChat(history: summaryHistory);
    final summaryResponse = await summaryChat.sendMessage(Content.text(summarizationPrompt));
    return summaryResponse.text?.trim() ?? "";
  }
}
