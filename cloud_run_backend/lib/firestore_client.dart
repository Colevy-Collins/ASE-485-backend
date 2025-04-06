// firestore_client.dart

import 'dart:convert';
import 'dart:io';
import 'package:googleapis/firestore/v1.dart' as fs;
import 'package:googleapis_auth/auth_io.dart';
import '../utility/custom_exceptions.dart';

const int maxSaveStories = 1;

Map<String, fs.Value> convertToFirestoreFields(Map<String, dynamic> data) {
  final Map<String, fs.Value> fields = {};
  data.forEach((key, value) {
    fields[key] = _convertValue(value);
  });
  return fields;
}

fs.Value _convertValue(dynamic value) {
  if (value is String) {
    return fs.Value(stringValue: value);
  } else if (value is int) {
    return fs.Value(integerValue: value.toString());
  } else if (value is double) {
    return fs.Value(doubleValue: value);
  } else if (value is bool) {
    return fs.Value(booleanValue: value);
  } else if (value is List) {
    return fs.Value(
      arrayValue: fs.ArrayValue(
        values: value.map((e) => _convertValue(e)).toList(),
      ),
    );
  } else if (value is Map) {
    return fs.Value(
      mapValue: fs.MapValue(fields: convertToFirestoreFields(value as Map<String, dynamic>)),
    );
  } else if (value is DateTime) {
    return fs.Value(timestampValue: value.toUtc().toIso8601String());
  }
  return fs.Value(); // For null or unsupported types.
}

/// Gets a Google Firestore API client via Service Account credentials.
Future<fs.FirestoreApi> getFirestoreApi() async {
  final serviceAccountJson = Platform.environment['SERVICE_ACCOUNT_JSON'];
  if (serviceAccountJson == null) {
    throw MissingServiceAccountJsonException();
  }

  try {
    final accountCredentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
    const scopes = [fs.FirestoreApi.datastoreScope];
    final client = await clientViaServiceAccount(accountCredentials, scopes);
    return fs.FirestoreApi(client);
  
  } on SocketException catch (e, st) {
    print("SocketException in getFirestoreApi: $e\n$st");
    throw ServerUnavailableException();
  } on FormatException catch (e, st) {
    print("FormatException in getFirestoreApi: $e\n$st");
    throw StoryJsonParsingException();
  } catch (e, st) {
    print("Unexpected error in getFirestoreApi: $e\n$st");
    throw StoryException();
  }
}

Future<void> saveStory(String userId, Map<String, dynamic> storyJson) async {
  storyJson['userId'] = userId;
  final String projectId = "versatale-966fe";
  final String basePath = "projects/$projectId/databases/(default)/documents";

  fs.FirestoreApi firestore;
  try {
    firestore = await getFirestoreApi();
  } catch (e) {
    rethrow; // Already mapped
  }

  try {
    // In a real app using cloud_firestore directly, you'd do:
    // FirebaseFirestore.instance.collection('saved_stories').get() etc.
    // For your googleapis version, you do:
    final listResponse = await firestore.projects.databases.documents.list(
      basePath, 
      "saved_stories",
    );

    int userStoryCount = 0;
    if (listResponse.documents != null) {
      for (var doc in listResponse.documents!) {
        if (doc.fields != null && doc.fields!["userId"]?.stringValue == userId) {
          userStoryCount++;
        }
      }
    }

    if (userStoryCount >= maxSaveStories) {
      throw MaxUserStoriesException();
    }

    final fields = convertToFirestoreFields(storyJson);
    final document = fs.Document(fields: fields);

    final String documentId = "$userId-${DateTime.now().millisecondsSinceEpoch}";
    final String documentPath = "$basePath/saved_stories/$documentId";

    // Save/patch
    await firestore.projects.databases.documents.patch(document, documentPath);

  } on SocketException catch (e, st) {
    print("SocketException in saveStory: $e\n$st");
    throw ServerUnavailableException();
  } on FormatException catch (e, st) {
    print("FormatException in saveStory: $e\n$st");
    throw StoryJsonParsingException();
  } catch (e, st) {
    print("Unexpected error in saveStory: $e\n$st");
    throw StoryException();
  }
}

