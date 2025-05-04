import '../models/story.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'prompt_generator.dart';
import '../utility/custom_exceptions.dart';

class StoryManager {
  // ────────────────────────────────────────────────────────────────────────────
  // Canonical look‑ups / constants
  static const _difficultyMap = <String, int>{
    'Easy': 4,
    'Normal': 3,
    'Hard': 2,
    'Nightmare': 1,
  };

  static const _excludedDims = <String>{
    'Difficulty',
    'Minimum Number of Options',
    'Story Length',
  };

  // ────────────────────────────────────────────────────────────────────────────
  final PromptGenerator _promptGen;
  StoryManager({PromptGenerator? promptGenerator})
      : _promptGen = promptGenerator ?? PromptGenerator();

  // ────────────────────────────────────────────────────────────────────────────
  /// Builds a fresh [StoryData] instance from a decoded‑JSON payload.
  void initializeStory(StoryData story, Map<String, dynamic> data) {
    final dims = (data['dimensions'] as Map<String, dynamic>?) ?? const {};

    // Fixed dimensions
    story
      ..selectStrategyFromString(dims['Story Length'] as String? ?? 'Short')
      ..difficulty = _difficultyMap[dims['Difficulty']] ?? _difficultyMap['Easy']!
      ..optionCount =
          int.tryParse(dims['Minimum Number of Options']?.toString() ?? '') ?? 2

      // Persisted state
      ..currentSection          = data['currentSection']          as String? ?? 'Exposition'
      ..currentLeg              = data['currentLeg']              as int?    ?? 0
      ..currentSectionStartIndex = data['currentSectionStartIndex'] as int?    ?? 0;

    // Dynamic dimensions
    for (final entry in dims.entries) {
      if (!_excludedDims.contains(entry.key) && entry.value is String) {
        story.dimensions[entry.key] = entry.value as String;
      }
    }

    // Seed the very first leg.
    final system = _promptGen.generateSystemPrompt(story);
    story.storyLegs.add(StoryLeg(userMessage: const {}, aiResponse: system));
  }

  // ────────────────────────────────────────────────────────────────────────────
  void appendStoryLeg(
    StoryData story,
    String decision,
    Map<String, dynamic> aiResponse,
  ) {
    story.storyLegs.add(
      StoryLeg(
        userMessage: {'role': 'user', 'content': decision},
        aiResponse: aiResponse,
      ),
    );
    story.storyTitle = aiResponse['storyTitle'];
  }

  // ────────────────────────────────────────────────────────────────────────────
  /// Returns the system prompt plus the most‑recent [maxLegs] exchanges.
  List<Content> buildChatHistory(StoryData story, {int maxLegs = 25}) {
    if (story.storyLegs.isEmpty) return [];

    final history = <Content>[
      Content.text(story.storyLegs.first.aiResponse['content']),
    ];

    final recent = story.storyLegs.skip(
      (story.storyLegs.length - maxLegs).clamp(1, story.storyLegs.length),
    );

    for (final leg in recent) {
      history
        ..add(Content.text('User: ${leg.userMessage['content']}'))
        ..add(Content.text('AI: ${leg.aiResponse['content']}'));
    }
    return history;
  }

  // ────────────────────────────────────────────────────────────────────────────
  void removeLastStoryLeg(StoryData story) {
    if (story.storyLegs.length <= 2) {
      throw InvalidStoryOperationException(
        'Cannot remove the last story leg because only one leg remains.',
      );
    }
    story.storyLegs.removeLast();
    story.storyTitle = story.storyLegs.last.aiResponse['storyTitle'];
  }
}
