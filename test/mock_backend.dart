import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_admin/firebase_admin.dart';
import 'package:firebase_management/firebase_management.dart';
import 'package:firebase_management/src/operation.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;

class MockProjectsBackend {
  static const testProjectId = 'appsup-test';

  static const testProject = {
    'projectId': testProjectId,
    'name': 'projects/$testProjectId',
    'projectNumber': '123456789',
    'displayName': 'Test Project',
    'state': 'ACTIVE',
    'resources': {
      'hostingSite': testProjectId,
      'realtimeDatabaseInstance': testProjectId,
      'locationId': 'us-central',
    },
    'etag': '1_abcdef1234567890',
  };

  static const testProjectAdminSdkConfig = {
    'projectId': testProjectId,
    'databaseURL': 'https://$testProjectId.firebaseio.com',
    'storageBucket': '$testProjectId.appspot.com',
    'locationId': 'us-central',
  };

  final Map<String, Map<String, Object>> projects = {
    for (var index = 0; index < 10; index++)
      'project-$index': {
        'projectId': 'project-$index',
        'name': 'projects/project-$index',
        'projectNumber': '123456789',
        'displayName': 'Project $index',
        'state': 'ACTIVE',
        'resources': {
          'hostingSite': 'project-$index',
          'realtimeDatabaseInstance': 'project-$index',
          'locationId': 'us-central',
        },
        'etag': '1_abcdef1234567890',
      },
    testProjectId: {...testProject},
  };

  final Map<String, Map<String, Object>> analytics = {};

  final MockBackend backend;

  MockProjectsBackend(this.backend);

  Map<String, Object> getProject(String projectId,
          {Error error = Error.permissionDenied}) =>
      projects[projectId] ?? (throw error);

  Future<http.Response> _handleRequest(http.Request request) async {
    if (request.method == 'GET') {
      return _handleGetRequest(request);
    } else if (request.method == 'PATCH') {
      return _handlePatchRequest(request);
    } else if (request.method == 'POST') {
      return _handlePostRequest(request);
    }
    throw Error.notFound;
  }

  Future<http.Response> _handleGetRequest(http.Request request) async {
    final segments = request.url.pathSegments;

    if (segments.length == 2) {
      return backend._listResponse(
          request, 'results', projects.values.toList());
    } else if (segments.length == 3) {
      // Get project: GET /projects/{id}
      final id = segments.last;
      return backend._getResponse(request, () => getProject(id));
    } else if (segments.length == 4) {
      final id = segments[2];
      switch (segments.last) {
        case 'adminSdkConfig':
          return backend._getResponse(
              request,
              () => id == testProjectId
                  ? testProjectAdminSdkConfig
                  : throw Error.permissionDenied);
        case 'analyticsDetails':
          return backend._getResponse(
              request,
              () => [getProject(id), analytics[id] ?? (throw Error.notFound)]
                  .last);
      }
    }
    throw Error.notFound;
  }

  Future<http.Response> _handlePatchRequest(http.Request request) async {
    final segments = request.url.pathSegments;

    if (segments.length == 3) {
      // Update project: PATCH /projects/{id}
      final id = segments.last;
      final body = request.body.isNotEmpty
          ? json.decode(request.body)
          : <String, dynamic>{};

      var project = getProject(id, error: Error.invalidArgument);
      project.addAll({
        if (body['displayName'] != null) 'displayName': body['displayName'],
        if (body['annotations'] != null)
          'annotations': Map<String, String>.from(body['annotations']),
      });

      return backend._updateResponse(request, project);
    }
    throw Error.notFound;
  }

