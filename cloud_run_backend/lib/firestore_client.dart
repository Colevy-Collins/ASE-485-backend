import 'dart:convert';
import 'dart:io';
import 'package:googleapis/firestore/v1.dart' as fs;
import 'package:googleapis_auth/auth_io.dart';
  // Define maximum allowed stories per user.
  const int maxSaveStories = 1;

/// Converts a Map<String, dynamic> to a Map<String, fs.Value> that Firestore expects.
Map<String, fs.Value> convertToFirestoreFields(Map<String, dynamic> data) {
  final Map<String, fs.Value> fields = {};
  data.forEach((key, value) {
    fields[key] = _convertValue(value);
  });
  return fields;
}

/// Helper to convert dynamic value to fs.Value.
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

/// Returns an authenticated FirestoreApi client.
Future<fs.FirestoreApi> getFirestoreApi() async {
  final serviceAccountJson = Platform.environment['SERVICE_ACCOUNT_JSON'];
  if (serviceAccountJson == null) {
    throw Exception('SERVICE_ACCOUNT_JSON environment variable is not set.');
  }
  
  final accountCredentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
  const scopes = [fs.FirestoreApi.datastoreScope];
  var client = await clientViaServiceAccount(accountCredentials, scopes);
  return fs.FirestoreApi(client);
}

/// Saves the story data to Firestore under the "saved_stories" collection.
/// Limits the number of stories per user to a predefined maximum.
Future<void> saveStory(String userId, Map<String, dynamic> storyJson) async {
  // Add userId to the story data so we can filter later.
  storyJson['userId'] = userId;
  
  final String projectId = "versatale-966fe";
  // Parent path for documents.
  final String basePath = "projects/$projectId/databases/(default)/documents";
  
  final firestore = await getFirestoreApi();
  
  // List all documents in the "saved_stories" collection.
  final listResponse = await firestore.projects.databases.documents.list(basePath, "saved_stories");
  
  int userStoryCount = 0;
  if (listResponse.documents != null) {
    for (var doc in listResponse.documents!) {
      // Check if the document belongs to this user by its "userId" field.
      if (doc.fields != null && doc.fields!["userId"]?.stringValue == userId) {
        userStoryCount++;
      }
    }
  }
  

  if (userStoryCount >= maxSaveStories) {
    throw Exception("User has reached the maximum number of saved stories ($maxSaveStories).");
  }
  
  // Convert storyJson to Firestore fields.
  final fields = convertToFirestoreFields(storyJson);
  fs.Document document = fs.Document(fields: fields);
  
  // Generate a unique document ID using the userId and current timestamp.
  final String documentId = "$userId-${DateTime.now().millisecondsSinceEpoch}";
  final String documentPath = "$basePath/saved_stories/$documentId";
  
  // Use the patch method to create (or update) the document.
  await firestore.projects.databases.documents.patch(
    document,
    documentPath,
  );
}

/// Retrieves all saved stories for a given user from Firestore.
Future<List<Map<String, dynamic>>> getSavedStories(String userId) async {
  final String projectId = "versatale-966fe";
  final String basePath = "projects/$projectId/databases/(default)/documents";
  final firestore = await getFirestoreApi();

  // List documents in the "saved_stories" collection.
  final listResponse = await firestore.projects.databases.documents.list(basePath, "saved_stories");
  List<Map<String, dynamic>> userStories = [];
  if (listResponse.documents != null) {
    for (var doc in listResponse.documents!) {
      if (doc.fields != null && doc.fields!["userId"]?.stringValue == userId) {
        userStories.add(_convertFirestoreFields(doc.fields!));
      }
    }
  }
  return userStories;
}

/// Helper function to convert Firestore document fields to a Dart Map.
Map<String, dynamic> _convertFirestoreFields(Map<String, fs.Value> fields) {
  Map<String, dynamic> result = {};
  fields.forEach((key, value) {
    result[key] = _convertFromFirestoreValue(value);
  });
  return result;
}

/// Helper function to convert a Firestore Value to a native Dart type.
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
