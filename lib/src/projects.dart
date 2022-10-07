part of firebase_management;

class FirebaseManagementProjects {
  final FirebaseApiClient firebaseAPIClient;

  FirebaseManagementProjects._(this.firebaseAPIClient);

  /// Lists all Firebase projects associated with the currently logged-in
  /// account.
  Future<List<FirebaseProjectMetadata>> listFirebaseProjects(
      {int pageSize = 100}) async {
    return firebaseAPIClient.list('projects', 'results');
  }

  /// Gets the Firebase project information identified by the specified project
  /// ID
  Future<FirebaseProjectMetadata> getFirebaseProject(String projectId) async {
    return firebaseAPIClient
        .get<FirebaseProjectMetadata>('projects/$projectId');
  }

  /// Lists all Google Cloud Platform projects that are available to have
  /// Firebase resources added.
  Future<List<CloudProjectInfo>> listAvailableCloudProjects(
      {int pageSize = 100}) {
    return firebaseAPIClient.list('availableProjects', 'projectInfo');
  }
}

class CloudProjectInfo extends UnmodifiableSnapshotView {
  CloudProjectInfo(Snapshot snapshot) : super(snapshot);

  String get project => get<String>('project');

  String? get displayName => get<String?>('displayName');

  String? get locationId => get<String?>('locationId');
}

class FirebaseProjectMetadata extends UnmodifiableSnapshotView {
  FirebaseProjectMetadata(Snapshot snapshot) : super(snapshot);

  String get projectId => get('projectId');

  String get name => get('name');

  String get projectNumber => get('projectNumber');

  String get displayName => get('displayName');

  String get state => get('state');

  DefaultProjectResources get resources => get('resources')!;
}

class DefaultProjectResources extends UnmodifiableSnapshotView {
  DefaultProjectResources(Snapshot snapshot) : super(snapshot);

  String? get hostingSite => get('hostingSite');

  String? get realtimeDatabaseInstance => get('realtimeDatabaseInstance');

  String? get storageBucket => get('storageBucket');

  String? get locationId => get('locationId');
}