Future<List<Map<String, dynamic>>> getSavedStories(String userId) async {
  final String projectId = "versatale-966fe";
  final String basePath = "projects/$projectId/databases/(default)/documents";
  final firestore = await getFirestoreApi();

  try {
    final listResponse = await firestore.projects.databases.documents.list(
      basePath,
      "saved_stories",
    );
    final List<Map<String, dynamic>> userStories = [];

    if (listResponse.documents != null) {
      for (var doc in listResponse.documents!) {
        if (doc.fields != null && doc.fields!["userId"]?.stringValue == userId) {
          final story = _convertFirestoreFields(doc.fields!);
          final docId = doc.name?.split("/").last ?? "";
          story["story_ID"] = docId;
          userStories.add(story);
        }
      }
    }
    return userStories;

  } on SocketException catch (e, st) {
    print("SocketException in getSavedStories: $e\n$st");
    throw ServerUnavailableException();
  } on FormatException catch (e, st) {
    print("FormatException in getSavedStories: $e\n$st");
    throw StoryJsonParsingException();
  } catch (e, st) {
    print("Unexpected error in getSavedStories: $e\n$st");
    throw StoryException();
  }
}

Map<String, dynamic> _convertFirestoreFields(Map<String, fs.Value> fields) {
  final Map<String, dynamic> result = {};
  fields.forEach((key, value) {
    result[key] = _convertFromFirestoreValue(value);
  });
  return result;
}

dynamic _convertFromFirestoreValue(fs.Value value) {
  if (value.stringValue != null) {
    return value.stringValue;
  } else if (value.integerValue != null) {
    return int.tryParse(value.integerValue!) ?? value.integerValue;
  } else if (value.doubleValue != null) {
    return value.doubleValue;
  } else if (value.booleanValue != null) {
    return value.booleanValue;
  } else if (value.arrayValue != null && value.arrayValue!.values != null) {
    return value.arrayValue!.values!.map((v) => _convertFromFirestoreValue(v)).toList();
  } else if (value.mapValue != null && value.mapValue!.fields != null) {
    return _convertFirestoreFields(value.mapValue!.fields!);
  } else if (value.timestampValue != null) {
    return DateTime.tryParse(value.timestampValue!);
  }
  return null;
}

Future<Map<String, dynamic>> getSavedStoryById(String storyId) async {
  final String projectId = "versatale-966fe";
  final String basePath = "projects/$projectId/databases/(default)/documents";
  final firestore = await getFirestoreApi();
  final String documentPath = "$basePath/saved_stories/$storyId";

  try {
    final doc = await firestore.projects.databases.documents.get(documentPath);
    if (doc.fields == null) {
      throw StoryException('Story not found.');
    }

    final story = _convertFirestoreFields(doc.fields!);
    final docId = doc.name?.split("/").last ?? "";
    story["story_ID"] = docId;
    return story;

  } on SocketException catch (e, st) {
    print("SocketException in getSavedStoryById: $e\n$st");
    throw ServerUnavailableException();
  } on FormatException catch (e, st) {
    print("FormatException in getSavedStoryById: $e\n$st");
    throw StoryJsonParsingException();
  } catch (e, st) {
    print("Unexpected error in getSavedStoryById: $e\n$st");
    throw StoryException();
  }
}

Future<void> deleteSavedStory(String storyId) async {
  final String projectId = "versatale-966fe";
  final String basePath = "projects/$projectId/databases/(default)/documents";
  final firestore = await getFirestoreApi();
  final String documentPath = "$basePath/saved_stories/$storyId";

  try {
    await firestore.projects.databases.documents.delete(documentPath);
  } on SocketException catch (e, st) {
    print("SocketException in deleteSavedStory: $e\n$st");
    throw ServerUnavailableException();
  } on FormatException catch (e, st) {
    print("FormatException in deleteSavedStory: $e\n$st");
    throw StoryJsonParsingException();
  } catch (e, st) {
    print("Unexpected error in deleteSavedStory: $e\n$st");
    throw StoryException();
  }
}
