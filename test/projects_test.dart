import 'dart:async';
import 'dart:convert';

import 'package:firebase_admin/firebase_admin.dart';
import 'package:firebase_management/firebase_management.dart';
import 'package:firebase_management/src/api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:test/test.dart';

const testProjectId = 'appsup-test';

void main() {
  var backend = _MockBackend(shouldMock: true);

  var projects = backend.client.projects;

  group('FirebaseManagementProjects', () {
    group('listFirebaseProjects', () {
      test('returns list of projects', () async {
        final result = await projects.listFirebaseProjects();

        expect(result, hasLength(greaterThan(5)));

        final project = result.firstWhere((e) => e.projectId == testProjectId);
        expect(project.projectId, testProjectId);
        expect(project.displayName, isNotEmpty);
        expect(project.state, 'ACTIVE');
        expect(project.name, 'projects/$testProjectId');
        expect(project.resources.hostingSite, testProjectId);
        expect(project.resources.realtimeDatabaseInstance, testProjectId);
        expect(project.resources.locationId, 'us-central');
        expect(project.resources.storageBucket, anything);
      });

      test('handles pagination', () async {
        final result1 = await projects.listFirebaseProjects(pageSize: 1);
        final result2 = await projects.listFirebaseProjects(pageSize: 10);

        expect(result1, hasLength(greaterThan(5)));
        expect(result2, hasLength(result1.length));
      });
    });

    group('listAvailableCloudProjects', () {
      test('returns available cloud projects', () async {
        final result = await projects.listAvailableCloudProjects(pageSize: 2);

        expect(result, hasLength(greaterThan(2)));
        for (var p in result) {
          expect(p.project, startsWith('projects/'));
          expect(p.displayName, isNotEmpty);
          expect(p.locationId, isIn(['us-central', 'europe-west1', null]));
        }
      });
    });

    group('getFirebaseProject', () {
      test('returns single project metadata', () async {
        final result = await projects.getFirebaseProject(testProjectId);

        expect(result.projectId, testProjectId);
        expect(result.name, 'projects/$testProjectId');
        expect(result.displayName, isNotEmpty);
        expect(result.resources.locationId, 'us-central');
      });

      test('throws FirebaseApiException when missing', () async {
        expect(
            () => projects.getFirebaseProject('unknown-project'),
            throwsA(isA<FirebaseApiException>()
                .having((e) => e.status, 'status', 403)
                .having((e) => e.code, 'code', 'PERMISSION_DENIED')));
      });
    });

    group('getAdminSdkConfig', () {
      test('returns admin sdk config', () async {
        final result = await projects.getAdminSdkConfig(testProjectId);

        expect(result.projectId, testProjectId);
        expect(result.databaseURL, 'https://$testProjectId.firebaseio.com');
        expect(result.storageBucket, '$testProjectId.appspot.com');
        expect(result.locationId, 'us-central');
      });

      test('throws when config missing', () async {
        expect(
            () => projects.getAdminSdkConfig('unknown'),
            throwsA(isA<FirebaseApiException>()
                .having((e) => e.status, 'status', 403)
                .having((e) => e.code, 'code', 'PERMISSION_DENIED')));
      });
    });

    group('addFirebase', () {
      test('polls operation and returns project', () async {
        if (!backend.shouldMock) {
          throw Skip('Skipping test in non-mock mode');
        }
        var availableProject = backend.availableProjects.first;
        var projectId = availableProject['project'].split('/').last;
        var displayName = availableProject['displayName'];

        final result = await projects.addFirebase(projectId);

        expect(result.projectId, projectId);
        expect(result.displayName, displayName);
        expect(result.resources.locationId, availableProject['locationId']);
      }, skip: !backend.shouldMock);

      test('throws when addFirebase not allowed', () async {
        expect(
            () => projects.addFirebase('unknown'),
            throwsA(isA<FirebaseApiException>()
                .having((e) => e.status, 'status', 403)
                .having((e) => e.code, 'code', 'PERMISSION_DENIED')));
      });
    });

    group('updateFirebaseProject', () {
      test('patches displayName and annotations', () async {
        var project = await projects.getFirebaseProject(testProjectId);

        try {
          final newName = 'Updated Name';
          final newAnnotations = {'k1': 'v1', 'k2': 'v2'};

          final result = await projects.updateFirebaseProject(testProjectId,
              displayName: newName, annotations: newAnnotations);

          expect(result.projectId, testProjectId);
          expect(result.displayName, newName);
          expect(result.annotations, isNotNull);
          expect(result.annotations, containsPair('k1', 'v1'));
          expect(result.annotations, containsPair('k2', 'v2'));
        } finally {
          if (!backend.shouldMock) {
            await projects.updateFirebaseProject(testProjectId,
                displayName: project.displayName,
                annotations: project.annotations ?? {});
          }
        }
      });

      test('throws when update not allowed', () async {
        expect(
            () => projects.updateFirebaseProject('unknown',
                displayName: 'x', annotations: {'k': 'v'}),
            throwsA(isA<FirebaseApiException>()
                .having((e) => e.status, 'status', 400)
                .having((e) => e.code, 'code', 'INVALID_ARGUMENT')));
      });
    });

    group('getAnalyticsDetails', () {
      test('returns analytics details', () async {
        final result = await projects.getAnalyticsDetails(testProjectId);

        expect(result.analyticsProperty.analyticsAccountId, isNotEmpty);
        expect(result.analyticsProperty.id, isNotEmpty);
        expect(result.streamMappings, isNotEmpty);
        for (var s in result.streamMappings) {
          expect(s.app, startsWith('projects/$testProjectId/'));
          expect(s.streamId, isNotEmpty);
          expect(
              s.measurementId, s.app.contains('webApps') ? isNotEmpty : isNull);
        }
      });

      test('throws when analytics not found', () async {
        expect(
            () => projects.getAnalyticsDetails('unknown'),
            throwsA(isA<FirebaseApiException>()
                .having((e) => e.status, 'status', 403)
                .having((e) => e.code, 'code', 'PERMISSION_DENIED')));
      });
    });
  });
}

