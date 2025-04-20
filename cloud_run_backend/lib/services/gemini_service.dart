// lib/services/gemini_service.dart
//
// Responsibilities
// ────────────────
// • Build prompts & chat history (delegated to PromptGenerator / StoryManager)
// • Call the Gemini API safely and translate low‑level errors into our
//   domain‑specific StoryExceptions.
// • Nothing else. All duplication / plumbing lives in the two helpers below.

import 'dart:convert';
import 'dart:io';                                // SocketException
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/story.dart';
import 'prompt_generator.dart';
import 'story_manager.dart';
import 'section_manager.dart';
import '../utility/custom_exceptions.dart';

class GeminiService {
  // ──────────────────────────────────────────────────────────────────────────
  // Construction
  // ──────────────────────────────────────────────────────────────────────────
  GeminiService({
    PromptGenerator? promptGenerator,
    StoryManager?   storyManager,
    SectionManager? sectionManager,
  })  : promptGenerator = promptGenerator ?? PromptGenerator(),
        storyManager    = storyManager    ?? StoryManager(),
        sectionManager  = sectionManager  ?? SectionManager();

  final PromptGenerator promptGenerator;
  final StoryManager    storyManager;
  final SectionManager  sectionManager;

  // ──────────────────────────────────────────────────────────────────────────
  // Public API
  // ──────────────────────────────────────────────────────────────────────────

  /// Generates the **final resolution** leg of the story.
  Future<Map<String, dynamic>> handleResolutionSection(
    StoryData       storyData,
    List<Content>   history,
    GenerativeModel model,
  ) =>
      _safeGeminiCall('handleResolutionSection', () async {
        final instruction  = promptGenerator.buildFinalInstructions(storyData);
        final chat         = model.startChat(history: history);
        final response     = await chat.sendMessage(Content.text(instruction));
        final rawJson      = response.text ?? '';
        final parsed       = jsonDecode(rawJson) as Map<String, dynamic>;

        print('AI Final Response (Parsed JSON): ${jsonEncode(parsed)}');

        storyData.finalResolution = parsed;
        return parsed;
      });

  /// Main entry‑point: advances the story by **one decision**.
  Future<Map<String, dynamic>> callGeminiAPIWithHistory(
    StoryData storyData,
    String    decision,
  ) =>
      _safeGeminiCall('callGeminiAPIWithHistory', () async {
        // 1) Build / update chat history
        final history = storyManager.buildChatHistory(storyData)
          ..add(Content.text('User: $decision'));

        // 2) Section transition logic
        final int sectionLimit =
            storyData.sectionLegLimits[storyData.currentSection] ?? 2;

        final model = _createModel(); // uses the centralised API key getter

        if (storyData.currentLeg >= sectionLimit &&
            storyData.currentSection != 'Final Resolution') {
          await sectionManager.handleSectionTransition(
              storyData, model, history);
        }

        // 3) If we’re already in the final phase, short‑circuit
        if (storyData.currentSection == 'Final Resolution') {
          return storyData.finalResolution ??
              await handleResolutionSection(storyData, history, model);
        }

        // 4) Normal flow ─ increment leg counter & build prompt
        storyData.currentLeg++;
        final sysPrompt   = promptGenerator.generateSystemPrompt(storyData);
        final instruction = promptGenerator.buildGeneralInstructions(storyData) +
            sysPrompt['content'];

        final chat       = model.startChat(history: history);
        final response   = await chat.sendMessage(Content.text(instruction));
        final jsonResult = jsonDecode(response.text ?? '') as Map<String, dynamic>
          ..['decisionNumber'] = storyData.currentLeg;

        return jsonResult;
      });

  // ──────────────────────────────────────────────────────────────────────────
  // Private helpers (the *only* place you touch when error rules change)
  // ──────────────────────────────────────────────────────────────────────────

  /// Single‑source‑of‑truth for locating the Gemini API key.
  /// Throws a *typed* exception so controllers can return **401**.
  String get _apiKey {
    final key = Platform.environment['GEMINI_API_KEY1'];
    if (key == null) throw MissingGeminiApiKeyException();
    return key;
  }

  GenerativeModel _createModel() => GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature:       2,
          topK:              40,
          topP:              0.95,
          maxOutputTokens:   8192,
          responseMimeType:  'application/json',
          responseSchema:    _responseSchema,
        ),
      );

  /// Wraps any *Gemini* call, translating low‑level errors into
  /// [StoryException] sub‑classes that already embed the correct HTTP status.
  Future<T> _safeGeminiCall<T>(
    String context,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } on SocketException catch (e, st) {
      print('SocketException in $context: $e\n$st');
      throw ServerUnavailableException();
    } on FormatException catch (e, st) {
      print('FormatException in $context: $e\n$st');
      throw StoryJsonParsingException();
    } on Exception catch (e, st) {
      // Any other exception coming from google_generative_ai.
      print('Gemini SDK exception in $context: $e\n$st');
      throw ThirdPartyServiceUnavailableException();
    } catch (e, st) {
      // Truly unexpected: preserve original stack for logs but mask for clients.
      print('Unknown error in $context: $e\n$st');
      throw StoryException(ErrorStrings.unknownError);
    }
  }

  // Pre‑built JSON schema so it’s only created once.
  static final Schema _responseSchema = Schema.object(
    description: 'Story data object for the Gemini API.',
    properties: {
      'storyTitle':      Schema.string(description: 'A short title.', nullable: false),
      'decisionNumber':  Schema.integer(description: 'Current step number.', nullable: false),
      'currentSection':  Schema.string(description: "Narrative part.", nullable: false),
      'storyLeg':        Schema.string(description: 'Narrative text.', nullable: false),
      'options': Schema.array(
        description: 'Choices, each starting with a numeric identifier.',
        items: Schema.string(nullable: false),
      ),
    },
    requiredProperties: [
      'storyTitle',
      'decisionNumber',
      'currentSection',
      'storyLeg',
      'options',
    ],
  );
}
