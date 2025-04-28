//
// Responsibilities
// • Build prompts & chat history
// • Call Gemini safely, translating errors
// • Track token / cost usage and store it in StoryData
//
import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/story.dart';
import 'prompt_generator.dart';
import 'story_manager.dart';
import 'section_manager.dart';
import '../utility/custom_exceptions.dart';

class GeminiService {
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

  //─────────────────────────────────────────────────────────
  // Public API
  //─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> handleResolutionSection(
    StoryData       storyData,
    List<Content>   history,
    GenerativeModel model,
  ) =>
      _safeGeminiCall('handleResolutionSection', () async {
        final instruction = promptGenerator.buildFinalInstructions(storyData);
        final chat        = model.startChat(history: history);
        final response    = await chat.sendMessage(Content.text(instruction));

        _recordUsage(storyData, response);

        final parsed = jsonDecode(response.text ?? '') as Map<String, dynamic>;
        storyData.finalResolution = parsed;
        return parsed;
      });

  Future<Map<String, dynamic>> callGeminiAPIWithHistory(
    StoryData storyData,
    String    decision,
  ) =>
      _safeGeminiCall('callGeminiAPIWithHistory', () async {
        // 1. history
        final history = storyManager.buildChatHistory(storyData)
          ..add(Content.text('User: $decision'));

        // 2. section transition
        final sectionLimit =
            storyData.sectionLegLimits[storyData.currentSection] ?? 2;
        final model = _createModel();

        if (storyData.currentLeg >= sectionLimit &&
            storyData.currentSection != 'Final Resolution') {
          await sectionManager.handleSectionTransition(
              storyData, model, history);
        }

        // 3. already final?
        if (storyData.currentSection == 'Final Resolution') {
          return storyData.finalResolution ??
              await handleResolutionSection(storyData, history, model);
        }

        // 4. normal story continuation
        storyData.currentLeg++;
        final sysPrompt   = promptGenerator.generateSystemPrompt(storyData);
        final instruction = promptGenerator.buildGeneralInstructions(storyData) +
            sysPrompt['content'];

        final chat     = model.startChat(history: history);
        final response = await chat.sendMessage(Content.text(instruction));

        _recordUsage(storyData, response);

        final jsonResult = jsonDecode(response.text ?? '') as Map<String, dynamic>
          ..['decisionNumber']   = storyData.currentLeg
          ..['inputTokens']      = storyData.inputTokens
          ..['outputTokens']     = storyData.outputTokens
          ..['estimatedCostUsd'] = storyData.estimatedCostUsd;

        return jsonResult;
      });

  //─────────────────────────────────────────────────────────
  // Helpers
  //─────────────────────────────────────────────────────────
  void _recordUsage(StoryData story, GenerateContentResponse resp) {
    final UsageMetadata? u = resp.usageMetadata;
    if (u == null) return;

    story.inputTokens  += u.promptTokenCount     ?? 0;
    story.outputTokens += u.candidatesTokenCount ?? 0;
    story.estimatedCostUsd = _costUsd(
      story.inputTokens,
      story.outputTokens,
    );
  }

  // April-2025 public pricing (gemini-2.0-flash)
  static const double _kInCostPerToken  = 0.10 / 1e6; // $0.10 / M prompt
  static const double _kOutCostPerToken = 0.40 / 1e6; // $0.40 / M output

  double _costUsd(int inTok, int outTok) =>
      inTok * _kInCostPerToken + outTok * _kOutCostPerToken;

  //──────── Gemini model + error wrapper ─────────
  String get _apiKey {
    final key = Platform.environment['GEMINI_API_KEY1'];
    if (key == null) throw MissingGeminiApiKeyException();
    return key;
  }

  GenerativeModel _createModel() => GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature:      2,
          topK:             40,
          topP:             0.95,
          maxOutputTokens:  8192,
          responseMimeType: 'application/json',
          responseSchema:   _responseSchema,
        ),
      );

  Future<T> _safeGeminiCall<T>(
    String context,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } on SocketException {
      throw ServerUnavailableException();
    } on FormatException {
      throw StoryJsonParsingException();
    } on Exception {
      throw ThirdPartyServiceUnavailableException();
    } catch (_) {
      throw StoryException(ErrorStrings.unknownError);
    }
  }

  // JSON schema (unchanged)
  static final Schema _responseSchema = Schema.object(
    description: 'Story data object for the Gemini API.',
    properties: {
      'storyTitle'    : Schema.string(nullable: false),
      'decisionNumber': Schema.integer(nullable: false),
      'currentSection': Schema.string(nullable: false),
      'storyLeg'      : Schema.string(nullable: false),
      'options'       : Schema.array(items: Schema.string(nullable: false)),
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
