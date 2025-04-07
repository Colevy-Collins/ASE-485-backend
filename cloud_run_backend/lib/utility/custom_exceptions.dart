// custom_exceptions.dart

/// Centralized error message strings so you only change them in one place.
class ErrorStrings {
  static const missingGeminiApiKey = 'No GEMINI_API_KEY environment variable.';
  static const storyJsonParsingFailed = 'Failed to parse AI response as JSON.';
  static const missingServiceAccountJson = 'SERVICE_ACCOUNT_JSON environment variable is not set.';
  static const maxUserStoriesReached = 'You have reached the maximum number of saved stories. Please delete some stories to continue.';
  static const cannotRemoveLastStoryLeg = 'Cannot remove the last story leg because only one leg remains.';
  static const thirdPartyServiceUnavailable = 'A required third-party service is currently unavailable.';
  static const serverUnavailable = 'The server is currently unreachable.';
  static const unknownError = 'An unexpected error occurred. Please try again later.';
}

/// Base exception class for story-related errors.
class StoryException implements Exception {
  final String message;

  /// If [message] is null, it defaults to [ErrorStrings.unknownError].
  StoryException([String? message])
      : message = message ?? ErrorStrings.unknownError;

  @override
  String toString() => 'StoryException: $message';
}

/// Thrown when the GEMINI_API_KEY environment variable is missing.
class MissingGeminiApiKeyException extends StoryException {
  MissingGeminiApiKeyException([String? message])
      : super(message ?? ErrorStrings.missingGeminiApiKey);
}

/// Thrown when we fail to parse an AI response as valid JSON.
class StoryJsonParsingException extends StoryException {
  StoryJsonParsingException([String? message])
      : super(message ?? ErrorStrings.storyJsonParsingFailed);
}

/// Thrown when the user has reached the maximum number of saved stories allowed.
class MaxUserStoriesException extends StoryException {
  MaxUserStoriesException([String? message])
      : super(message ?? ErrorStrings.maxUserStoriesReached);
}

/// Thrown when the SERVICE_ACCOUNT_JSON environment variable is missing.
class MissingServiceAccountJsonException extends StoryException {
  MissingServiceAccountJsonException([String? message])
      : super(message ?? ErrorStrings.missingServiceAccountJson);
}

/// Thrown for invalid operations on the story’s structure (e.g., removing the last leg).
class InvalidStoryOperationException extends StoryException {
  InvalidStoryOperationException([String? message])
      : super(message ?? ErrorStrings.cannotRemoveLastStoryLeg);
}

/// Thrown when a required external (third-party) service is unavailable.
class ThirdPartyServiceUnavailableException extends StoryException {
  ThirdPartyServiceUnavailableException([String? message])
      : super(message ?? ErrorStrings.thirdPartyServiceUnavailable);
}

/// Thrown when the server itself (or network) is unreachable.
class ServerUnavailableException extends StoryException {
  ServerUnavailableException([String? message])
      : super(message ?? ErrorStrings.serverUnavailable);
}
