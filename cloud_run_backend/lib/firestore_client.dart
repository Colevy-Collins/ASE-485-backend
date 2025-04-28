import 'dart:convert';
import 'dart:io';

import 'package:googleapis/firestore/v1.dart' as fs;
import 'package:googleapis_auth/auth_io.dart';

import 'utility/custom_exceptions.dart';

// -------------------------------------------------------------------
//  Project‑wide constants
// -------------------------------------------------------------------
const int    _maxSavedStories = 1;
const String _projectId       = 'versatale-966fe';
const String _basePath        =
    'projects/$_projectId/databases/(default)/documents';
const String _rtdbBaseUrl     =
    'https://$_projectId-default-rtdb.firebaseio.com';

// -------------------------------------------------------------------
//  Cached clients & tokens
// -------------------------------------------------------------------
fs.FirestoreApi?             _cachedFsApi;
AutoRefreshingAuthClient?    _cachedAuthClient;
DateTime?                    _cachedAuthExpiry;

/// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
///  Shared helper: mint (and cache) an AuthClient for all Firebase scopes
/// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
Future<AutoRefreshingAuthClient> _authClient() async {
  // Return the existing client if its token is still valid.
  if (_cachedAuthClient != null &&
      _cachedAuthExpiry != null &&
      DateTime.now().isBefore(_cachedAuthExpiry!.subtract(const Duration(minutes: 1)))) {
    return _cachedAuthClient!;
  }

  final jsonStr = Platform.environment['SERVICE_ACCOUNT_JSON'];

  if (jsonStr == null) throw MissingServiceAccountJsonException();

  final creds = ServiceAccountCredentials.fromJson(jsonStr);
  const scopes = [
    fs.FirestoreApi.datastoreScope,
    'https://www.googleapis.com/auth/firebase.database',
    'https://www.googleapis.com/auth/userinfo.email',
  ];

  final client = await clientViaServiceAccount(creds, scopes);
  _cachedAuthClient = client;
  _cachedAuthExpiry = client.credentials.accessToken.expiry;
  return client;
}

/// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
///  Firestore API getter (cached)
/// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
Future<fs.FirestoreApi> get _firestore async {
  if (_cachedFsApi != null) return _cachedFsApi!;
  final client = await _authClient();
  _cachedFsApi = fs.FirestoreApi(client);
  return _cachedFsApi!;
}

/// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
///  Public API (Firestore)
/// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
Future<void> saveStory(String userId, Map<String, dynamic> storyJson) =>
    _safeFsCall('saveStory', () async {
  final firestore = await _firestore;

  // 1) quota check
  final docs = await firestore.projects.databases.documents
      .list(_basePath, 'saved_stories');
  final count = docs.documents
          ?.where((d) =>
              d.fields?['userId']?.stringValue == userId)
          .length ?? 0;

  if (count >= _maxSavedStories) throw MaxUserStoriesException();

  // 2) write
  storyJson['userId'] = userId;
  final docId   = '$userId-${DateTime.now().millisecondsSinceEpoch}';
  final docPath = '$_basePath/saved_stories/$docId';

  final document = fs.Document(fields: _toFirestoreFields(storyJson));
  await firestore.projects.databases.documents.patch(document, docPath);
});

Future<List<Map<String, dynamic>>> getSavedStories(String userId) =>
    _safeFsCall('getSavedStories', () async {
  final firestore = await _firestore;
  final docs = await firestore.projects.databases.documents
      .list(_basePath, 'saved_stories');

  return (docs.documents ?? [])
      .where((d) => d.fields?['userId']?.stringValue == userId)
      .map((d) {
    final map = _fromFirestoreFields(d.fields ?? {});
    map['story_ID'] = d.name?.split('/').last ?? '';
    return map;
  }).toList();
});

Future<Map<String, dynamic>> getSavedStoryById(String storyId) =>
    _safeFsCall('getSavedStoryById', () async {
  final firestore = await _firestore;
  final docPath   = '$_basePath/saved_stories/$storyId';

  final doc = await firestore.projects.databases.documents.get(docPath);
  if (doc.fields == null) {
    throw StoryException('Story not found.', statusCode: 404);
  }

  final map = _fromFirestoreFields(doc.fields!)
    ..['story_ID'] = storyId;
  return map;
});

Future<void> deleteSavedStory(String storyId) =>
    _safeFsCall('deleteSavedStory', () async {
  final firestore = await _firestore;
  final docPath   = '$_basePath/saved_stories/$storyId';
  await firestore.projects.databases.documents.delete(docPath);
});

Future<void> deleteAllStories(String userId) => _safeFsCall(
      'deleteAllStories',
      () async {
    final stories = await getSavedStories(userId);
    for (final s in stories) {
      final id = s['story_ID'] as String?;
      if (id != null && id.isNotEmpty) await deleteSavedStory(id);
    }
  },
);

Future<void> createOrUpdateUserData(
  String userId, {
  required DateTime lastAccessDate,
}) =>
    _safeFsCall('createOrUpdateUserData', () async {
  final firestore = await _firestore;
  final docPath   = '$_basePath/user_data/$userId';

  bool    exists          = true;
  String? creationDateIso;

  // ── 1 · check if the doc exists (to preserve other fields) ────────────
  try {
    final existing =
        await firestore.projects.databases.documents.get(docPath);
    creationDateIso = existing.fields?['creationDate']?.stringValue;
  } on fs.DetailedApiRequestError catch (e) {
    if (e.status == 404) {
      exists = false;
    } else {
      rethrow;
    }
  }

  // ── 2 · build the map with ONLY the fields we want to set/override ────
  final data = <String, dynamic>{
    'userId'        : userId,
    'lastAccessDate': lastAccessDate.toUtc().toIso8601String(),
  };

  // ensure creationDate is set exactly once
  if (!exists) {
    data['creationDate'] =
        creationDateIso ?? lastAccessDate.toUtc().toIso8601String();
  }

  final document = fs.Document(fields: _toFirestoreFields(data));

  // ── 3 · patch: if doc exists, use updateMask so other fields survive ──
  if (exists) {
    await firestore.projects.databases.documents.patch(
      document,
      docPath,
      updateMask_fieldPaths: data.keys.toList(), // touches ONLY these keys
    );
  } else {
    // first time → write all provided fields (none of the “missing” keys yet)
    await firestore.projects.databases.documents.patch(document, docPath);
  }
});

