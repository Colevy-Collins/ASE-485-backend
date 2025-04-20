import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../controllers/get_story_controller.dart';
import '../controllers/start_story_controller.dart';
import '../controllers/next_leg_controller.dart';
import '../controllers/save_story_controller.dart';
import '../controllers/get_saved_stories_controller.dart';
import '../controllers/view_story_controller.dart';
import '../controllers/delete_story_controller.dart';
import '../controllers/continue_story_controller.dart';
import '../controllers/previous_leg_controller.dart';
import '../controllers/get_profile_data_controller.dart';
import '../controllers/delete_user_data_controller.dart';
import '../controllers/delete_all_stories_controller.dart';
import '../controllers/update_last_access_controller.dart';
import '../controllers/create_multiplayer_session_controller.dart';
import '../controllers/join_multiplayer_session_controller.dart';

import '../utility/story_cleanup.dart';
import '../models/story_storage.dart';
import '../models/story.dart';

/// ───────────────────────────────────────────────────────────────────────────
/// Public factory – call `createApiHandler()` from `bin/server.dart` exactly
/// the same way you did before. No parameters required.
/// ───────────────────────────────────────────────────────────────────────────
Handler createApiHandler() {
  // Instantiate controllers once – they are stateless so one instance is fine.
  final _getStory            = GetStoryController();
  final _startStory          = StartStoryController();
  final _nextLeg             = NextLegController();
  final _previousLeg         = PreviousLegController();
  final _saveStory           = SaveStoryController();
  final _getSavedStories     = GetSavedStoriesController();
  final _viewStory           = ViewStoryController();
  final _deleteStory         = DeleteStoryController();
  final _continueStory       = ContinueStoryController();
  final _getProfile          = GetProfileDataController();
  final _deleteUserData      = DeleteUserDataController();
  final _deleteAllStories    = DeleteAllStoriesController();
  final _updateLastAccess    = UpdateLastAccessController();
  final _createSession       = CreateMultiplayerSessionController();
  final _joinSession         = JoinMultiplayerSessionController();

  final router = Router();

  // ── Solo‑story endpoints ───────────────────────────────────────────────
  router.get   (Routes.story,              _withStory(_getStory.handle));
  router.post  (Routes.startStory,         _resetThen(_startStory.handle));
  router.post  (Routes.nextLeg,            _withStory(_nextLeg.handle));
  router.get   (Routes.previousLeg,        _withStory(_previousLeg.handle));

  // ── Saved stories ──────────────────────────────────────────────────────
  router.post  (Routes.saveStory,          _withStoryUser(_saveStory.handle));
  router.get   (Routes.savedStories,       _withUser(_getSavedStories.handle));

  // ── Single‑story actions ───────────────────────────────────────────────
  router.get   (Routes.viewStory,          _withStoryId(_viewStory.handle));
  router.post  (Routes.deleteStory,        _withStoryId(_deleteStory.handle));
  router.post  (Routes.continueStory,      _resetThenWithId(_continueStory.handle));

  // Profile & housekeeping routes ────────────────────────────────────────
  router.get   (Routes.profile,            _withUser((req, uid) => _getProfile.handle(req, userID: uid)));
  router.post  (Routes.deleteUserData,     _withUser((req, uid) => _deleteUserData.handle(req, userID: uid)));
  router.post  (Routes.deleteAllStories,   _withUser((req, uid) => _deleteAllStories.handle(req, userIdOverride: uid)));
  router.post  (Routes.updateLastAccess,   _withUser((req, uid) => _updateLastAccess.handle(req, userID: uid, time: DateTime.now())));

  // ── Multiplayer ────────────────────────────────────────────────────────
  router.post  (Routes.createSession,      _createSession.handle);
  router.post  (Routes.joinSession,        _joinSession.handle);

  // ── Build pipeline ─────────────────────────────────────────────────────
  return Pipeline()
      .addMiddleware(_cleanupInactiveStories())
      .addMiddleware(_authenticate())
      .addMiddleware(_parseJsonBody())        // ← parse JSON once here
      .addHandler(router);
}

