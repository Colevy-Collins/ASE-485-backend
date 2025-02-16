import 'package:cloud_run_backend/cloud_run_backend.dart' as cloud_run_backend;

//void main(List<String> arguments) {
//  print('Hello world: ${cloud_run_backend.calculate()}!');
//}
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

// Create a simple router
final router = Router()
  ..get('/', (Request request) => Response.ok('Cloud Run Backend is Running!'))
  ..post('/process', (Request request) async {
    final body = await request.readAsString();
    return Response.ok('Received: $body');
  });

void main() async {
  final handler = Pipeline().addMiddleware(corsHeaders()).addHandler(router.call);
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  print('Server running on port $port');
}