class _MockBackend {
  static const testToken = 'test-access-token';

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

  final Map<String, Map<String, dynamic>> analytics = {
    testProjectId: {
      'analyticsProperty': {
        'id': 'GA-PROPERTY-456',
        'displayName': 'Test Property',
        'analyticsAccountId': 'GA-ACCOUNT-123',
      },
      'streamMappings': [
        {
          'app': 'projects/$testProjectId/androidApps/1234567890:android',
          'streamId': '1234567890',
        },
        {
          'app': 'projects/$testProjectId/webApps/1234567890:web',
          'streamId': '1234567890',
          'measurementId': 'G-1234567890',
        },
      ],
    },
  };

  final List<Map<String, Object>> projects = [
    ...List.generate(
        10,
        (index) => {
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
            }),
    {...testProject},
  ];

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

  final bool shouldMock;

  _MockBackend({this.shouldMock = true});

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
          } on Error catch (e) {
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
    final segments = request.url.pathSegments;

    switch (segments[1]) {
      case 'projects':
        if (segments.length == 2) {
          if (request.method == 'GET') {
            // List projects: GET /projects
            return _listResponse(request, projects);
          }
        } else if (segments.length == 3 && request.method == 'GET') {
          // Get project: GET /projects/{id}
          final id = segments.last;
          return _getResponse(
              request,
              () => projects.firstWhere((p) => p['projectId'] == id,
                  orElse: () => throw Error.permissionDenied));
        } else if (segments.length == 3 && request.method == 'PATCH') {
          // Update project: PATCH /projects/{id}
          final id = segments.last;
          final body = request.body.isNotEmpty
              ? json.decode(request.body)
              : <String, dynamic>{};

          var project = projects.firstWhere((p) => p['projectId'] == id,
              orElse: () => throw Error.invalidArgument);
          project.addAll({
            if (body['displayName'] != null) 'displayName': body['displayName'],
            if (body['annotations'] != null)
              'annotations': Map<String, String>.from(body['annotations']),
          });

          return _updateResponse(request, project);
        } else if (segments.length == 4 && request.method == 'GET') {
          final id = segments[2];
          switch (segments.last) {
            case 'adminSdkConfig':
              return _getResponse(
                  request,
                  () => id == testProjectId
                      ? testProjectAdminSdkConfig
                      : throw Error.permissionDenied);
            case 'analyticsDetails':
              return _getResponse(request,
                  () => analytics[id] ?? (throw Error.permissionDenied));
          }
        } else if (segments.length == 3 &&
            segments[2].endsWith(':addFirebase') &&
            request.method == 'POST') {
          final id = segments[2].split(':').first;
          final body = request.body.isNotEmpty ? json.decode(request.body) : {};
          // Only allow known project; otherwise permission denied
          return _startOperationResponse(request, () {
            var availableProject = availableProjects.firstWhere(
                (p) => p['project'].split('/').last == id,
                orElse: () => throw Error.permissionDenied);
            var projectId = availableProject['project'].split('/').last;
            var project = <String, Object>{
              'projectId': projectId,
              'name': 'projects/$projectId',
              'projectNumber': '123456789',
              'displayName': availableProject['displayName'],
              'state': 'ACTIVE',
              'resources': {
                'hostingSite': projectId,
                'realtimeDatabaseInstance': projectId,
                'locationId': body['locationId'] ??
                    availableProject['locationId'] ??
                    'us-central',
              },
              'etag': '1_abcdef1234567890',
            };

            return Future.delayed(const Duration(milliseconds: 100), () {
              projects.add(project);
              return project;
            });
          });
        }
        break;
      case 'availableProjects':
        if (segments.length == 2 && request.method == 'GET') {
          return _listAvailableResponse(request, availableProjects);
        }
        break;
      case 'operations':
        if (segments.length == 3 && request.method == 'GET') {
          return _pollOperationResponse(request, 'operations/${segments.last}');
        }
        break;
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
      http.Request request, List<Map<String, dynamic>> elements) {
    var pageSize = int.parse(request.url.queryParameters['pageSize'] ?? '100');
    var pageToken = int.parse(request.url.queryParameters['pageToken'] ?? '0');

    return http.Response(
        json.encode({
          'results': elements.skip(pageToken).take(pageSize).toList(),
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
    return http.Response(
        json.encode({
          'name': operationName,
          'done': completer.isCompleted,
          if (completer.isCompleted) 'response': await completer.future
        }),
        200,
        request: request);
  }

  http.Response _listAvailableResponse(
      http.Request request, List<Map<String, dynamic>> elements) {
    var pageSize = int.parse(request.url.queryParameters['pageSize'] ?? '100');
    var pageToken = int.parse(request.url.queryParameters['pageToken'] ?? '0');

    return http.Response(
        json.encode({
          'projectInfo': elements.skip(pageToken).take(pageSize).toList(),
          'nextPageToken': (pageToken + pageSize) < elements.length
              ? (pageToken + pageSize).toString()
              : null,
        }),
        200,
        request: request);
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
