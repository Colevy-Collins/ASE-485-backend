// lib/services/firestore_client.dart
//
// Clean‑room rewrite that
// ────────────────────────────────────────────────────────────────────────────
// • centralises *all* repetitive try/catch → `_safeFsCall()`
// • offers a single‑point `_firestore` getter (lazy‑cached)               //
// • removes duplicate Project / Base‑path literals                        //
// • keeps **every public function name & signature identical**            //
//   so the rest of your codebase compiles without changes.                //

import 'dart:convert';
import 'dart:io';

import 'package:googleapis/firestore/v1.dart' as fs;
import 'package:googleapis_auth/auth_io.dart';

import 'utility/custom_exceptions.dart';

const int _maxSavedStories = 1;
const String _projectId    = 'versatale-966fe';
const String _basePath     =
    'projects/$_projectId/databases/(default)/documents';

fs.FirestoreApi? _cachedApi;

/// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
///  Public API  (signatures unchanged)
/// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

Future<void> saveStory(String userId, Map<String, dynamic> storyJson) =>
    _safeFsCall('saveStory', () async {
      final firestore = await _firestore;

      // 1) quota check
      final docs = await firestore.projects.databases.documents
          .list(_basePath, 'saved_stories');
      final count = docs.documents
              ?.where((d) =>
                  d.fields?['userId']?.stringValue == userId) // filter by owner
              .length ??
          0;

      if (count >= _maxSavedStories) throw MaxUserStoriesException();

      // 2) write
      storyJson['userId'] = userId;
      final docId   = '$userId-${DateTime.now().millisecondsSinceEpoch}';
      final docPath = '$_basePath/saved_stories/$docId';

      final document =
          fs.Document(fields: _toFirestoreFields(storyJson));
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
        final map  = _fromFirestoreFields(d.fields ?? {});
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
  String   userId, {
  required DateTime lastAccessDate,
}) =>
    _safeFsCall('createOrUpdateUserData', () async {
      final firestore = await _firestore;
      final docPath   = '$_basePath/user_data/$userId';

      String? creationDateIso;

      // try‑get to preserve creationDate
      try {
        final existing =
            await firestore.projects.databases.documents.get(docPath);
        creationDateIso =
            existing.fields?['creationDate']?.stringValue; // may be null
      } on fs.DetailedApiRequestError catch (e) {
        if (e.status != 404) rethrow; // network or permission error
      }

      final data = {
        'userId':         userId,
        'creationDate':   creationDateIso ??
            lastAccessDate.toUtc().toIso8601String(),
        'lastAccessDate': lastAccessDate.toUtc().toIso8601String(),
      };

      final document = fs.Document(fields: _toFirestoreFields(data));
      await firestore.projects.databases.documents.patch(document, docPath);
    });

Future<Map<String, dynamic>?> getUserData(String userId) =>
    _safeFsCall('getUserData', () async {
      final firestore = await _firestore;
      final docPath   = '$_basePath/user_data/$userId';

      try {
        final doc = await firestore.projects.databases.documents.get(docPath);
        return _fromFirestoreFields(doc.fields ?? {})
          ..['docId'] = userId;
      } on fs.DetailedApiRequestError catch (e) {
        if (e.status == 404) return null; // no profile yet
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
          if (e.status == 404) return; // nothing to delete
          rethrow;
        }
      },
    );

/// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
///  Shared plumbing
/// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

/// Wraps any Firestore I/O and converts low‑level exceptions
/// into our domain‑specific [StoryException] hierarchy.
///
///   •  Keeps detailed logs on the server side.
///   •  Propagates *custom* [StoryException] untouched so controllers
///      can read their embedded status code.
Future<T> _safeFsCall<T>(
  String ctx,
  Future<T> Function() action,
) async {
  try {
    return await action();
  } on StoryException {
    rethrow; // already mapped + logged by caller
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

/// Initialised (and cached) Firestore API client.
Future<fs.FirestoreApi> get _firestore async {
  if (_cachedApi != null) return _cachedApi!;

  _cachedApi = await _safeFsCall('getFirestoreApi', () async {
    final json = Platform.environment['SERVICE_ACCOUNT_JSON'];
    if (json == null) throw MissingServiceAccountJsonException();

    final creds  = ServiceAccountCredentials.fromJson(json);
    const scopes = [fs.FirestoreApi.datastoreScope];
    final client = await clientViaServiceAccount(creds, scopes);
    return fs.FirestoreApi(client);
  });

  return _cachedApi!;
}
/// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
///  Firestore <‑‑► Dart Map converters
/// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

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

  // fallback for unsupported types
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