  Future<http.Response> _handlePostRequest(http.Request request) async {
    final segments = request.url.pathSegments;
    var operation = segments.last.split(':').last;
    final id = segments.last.split(':').first;

    switch (operation) {
      case 'addFirebase':
        final body = request.body.isNotEmpty ? json.decode(request.body) : {};
        // Only allow known project; otherwise permission denied
        return backend._startOperationResponse(request, () {
          var availableProject = backend.availableProjects.getProject(id);
          var project = <String, Object>{
            'projectId': id,
            'name': 'projects/$id',
            'projectNumber': '123456789',
            'displayName': availableProject['displayName'],
            'state': 'ACTIVE',
            'resources': {
              'hostingSite': id,
              'realtimeDatabaseInstance': id,
              'locationId': body['locationId'] ??
                  availableProject['locationId'] ??
                  'us-central',
            },
            'etag': '1_abcdef1234567890',
          };

          return Future.delayed(const Duration(milliseconds: 100), () {
            projects[id] = project;
            return project;
          });
        });
      case 'addGoogleAnalytics':
        getProject(id);
        if (analytics.containsKey(id)) throw Error.invalidArgument;

        var body = request.body.isNotEmpty ? json.decode(request.body) : {};
        var analyticsPropertyId = body['analyticsPropertyId'];

        if (analyticsPropertyId != '516115643') throw Error.invalidArgument;

        return backend._startOperationResponse(request, () async {
          var v = {
            'analyticsProperty': {
              'id': 'GA-PROPERTY-456',
              'displayName': 'Test Property',
              'analyticsAccountId': 'GA-ACCOUNT-123',
            },
            'streamMappings': [
              {
                'app': 'projects/$id/androidApps/1234567890:android',
                'streamId': '1234567890',
              },
              {
                'app': 'projects/$id/webApps/1234567890:web',
                'streamId': '1234567890',
                'measurementId': 'G-1234567890',
              },
            ],
          };
          analytics[id] = v;
          return v;
        });
      case 'removeAnalytics':
        getProject(id);

        if (!analytics.containsKey(id)) throw Error.notFound;

        analytics.remove(id);

        return http.Response(json.encode({}), 200, request: request);
      default:
        throw Error.notFound;
    }
  }
}

class MockAvailableProjectsBackend {
  final List<Map<String, dynamic>> availableProjects = [
    {
      'project': 'projects/available-1',
      'displayName': 'Available One',
      'locationId': 'us-central',
    },
    {
      'project': 'projects/available-2',
      'displayName': 'Available Two',
      'locationId': 'europe-west1',
    },
    {
      'project': 'projects/available-3',
      'displayName': 'Available Three',
      'locationId': null,
    },
  ];

  final MockBackend backend;

  MockAvailableProjectsBackend(this.backend);

  Map<String, dynamic> getProject(String projectId) =>
      availableProjects.firstWhere(
          (p) => p['project'].split('/').last == projectId,
          orElse: () => throw Error.permissionDenied);

  http.Response _handleRequest(http.Request request) {
    final segments = request.url.pathSegments;
    if (segments.length == 2 && request.method == 'GET') {
      return backend._listResponse(request, 'projectInfo', availableProjects);
    }
    throw Error.notFound;
  }
}

class MockAppBackend {
  final MockBackend backend;

  final Map<String, Map<String, dynamic>> apps = {
    'projects/967810674370/apps/1:967810674370:android:9f90dc2e58dfb96d6b155b':
        {
      'name':
          'projects/967810674370/apps/1:967810674370:android:9f90dc2e58dfb96d6b155b',
      'displayName': 'Test App',
      'platform': 'android',
      'appId': '1:967810674370:android:9f90dc2e58dfb96d6b155b',
    },
  };

  MockAppBackend(this.backend);

  Map<String, dynamic> getApp(String appId, {Error error = Error.notFound}) =>
      apps[appId] ?? (throw error);
}

class MockAppDistributionBackend {
  final MockBackend backend;

  final Map<String, List<Map<String, dynamic>>> releasesByAppId = {
    'projects/967810674370/apps/1:967810674370:android:9f90dc2e58dfb96d6b155b':
        [
      {
        'name':
            'projects/967810674370/apps/1:967810674370:android:9f90dc2e58dfb96d6b155b/releases/2ihsr3j631410',
        'displayVersion': '25.3.0-beta.1',
        'buildVersion': '50766465',
        'releaseNotes': {'text': 'Initial release'},
        'createTime': '2024-01-01T00:00:00Z',
        'firebaseConsoleUri': 'https://console.firebase.google.com/app-1',
        'testingUri': 'https://appdistribution.firebase.google.com/app-1',
        'binaryDownloadUri': 'https://download.firebase.com/app-1',
      },
      {
        'name':
            'projects/967810674370/apps/1:967810674370:android:9f90dc2e58dfb96d6b155b/releases/7bdm21i5gk9b8',
        'displayVersion': '25.3.0-beta.1',
        'buildVersion': '50766465',
        'releaseNotes': {'text': 'Initial release'},
        'createTime': '2024-01-01T00:00:00Z',
        'firebaseConsoleUri': 'https://console.firebase.google.com/app-1',
        'testingUri': 'https://appdistribution.firebase.google.com/app-1',
        'binaryDownloadUri': 'https://download.firebase.com/app-1',
      },
    ],
  };

