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
  });
}

class _MockBackend {
  static const testToken = 'test-access-token';

  final List<Map<String, dynamic>> projects = [
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
    {
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

  http.Client get httpClient =>
      shouldMock ? http_testing.MockClient(_handleRequest) : http.Client();

  Future<http.Response> _handleRequest(http.Request request) async {
    final segments = request.url.pathSegments;

    switch (segments[1]) {
      case 'projects':
        if (segments.length == 2) {
          if (request.method == 'GET') {
            // List projects: GET /projects
            return _listResponse(request, projects);
          }
        } else if (segments.length == 3) {
          if (request.method == 'GET') {
            // Get project: GET /projects/{id}
            final id = segments.last;
            return _getResponse(request, projects, (p) => p['projectId'] == id);
          }
        }
    }
    return http.Response(json.encode({}), 404, request: request);
  }

  http.Response _getResponse(
      http.Request request,
      List<Map<String, dynamic>> elements,
      bool Function(Map<String, dynamic>) predicate) {
    try {
      return http.Response(json.encode(elements.firstWhere(predicate)), 200,
          request: request);
    } catch (e) {
      return http.Response(
          json.encode({
            'error': {
              'status': 'PERMISSION_DENIED',
              'message': 'Permission denied'
            }
          }),
          403,
          request: request);
    }
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
