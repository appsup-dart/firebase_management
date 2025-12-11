import 'dart:async';

import 'package:firebase_management/src/api.dart';
import 'package:test/test.dart';

import 'mock_backend.dart';

void main() {
  var backend = MockBackend(shouldMock: true);

  var projects = backend.client.projects;

  var testProjectId = MockProjectsBackend.testProjectId;

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
        var availableProject =
            backend.availableProjects.availableProjects.first;
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
        try {
          await projects.addGoogleAnalytics(
            testProjectId,
            analyticsPropertyId: '516115643',
          );
        } catch (e) {
          //ignore
        }
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
        try {
          await projects.removeAnalytics(testProjectId);
        } catch (e) {
          //ignore
        }
        expect(
            () => projects.getAnalyticsDetails(testProjectId),
            throwsA(isA<FirebaseApiException>()
                .having((e) => e.status, 'status', 404)
                .having((e) => e.code, 'code', 'NOT_FOUND')));
      });

      test('throws when project not found', () async {
        expect(
            () => projects.getAnalyticsDetails('unknown'),
            throwsA(isA<FirebaseApiException>()
                .having((e) => e.status, 'status', 403)
                .having((e) => e.code, 'code', 'PERMISSION_DENIED')));
      });
    });

    group('removeAnalytics', () {
      test('removes analytics for project', () async {
        try {
          await projects.addGoogleAnalytics(
            testProjectId,
            analyticsPropertyId: '516115643',
          );
        } catch (e) {
          //ignore
        }

        await projects.removeAnalytics(testProjectId);

        expect(
            () => projects.getAnalyticsDetails(testProjectId),
            throwsA(isA<FirebaseApiException>()
                .having((e) => e.status, 'status', 404)
                .having((e) => e.code, 'code', 'NOT_FOUND')));
      });

      test('throws when no analytics', () async {
        try {
          await projects.removeAnalytics(testProjectId);
        } catch (e) {
          //ignore
        }
        expect(
            () => projects.removeAnalytics(testProjectId),
            throwsA(isA<FirebaseApiException>()
                .having((e) => e.status, 'status', 404)
                .having((e) => e.code, 'code', 'NOT_FOUND')));
      });

      test('throws when project not found', () async {
        expect(
            () => projects.removeAnalytics('unknown'),
            throwsA(isA<FirebaseApiException>()
                .having((e) => e.status, 'status', 403)
                .having((e) => e.code, 'code', 'PERMISSION_DENIED')));
      });
    });

    group('addGoogleAnalytics', () {
      test('adds analytics for project', () async {
        try {
          await projects.removeAnalytics(testProjectId);
          await Future.delayed(const Duration(seconds: 1));
        } catch (e) {
          //ignore
        }

        try {
          await projects.addGoogleAnalytics(testProjectId,
              analyticsPropertyId: '516115643');
        } on FirebaseOperationException catch (_) {
          // ignore
        }
        var result = await projects.getAnalyticsDetails(testProjectId);
        expect(result.analyticsProperty.id, isNotEmpty);
        expect(result.analyticsProperty.displayName, isNotEmpty);
        expect(result.analyticsProperty.analyticsAccountId, isNotEmpty);
      });

      test('throws when project not found', () async {
        expect(
            () => projects.addGoogleAnalytics('unknown',
                analyticsPropertyId: '516115643'),
            throwsA(isA<FirebaseApiException>()
                .having((e) => e.status, 'status', 403)
                .having((e) => e.code, 'code', 'PERMISSION_DENIED')));
      });

      test('throws when analytics property not found', () async {
        try {
          await projects.removeAnalytics(testProjectId);
          await Future.delayed(const Duration(seconds: 1));
        } catch (e) {
          //ignore
        }
        expect(
            () => projects.addGoogleAnalytics(testProjectId,
                analyticsPropertyId: 'unknown'),
            throwsA(isA<FirebaseApiException>()
                .having((e) => e.status, 'status', 400)
                .having((e) => e.code, 'code', 'INVALID_ARGUMENT')));
      });

      test('throws when analytics already added', () async {
        try {
          await projects.addGoogleAnalytics(
            testProjectId,
            analyticsPropertyId: '516115643',
          );
        } catch (e) {
          //ignore
        }
        expect(
            () => projects.addGoogleAnalytics('unknown',
                analyticsPropertyId: '516115643'),
            throwsA(isA<FirebaseApiException>()
                .having((e) => e.status, 'status', 403)
                .having((e) => e.code, 'code', 'PERMISSION_DENIED')));
      });
    });
  });
}