  MockAppDistributionBackend(this.backend);

  Map<String, dynamic> _getApp(Uri url) {
    var segments = url.pathSegments;
    // Handle upload path: /upload/v1/projects/.../apps/...
    // or regular path: /v1/projects/.../apps/...
    var skip = segments.first == 'upload' ? 2 : 1;
    return backend.apps.getApp(segments.skip(skip).take(4).join('/'),
        error: Error.invalidArgument);
  }

  Future<http.Response> _handleGetRequest(http.Request request) async {
    var app = _getApp(request.url);
    var segments = request.url.pathSegments;
    var releases = releasesByAppId[app['name']] ?? [];
    if (segments.length == 6 && segments.last == 'releases') {
      return backend._listResponse(request, 'releases', releases);
    } else if (segments.length == 7) {
      switch (segments[5]) {
        case 'releases':
          var releaseId = segments[6];
          return backend._getResponse(
              request,
              () => releases.firstWhere(
                  (r) => r['name'].toString().endsWith('/$releaseId'),
                  orElse: () => throw Error.notFound));
      }
    }
    throw Error.notFound;
  }

  Future<http.Response> _handlePatchRequest(http.Request request) async {
    var app = _getApp(request.url);
    var segments = request.url.pathSegments;
    if (segments.length == 7 && segments[5] == 'releases') {
      final body = request.body.isNotEmpty
          ? json.decode(request.body) as Map<String, dynamic>
          : <String, dynamic>{};
      var releases = releasesByAppId[app['name']] ?? [];
      var releaseId = segments[6];
      var release = releases.firstWhere(
          (r) => r['name'].toString().endsWith('/$releaseId'),
          orElse: () => throw Error.notFound);
      release.addAll({
        if (body['displayVersion'] != null)
          'displayVersion': body['displayVersion'],
        if (body['buildVersion'] != null) 'buildVersion': body['buildVersion'],
        if (body['releaseNotes'] != null) 'releaseNotes': body['releaseNotes'],
      });
      return backend._updateResponse(request, release);
    }
    throw Error.notFound;
  }

  Future<http.Response> _handlePostRequest(http.Request request) async {
    var segments = request.url.pathSegments;
    var app = _getApp(request.url);
    var operation = segments.last.split(':').last;

    // Handle multipart upload for releases:upload
    if (operation == 'upload') {
      // Create a new release from the upload
      return backend._startOperationResponse(request, () async {
        await Future.delayed(const Duration(milliseconds: 100));
        throw OperationError.invalidApkOrIpa;
      });
    }

    if (segments.length == 7 && segments[5] == 'releases') {
      final releaseId = segments[6].split(':').first;
      releasesByAppId[app['name']]?.firstWhere(
          (r) => r['name'].toString().endsWith('/$releaseId'),
          orElse: () => throw Error.notFound);
      switch (operation) {
        case 'distribute':
          return http.Response(json.encode({}), 200, request: request);
      }
    }
    throw Error.notFound;
  }

  Future<http.Response> _handleRequest(http.Request request) {
    switch (request.method) {
      case 'GET':
        return _handleGetRequest(request);
      case 'PATCH':
        return _handlePatchRequest(request);
      case 'POST':
        return _handlePostRequest(request);
    }
    throw Error.notFound;
  }
}

class MockBackend {
  static const testToken = 'test-access-token';

  final bool shouldMock;

  late final MockProjectsBackend projects = MockProjectsBackend(this);
  late final MockAvailableProjectsBackend availableProjects =
      MockAvailableProjectsBackend(this);
  late final MockAppDistributionBackend appDistribution =
      MockAppDistributionBackend(this);
  late final MockAppBackend apps = MockAppBackend(this);

  MockBackend({this.shouldMock = true});

