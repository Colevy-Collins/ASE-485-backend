import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:firebase_admin/firebase_admin.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

void main() async {
  // Initialize Firebase Admin App.
  final app = FirebaseAdmin.instance.initializeApp(
    AppOptions(
      credential: FirebaseAdmin.instance.certFromPath('serviceAccountKey.json'),
    ),
  );

  // Get the auth instance from the app.
  final auth = app.auth();

  // Middleware to verify Firebase ID Tokens.
  Middleware verifyTokenMiddleware = (Handler innerHandler) {
    return (Request request) async {
      // Allow OPTIONS requests to pass through (for CORS preflight)
      if (request.method == 'OPTIONS') {
        return Response.ok('');
      }
      try {
        // Expect the token in the Authorization header as "Bearer <token>"
        final authHeader = request.headers['Authorization'];
        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return Response.forbidden('Missing authentication token');
        }
        final token = authHeader.substring('Bearer '.length).trim();

        // Verify the token. This returns an IdToken object.
        final idToken = await auth.verifyIdToken(token);
        // Access the claims from the token.
        final userId = idToken.claims['sub'];
        print('Authenticated user: $userId');

        return innerHandler(request);
      } catch (e) {
        print('Token verification failed: $e');
        return Response.forbidden('Invalid authentication token');
      }
    };
  };

  // CORS headers configuration.
  final corsHeadersConfig = {
    "Access-Control-Allow-Origin": "*", // or restrict to your domain
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Origin, Content-Type, Authorization",
  };

  // Create a pipeline with logging, CORS, and token verification.
  var handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders(headers: corsHeadersConfig))
      .addMiddleware(verifyTokenMiddleware)
      .addHandler((Request request) {
    return Response.ok('Hello, authenticated user!');
  });

  // Start the server.
  var server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
  print('Server running on port ${server.port}');
}