/// ───────────────────────────────────────────────────────────────────────────
/// Routes (grouped here to avoid magic strings scattered throughout)
/// ───────────────────────────────────────────────────────────────────────────
abstract final class Routes {
  static const story             = '/story';
  static const startStory        = '/start_story';
  static const nextLeg           = '/next_leg';
  static const previousLeg       = '/previous_leg';
  static const saveStory         = '/save_story';
  static const savedStories      = '/saved_stories';
  static const viewStory         = '/view_story';
  static const deleteStory       = '/delete_story';
  static const continueStory     = '/continue_story';
  static const profile           = '/profile';
  static const deleteUserData    = '/delete_user_data';
  static const deleteAllStories  = '/delete_all_stories';
  static const updateLastAccess  = '/update_last_access';
  static const createSession     = '/create_multiplayer_session';
  static const joinSession       = '/join_multiplayer_session';
}

/// ───────────────────────────────────────────────────────────────────────────
/// Middleware
/// ───────────────────────────────────────────────────────────────────────────
Middleware _cleanupInactiveStories() => (innerHandler) => (request) async {
      cleanInactiveStories();
      return innerHandler(request);
    };

Middleware _authenticate() => (innerHandler) => (request) async {
      final userId = request.headers['X-User-Id'];
      if (userId == null) return Response.forbidden('User ID not found.');
      return innerHandler(request.change(context: {'userId': userId}));
    };

Middleware _parseJsonBody() => (innerHandler) => (request) async {
      // only parse on POSTs (or adjust per your needs)
      if (request.method != 'POST') {
        return innerHandler(request);
      }

      try {
        final payload = await request.readAsString();
        final jsonMap = payload.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(payload) as Map<String, dynamic>;

        // stash the parsed JSON for controllers
        return innerHandler(request.change(context: {'jsonBody': jsonMap}));
      } catch (_) {
        return Response.badRequest(body: 'Malformed JSON');
      }
    };

/// ───────────────────────────────────────────────────────────────────────────
/// Higher‑order helpers to keep controllers clean
/// ───────────────────────────────────────────────────────────────────────────
typedef _StoryHandler   = Future<Response> Function(Request, StoryData);
typedef _StoryIdHandler = Future<Response> Function(Request, String);
typedef _UserHandler    = Future<Response> Function(Request, String);

StoryData _touchStory(String userId) {
  final data = getOrCreateStory(userId)
    ..lastActivity = DateTime.now();
  return data;
}

String? _storyIdFrom(Request req) {
  if (req.method == 'GET') {
    return req.requestedUri.queryParameters['storyId'];
  }
  // pull from parsed JSON
  final json = req.context['jsonBody'] as Map<String, dynamic>?;
  return json?['storyId'] as String?;
}

Handler _withStory(_StoryHandler fn) => (req) {
  final userId = req.context['userId'] as String;
  final data   = _touchStory(userId);
  return fn(req, data);
};

Handler _resetThen(_StoryHandler fn) => (req) {
  final userId = req.context['userId'] as String;
  final data   = resetStoryForUser(userId);
  return fn(req, data);
};

Handler _withStoryId(_StoryIdHandler fn) => (req) {
  final storyId = _storyIdFrom(req);
  if (storyId == null) return Response.badRequest(body: 'Missing storyId');
  return fn(req, storyId);
};

Handler _resetThenWithId(Future<Response> Function(Request, String, StoryData) fn)
    => (req) {
  final userId  = req.context['userId'] as String;
  final storyId = _storyIdFrom(req);
  if (storyId == null) return Response.badRequest(body: 'Missing storyId');
  final data    = resetStoryForUser(userId);
  return fn(req, storyId, data);
};

Handler _withUser(_UserHandler fn) => (req) {
  final userId = req.context['userId'] as String;
  return fn(req, userId);
};

Handler _withStoryUser(Future<Response> Function(Request, String, StoryData) fn)
    => (req) {
  final userId = req.context['userId'] as String;
  final data   = _touchStory(userId);
  return fn(req, userId, data);
};