Future<void> updateUserPreferences(
  String userId, {
  String? preferredPalette,
  String? preferredFont,
}) =>
    _safeFsCall('updateUserPreferences', () async {
  final firestore = await _firestore;
  final docPath   = '$_basePath/user_data/$userId';

  final data = <String, String>{};
  if (preferredPalette != null) data['preferredPalette'] = preferredPalette;
  if (preferredFont    != null) data['preferredFont']    = preferredFont;
  if (data.isEmpty) return;

  final document = fs.Document(fields: _toFirestoreFields(data));

  await firestore.projects.databases.documents.patch(
    document,
    docPath,
    updateMask_fieldPaths: data.keys.toList(),
  );
});

Future<Map<String, dynamic>?> getUserData(String userId) =>
    _safeFsCall('getUserData', () async {
  final firestore = await _firestore;
  final docPath   = '$_basePath/user_data/$userId';

  try {
    final doc = await firestore.projects.databases.documents.get(docPath);
    return _fromFirestoreFields(doc.fields ?? {})..['docId'] = userId;
  } on fs.DetailedApiRequestError catch (e) {
    if (e.status == 404) return null;
    rethrow;
  }
});

Future<void> deleteUserData(String userId) => _safeFsCall(
      'deleteUserData',
      () async {
    final firestore = await _firestore;
    final docPath   = '$_basePath/user_data/$userId';

    try {
      await firestore.projects.databases.documents.delete(docPath);
    } on fs.DetailedApiRequestError catch (e) {
      if (e.status == 404) return;
      rethrow;
    }
  },
);

/// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
///  RTDB: Delete a lobby node in Realtime Database
/// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
Future<void> deleteLobbyRtdb(String sessionId) =>
    _safeFsCall('deleteLobbyRtdb', () async {
  final client = await _authClient();
  final token  = client.credentials.accessToken.data;
  final uri    = Uri.parse('$_rtdbBaseUrl/lobbies/$sessionId.json?access_token=$token');

  final resp = await HttpClient().deleteUrl(uri).then((r) => r.close());
  if (resp.statusCode == 200 ||
      resp.statusCode == 204 ||
      resp.statusCode == 404) {
    return;
  }

  final body = await resp.transform(utf8.decoder).join();
  throw StoryException(
    'Failed to delete lobby ($sessionId): '
    '${resp.statusCode} $body',
  );
});

/// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
/// Shared plumbing: wraps all I/O with error translation
/// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
Future<T> _safeFsCall<T>(
  String ctx,
  Future<T> Function() action,
) async {
  try {
    return await action();
  } on StoryException {
    rethrow;
  } on SocketException catch (e, st) {
    print('SocketException in $ctx: $e\n$st');
    throw ServerUnavailableException();
  } on FormatException catch (e, st) {
    print('FormatException in $ctx: $e\n$st');
    throw StoryJsonParsingException();
  } catch (e, st) {
    print('Unexpected Firestore error in $ctx: $e\n$st');
    throw ThirdPartyServiceUnavailableException();
  }
}

/// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
/// Firestore ↔ Dart Map converters
/// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
Map<String, fs.Value> _toFirestoreFields(Map<String, dynamic> data) =>
    data.map((k, v) => MapEntry(k, _toValue(v)));

fs.Value _toValue(dynamic v) {
  if (v == null)                    return fs.Value(stringValue: 'null');
  if (v is String)                  return fs.Value(stringValue: v);
  if (v is int)                     return fs.Value(integerValue: '$v');
  if (v is double)                  return fs.Value(doubleValue: v);
  if (v is bool)                    return fs.Value(booleanValue: v);
  if (v is DateTime)                return fs.Value(timestampValue: v.toUtc().toIso8601String());
  if (v is List)                    return fs.Value(arrayValue: fs.ArrayValue(values: v.map(_toValue).toList()));
  if (v is Map<String, dynamic>)    return fs.Value(mapValue: fs.MapValue(fields: _toFirestoreFields(v)));  
  return fs.Value(stringValue: v.toString());
}

Map<String, dynamic> _fromFirestoreFields(Map<String, fs.Value> f) =>
    f.map((k, v) => MapEntry(k, _fromValue(v)));

dynamic _fromValue(fs.Value v) {
  if (v.stringValue != null)    return v.stringValue == 'null' ? null : v.stringValue;
  if (v.integerValue != null)   return int.tryParse(v.integerValue!) ?? v.integerValue;
  if (v.doubleValue != null)    return v.doubleValue;
  if (v.booleanValue != null)   return v.booleanValue;
  if (v.timestampValue != null) return DateTime.tryParse(v.timestampValue!);
  if (v.arrayValue?.values != null) {
    return v.arrayValue!.values!.map(_fromValue).toList();
  }
  if (v.mapValue?.fields != null) {
    return _fromFirestoreFields(v.mapValue!.fields!);
  }
  return null;
}
