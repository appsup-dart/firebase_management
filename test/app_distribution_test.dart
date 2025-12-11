import 'package:firebase_management/src/api.dart';
import 'package:test/test.dart';

import 'mock_backend.dart';

void main() {
  final backend = MockBackend(shouldMock: true);
  final appDistribution = backend.client.appDistribution;
  const projectNumber = '967810674370';
  const appId = '1:967810674370:android:9f90dc2e58dfb96d6b155b';

  group('FirebaseManagementAppDistribution', () {
    group('listReleases', () {
      test('lists releases', () async {
        final releases =
            await appDistribution.listReleases(projectNumber, appId);

        expect(releases, isNotEmpty);
        for (var release in releases) {
          expect(release.name.split('/'), [
            'projects',
            projectNumber,
            'apps',
            appId,
            'releases',
            isNotEmpty,
          ]);
          expect(release.displayVersion, isNotEmpty);
        }
      });

      test('throws when app not found', () async {
        expect(
            () => appDistribution.listReleases(
                projectNumber, '1:967810674371:android:9f90dc2e58dfb96d6b155b'),
            throwsA(isA<FirebaseApiException>()
                .having((e) => e.status, 'status', 400)
                .having((e) => e.code, 'code', 'INVALID_ARGUMENT')));
      });

      test('throws when app not found', () async {
        expect(
            () => appDistribution.listReleases('unknown', appId),
            throwsA(isA<FirebaseApiException>()
                .having((e) => e.status, 'status', 400)
                .having((e) => e.code, 'code', 'INVALID_ARGUMENT')));
      });
    });

    group('getRelease', () {
      test('gets a single release', () async {
        final release = await appDistribution.getRelease(
            projectNumber, appId, '2ihsr3j631410');

        expect(release.buildVersion, '50766465');
        expect(release.displayVersion, '25.3.0-beta.1');
      });

      test('throws when missing', () async {
        expect(
            () => appDistribution.getRelease(projectNumber, appId, 'unknown'),
            throwsA(isA<FirebaseApiException>()
                .having((e) => e.status, 'status', 404)
                .having((e) => e.code, 'code', 'NOT_FOUND')));
      });
    });

    group('patchRelease', () {
      test('patches a release', () async {
        var releaseId = '7bdm21i5gk9b8';

        var r =
            await appDistribution.getRelease(projectNumber, appId, releaseId);

        final updated = await appDistribution.updateRelease(
          projectNumber,
          appId,
          releaseId,
          releaseNotes: 'Bug fixes',
        );

        expect(updated.releaseNotes?.text, 'Bug fixes');
        await appDistribution.updateRelease(
          projectNumber,
          appId,
          releaseId,
          releaseNotes: r.releaseNotes?.text ?? '',
        );
      });
    });

    group('distributeRelease', () {
      test('distributes a release', () async {
        await appDistribution.distributeRelease(
          projectNumber,
          appId,
          '7bdm21i5gk9b8',
          testerEmails: ['jane.doe@example.com'],
        );
      });
    });
  });
}