  FirebaseManagement get client => shouldMock
      ? FirebaseManagement(
          _MockCredential(testToken),
          httpClient: httpClient,
        )
      : FirebaseManagement(Credentials.applicationDefault()!);

  http.Client get httpClient => shouldMock
      ? http_testing.MockClient((request) async {
          try {
            return await _handleRequest(request);
          } on Error catch (e, tr) {
            print(tr);
            return http.Response(
                json.encode({
                  'error': {'status': e.code, 'message': e.message}
                }),
                e.status,
                request: request);
          }
        })
      : http.Client();

  Future<http.Response> _handleRequest(http.Request request) async {
    var segments = request.url.pathSegments;
    if (segments[1] == 'operations') {
      if (segments.length == 3 && request.method == 'GET') {
        return _pollOperationResponse(request, 'operations/${segments.last}');
      }
    }
    switch (request.url.host) {
      case 'firebase.googleapis.com':
        switch (segments[1]) {
          case 'projects':
            if (segments.contains('apps')) {
              return appDistribution._handleRequest(request);
            }
            return projects._handleRequest(request);
          case 'availableProjects':
            return availableProjects._handleRequest(request);
        }
        break;
      case 'firebaseappdistribution.googleapis.com':
        // Handle upload endpoint separately
        if (segments.isNotEmpty && segments[0] == 'upload') {
          return appDistribution._handleRequest(request);
        }
        return appDistribution._handleRequest(request);
    }

    return http.Response(json.encode({}), 404, request: request);
  }

  http.Response _updateResponse(
      http.Request request, Map<String, dynamic> updated) {
    return http.Response(json.encode(updated), 200, request: request);
  }

  http.Response _getResponse(
      http.Request request, Map<String, dynamic> Function() callback) {
    return http.Response(json.encode(callback()), 200, request: request);
  }

  http.Response _listResponse(
      http.Request request, String field, List<Map<String, dynamic>> elements) {
    var pageSize = int.parse(request.url.queryParameters['pageSize'] ?? '100');
    var pageToken = int.parse(request.url.queryParameters['pageToken'] ?? '0');

    return http.Response(
        json.encode({
          field: elements.skip(pageToken).take(pageSize).toList(),
          'nextPageToken': (pageToken + pageSize) < elements.length
              ? (pageToken + pageSize).toString()
              : null,
        }),
        200,
        request: request);
  }

  final Map<String, Completer<Map<String, dynamic>>> _operations = {};

  Future<http.Response> _startOperationResponse(
      http.Request request, Future<Map<String, dynamic>> Function() operation) {
    String operationName =
        'operations/${DateTime.now().millisecondsSinceEpoch}';

    _operations[operationName] = Completer()..complete(operation());

    return _pollOperationResponse(request, operationName);
  }

  Future<http.Response> _pollOperationResponse(
      http.Request request, String operationName) async {
    var completer = _operations[operationName];
    if (completer == null) {
      throw Error.notFound;
    }
    try {
      return http.Response(
          json.encode({
            'name': operationName,
            'done': completer.isCompleted,
            if (completer.isCompleted) 'response': await completer.future
          }),
          200,
          request: request);
    } on OperationError catch (e) {
      return http.Response(
          json.encode({
            'name': operationName,
            'done': completer.isCompleted,
            'error': {'code': e.code, 'message': e.message}
          }),
          200,
          request: request);
    }
  }
}

class _MockCredential implements Credential {
  _MockCredential(this._token);

  final String _token;

  @override
  Future<AccessToken> getAccessToken() async =>
      _MockAccessToken(_token, DateTime.now().add(const Duration(hours: 1)));
}

class _MockAccessToken extends AccessToken {
  _MockAccessToken(this.accessToken, this.expirationTime);

  @override
  final String accessToken;

  @override
  final DateTime expirationTime;
}

enum Error {
  permissionDenied(403, 'PERMISSION_DENIED', 'Permission denied'),
  notFound(404, 'NOT_FOUND', 'Not found'),
  invalidArgument(400, 'INVALID_ARGUMENT', 'Invalid argument');

  final String message;
  final String code;
  final int status;

  const Error(this.status, this.code, this.message);
}

enum OperationError {
  invalidApkOrIpa(3, 'Invalid APK or IPA file');

  final int code;
  final String message;

  const OperationError(this.code, this.message);
}
