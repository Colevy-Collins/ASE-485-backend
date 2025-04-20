// lib/utility/controller_utils.dart

import 'dart:convert';
import 'package:shelf/shelf.dart';

import 'custom_exceptions.dart';

/// Common JSON headers for all responses.
const Map<String, String> _jsonHeaders = {
  'Content-Type': 'application/json',
};

/// Returns a 200 OK response with a JSON‑encoded [body].
Response jsonOk(Object body) =>
    Response.ok(jsonEncode(body), headers: _jsonHeaders);

/// Returns an error response with status [statusCode] and a JSON‑encoded [body].
Response jsonError(int statusCode, Object body) =>
    Response(statusCode, body: jsonEncode(body), headers: _jsonHeaders);

/// Extension on Shelf’s [Request] to unify user‑ID extraction.
extension RequestX on Request {
  /// Reads the `X-User-Id` header, or returns null if missing/empty.
  String? get userId {
    final id = headers['X-User-Id'];
    if (id == null || id.isEmpty) return null;
    return id;
  }
}

/// Wraps your handler in a try/catch that:
///  • converts any [StoryException] into its proper HTTP status + JSON error  
///  • logs both custom and unexpected errors  
///  • defaults unexpected errors to HTTP 500.
Future<Response> guarded(Future<Response> Function() fn) async {
  try {
    return await fn();
  } on StoryException catch (e, st) {
    // TODO: replace with your favorite logger
    print('Handled StoryException (${e.statusCode}): ${e.message}\n$st');
    return Response(
      e.statusCode,
      body: jsonEncode({'message': e.message}),
      headers: _jsonHeaders,
    );
  } catch (e, st) {
    print('Unhandled error: $e\n$st');
    return jsonError(500, {'message': e.toString()});
  }
}
