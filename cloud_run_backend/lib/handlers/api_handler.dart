// api_handler.dart
import 'dart:convert';
import 'package:shelf/shelf.dart';
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
import '../controllers/fetch_lobby_state_controller.dart';
import '../controllers/update_player_name_controller.dart';
import '../controllers/submit_vote_controller.dart';
import '../controllers/resolve_votes_controller.dart';
import '../utility/story_cleanup.dart';
import '../models/story_storage.dart';
import '../models/multiplayer_session.dart';

/// Extracts the storyId from a request.
/// For GET/DELETE methods, it checks the query parameters.
/// For POST methods, it reads the JSON body.
Future<String?> extractStoryId(Request request) async {
  if (request.method == 'GET' || request.method == 'DELETE') {
    return request.requestedUri.queryParameters['storyId'];
  } else if (request.method == 'POST') {
    try {
      final payload = await request.readAsString();
      final body = jsonDecode(payload);
      return body['storyId'];
    } catch (e) {
      // If JSON parsing fails, or storyId is not in the body.
      return null;
    }
  }
  return null;
}

Handler createApiHandler() {
  return (Request request) async {
    // Clean up inactive stories.
    cleanInactiveStories();

    final userId = request.headers['X-User-Id'];
    if (userId == null) return Response.forbidden('User ID not found.');
    final path = request.requestedUri.path;

    // Create a StoryData object only for endpoints that need it.
    // Endpoints like view_story and delete_story don't require a StoryData object.

    var storyData = getOrCreateStory(userId);
    storyData.lastActivity = DateTime.now();
    // If this request is *not* one of the multiplayer endpoints,
    // clear any existing multiplayerSessionId to enforce solo mode.


    if (path == '/story' && request.method == 'GET') {
      return GetStoryController().handle(request, storyData);
    } else if (path == '/start_story' && request.method == 'POST') {
      storyData = resetStoryForUser(userId);
      return StartStoryController().handle(request, storyData);
    } else if (path == '/next_leg' && request.method == 'POST') {
      return NextLegController().handle(request, storyData);
    } else if (path == '/previous_leg' && request.method == 'GET') {
      return PreviousLegController().handle(request, storyData);
    } else if (path == '/save_story' && request.method == 'POST') {
      return SaveStoryController().handle(request, userId, storyData);
    } else if (path == '/saved_stories' && request.method == 'GET') {
      return GetSavedStoriesController().handle(request, userId);
    } else if (path.startsWith('/view_story') && request.method == 'GET') {
      final storyId = await extractStoryId(request);
      if (storyId == null) return Response.badRequest(body: 'Missing storyId');
      return ViewStoryController().handle(request, storyId);
    } else if (path.startsWith('/delete_story') && request.method == 'POST') {
      final storyId = await extractStoryId(request);
      if (storyId == null) return Response.badRequest(body: 'Missing storyId');
      return DeleteStoryController().handle(request, storyId);
    } else if (path == '/continue_story' && request.method == 'POST') {
      storyData = resetStoryForUser(userId);
      final storyId = await extractStoryId(request);
      if (storyId == null) return Response.badRequest(body: 'Missing storyId');
      return ContinueStoryController().handle(request, storyId, storyData);
    } else if (path == '/profile' && request.method == 'GET') {
      return GetProfileDataController().handle(request, userId);
    } else if (path == '/delete_user_data' && request.method == 'POST') {
      return DeleteUserDataController().handle(request, userId);
    } else if (path == '/delete_all_stories' && request.method == 'POST') {
      return DeleteAllStoriesController().handle(request, userId);
    } else if (path == '/update_last_access' && request.method == 'POST') {
      return UpdateLastAccessController().handle(request, userId, DateTime.now());
    } else if (path == '/create_multiplayer_session' && request.method == 'POST') {
      return CreateMultiplayerSessionController().handle(request, storyData);
    } else if (path == '/join_multiplayer_session' && request.method == 'POST') {
      return JoinMultiplayerSessionController().handle(request, storyData);
    } else if (path == '/lobby_state' && request.method == 'GET') {
      return FetchLobbyStateController().handle(request, storyData);
    }else if (path == '/lobby_state' && request.method == 'GET') {
      return FetchLobbyStateController().handle(request, storyData);
    } else if (path == '/update_player_name' && request.method == 'POST') {
      return UpdatePlayerNameController().handle(request, storyData);
    } else if (path == '/submit_vote' && request.method == 'POST') {
      return SubmitVoteController().handle(request, storyData);
    } else if (path == '/resolve_votes' && request.method == 'POST') {
      return ResolveVotesController().handle(request, storyData);
    } else {
      return Response.notFound('Route not found');
    }
  };
}
