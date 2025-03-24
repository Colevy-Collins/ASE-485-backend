// main.dart
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import '../lib/handlers/api_handler.dart';
import 'package:firebase_admin/firebase_admin.dart';

void main() async {
  // Initialize Firebase Admin.
  
  final app = FirebaseAdmin.instance.initializeApp(
    AppOptions(
      // add . before files for local host. 
      credential: FirebaseAdmin.instance.certFromPath('/secrets/serviceAccountKey.json'),
    ),
  );
  final auth = app.auth();

  // Middleware to verify Firebase ID tokens.
  Middleware verifyTokenMiddleware = (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') return Response.ok('');
      try {
        final authHeader = request.headers['Authorization'];
        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return Response.forbidden('Missing authentication token');
        }
        final token = authHeader.substring('Bearer '.length).trim();
        final idToken = await auth.verifyIdToken(token);
        final userId = idToken.claims['sub'] as String;
        // Pass the user id via a custom header.
        return innerHandler(request.change(headers: {'X-User-Id': userId}));
      } catch (e) {
        print('Token verification failed: $e');
        return Response.forbidden('Invalid authentication token');
      }
    };
  };

  // CORS headers configuration.
  final corsHeadersConfig = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Origin, Content-Type, Authorization",
  };

  // Build the API handler.
  var apiHandler = createApiHandler();
  var handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders(headers: corsHeadersConfig))
      .addMiddleware(verifyTokenMiddleware)
      .addHandler(apiHandler);

  final portStr = Platform.environment['PORT'] ?? '8080';
  final port = int.tryParse(portStr) ?? 8080;
  var server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  print('Server running on port ${server.port}');
}
