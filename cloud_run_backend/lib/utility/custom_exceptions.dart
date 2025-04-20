// lib/utility/custom_exceptions.dart

/// Centralized error message strings so you only change them in one place.
class ErrorStrings {
  static const missingGeminiApiKey     = 'No GEMINI_API_KEY environment variable.';
  static const storyJsonParsingFailed  = 'Failed to parse AI response as JSON.';
  static const missingServiceAccount   = 'SERVICE_ACCOUNT_JSON environment variable is not set.';
  static const maxUserStoriesReached   = 'User has reached the maximum number of saved stories.';
  static const cannotRemoveLastStory   = 'Cannot remove the last story leg because only one leg remains.';
  static const thirdPartyUnavailable   = 'A required third‑party service is currently unavailable.';
  static const serverUnavailable       = 'The server is currently unreachable.';
  static const unknownError            = 'An unexpected error occurred. Please try again later.';
  static const missingDimensionOption  = 'One or more required dimension options are missing.';
}

/// Base exception class for story‑related errors.
///
/// Carries both a message and an HTTP status code for accurate responses.
class StoryException implements Exception {
  final String message;
  final int statusCode;

  /// [statusCode] defaults to 500 (Internal Server Error).
  StoryException(this.message, {this.statusCode = 500});

  @override
  String toString() => 'StoryException($statusCode): $message';
}

/// 400 Bad Request – malformed or invalid input
class StoryJsonParsingException extends StoryException {
  StoryJsonParsingException([String? msg])
      : super(msg ?? ErrorStrings.storyJsonParsingFailed, statusCode: 400);
}

class InvalidStoryOperationException extends StoryException {
  InvalidStoryOperationException([String? msg])
      : super(msg ?? ErrorStrings.cannotRemoveLastStory, statusCode: 400);
}

class MissingDimensionOptionException extends StoryException {
  MissingDimensionOptionException([String? msg])
      : super(msg ?? ErrorStrings.missingDimensionOption, statusCode: 400);
}

/// 401 Unauthorized – missing or invalid credentials
class MissingGeminiApiKeyException extends StoryException {
  MissingGeminiApiKeyException([String? msg])
      : super(msg ?? ErrorStrings.missingGeminiApiKey, statusCode: 401);
}

class MissingServiceAccountJsonException extends StoryException {
  MissingServiceAccountJsonException([String? msg])
      : super(msg ?? ErrorStrings.missingServiceAccount, statusCode: 401);
}

/// 429 Too Many Requests – quota or rate limits hit
class MaxUserStoriesException extends StoryException {
  MaxUserStoriesException([String? msg])
      : super(msg ?? ErrorStrings.maxUserStoriesReached, statusCode: 429);
}

/// 503 Service Unavailable – external service or network outage
class ThirdPartyServiceUnavailableException extends StoryException {
  ThirdPartyServiceUnavailableException([String? msg])
      : super(msg ?? ErrorStrings.thirdPartyUnavailable, statusCode: 503);
}

class ServerUnavailableException extends StoryException {
  ServerUnavailableException([String? msg])
      : super(msg ?? ErrorStrings.serverUnavailable, statusCode: 503);
}

/// 500 Internal Server Error – fallback for everything else
class UnknownStoryException extends StoryException {
  UnknownStoryException([String? msg])
      : super(msg ?? ErrorStrings.unknownError, statusCode: 500);
}
