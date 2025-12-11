part of '../firebase_management.dart';

class FirebaseManagementAppDistribution {
  final FirebaseApiClient _client;

  FirebaseManagementAppDistribution._(this._client);

  /// Lists releases for the given Firebase app.
  Future<List<AppRelease>> listReleases(String projectNumber, String appId,
      {int pageSize = 100}) {
    return _client.list(
        'projects/$projectNumber/apps/$appId/releases', 'releases',
        pageSize: pageSize);
  }

  /// Gets a single release by its ID.
  Future<AppRelease> getRelease(
      String projectNumber, String appId, String releaseId) {
    return _client
        .get('projects/$projectNumber/apps/$appId/releases/$releaseId');
  }

  /// Updates a release with the specified fields (patch semantics).
  Future<AppRelease> updateRelease(
      String projectNumber, String appId, String releaseId,
      {String? releaseNotes}) {
    return _client
        .patch('projects/$projectNumber/apps/$appId/releases/$releaseId', {
      if (releaseNotes != null) 'releaseNotes': {'text': releaseNotes},
    });
  }

  /// Distributes a release to testers and/or groups.
  Future<void> distributeRelease(
      String projectNumber, String appId, String releaseId,
      {List<String>? testerEmails, List<String>? groupAliases}) async {
    await _client.post(
        'projects/$projectNumber/apps/$appId/releases/$releaseId:distribute', {
      if (testerEmails != null && testerEmails.isNotEmpty)
        'testerEmails': testerEmails,
      if (groupAliases != null && groupAliases.isNotEmpty)
        'groupAliases': groupAliases,
    });
  }

  /// Uploads a new release binary for the given Firebase app.
  ///
  /// [projectNumber] is the Firebase project number.
  /// [appId] is the Firebase app ID.
  /// [fileBytes] are the binary file contents to upload.
  /// [fileName] is the name of the file being uploaded.
  /// [releaseNotes] optional release notes for this release.
  ///
  /// Returns an [AppRelease] after the upload completes.
  Future<AppRelease> uploadRelease(String projectNumber, String appId,
      List<int> fileBytes, String fileName) async {
    // Use the upload endpoint with multipart
    final uploadClient = _client.withBaseUri(
        'https://firebaseappdistribution.googleapis.com/upload/v1/');

    var s = await uploadClient.uploadFile<Snapshot>(
      'projects/$projectNumber/apps/$appId/releases:upload',
      fileBytes,
      fileName,
    );

    return (await OperationPoller<Snapshot>(_client)
            .poll(s.child('name').as<String>()))
        .child('release')
        .as<AppRelease>();
  }
}

class AppRelease extends UnmodifiableSnapshotView {
  AppRelease(super.snapshot);

  String get name => get('name');

  ReleaseNotes? get releaseNotes => get('releaseNotes');

  String get displayVersion => get('displayVersion');

  String get buildVersion => get('buildVersion');

  DateTime get createTime => get('createTime');

  Uri get firebaseConsoleUri => get('firebaseConsoleUri');

  Uri get testingUri => get('testingUri');

  Uri get binaryDownloadUri => get('binaryDownloadUri');
}

class ReleaseNotes extends UnmodifiableSnapshotView {
  ReleaseNotes(super.snapshot);

  String? get text => get<String?>('text');
}

class AppReleaseUpdate {
  final String? displayVersion;
  final String? buildVersion;
  final String? releaseNotes;

  const AppReleaseUpdate({
    this.displayVersion,
    this.buildVersion,
    this.releaseNotes,
  });

  Map<String, dynamic> toJson() {
    return {
      if (displayVersion != null) 'displayVersion': displayVersion,
      if (buildVersion != null) 'buildVersion': buildVersion,
      if (releaseNotes != null) 'releaseNotes': {'text': releaseNotes},
    };
  }
}
