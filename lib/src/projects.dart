part of '../firebase_management.dart';

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

  /// Gets the configuration artifact associated with the specified
  /// FirebaseProject, which can be used by servers to simplify initialization.
  ///
  /// Typically, this configuration is used with the Firebase Admin SDK
  /// initializeApp command.
  Future<AdminSdkConfig> getAdminSdkConfig(String projectId) async {
    return firebaseAPIClient
        .get<AdminSdkConfig>('projects/$projectId/adminSdkConfig');
  }
}

class CloudProjectInfo extends UnmodifiableSnapshotView {
  CloudProjectInfo(super.snapshot);

  String get project => get<String>('project');

  String? get displayName => get<String?>('displayName');

  String? get locationId => get<String?>('locationId');
}

class FirebaseProjectMetadata extends UnmodifiableSnapshotView {
  FirebaseProjectMetadata(super.snapshot);

  String get projectId => get('projectId');

  String get name => get('name');

  String get projectNumber => get('projectNumber');

  String get displayName => get('displayName');

  String get state => get('state');

  DefaultProjectResources get resources => get('resources')!;
}

class DefaultProjectResources extends UnmodifiableSnapshotView {
  DefaultProjectResources(super.snapshot);

  String? get hostingSite => get('hostingSite');

  String? get realtimeDatabaseInstance => get('realtimeDatabaseInstance');

  String? get storageBucket => get('storageBucket');

  String? get locationId => get('locationId');
}

class AdminSdkConfig extends UnmodifiableSnapshotView {
  AdminSdkConfig(super.snapshot);

  /// A user-assigned unique identifier for the FirebaseProject.
  ///
  /// This identifier may appear in URLs or names for some Firebase resources
  /// associated with the Project, but it should generally be treated as a
  /// convenience alias to reference the Project.
  String get projectId => get('projectId');

  /// The default Firebase Realtime Database URL.
  String? get databaseURL => get('databaseURL');

  /// The default Cloud Storage for Firebase storage bucket name.
  String? get storageBucket => get('storageBucket');

  /// The ID of the Project's default GCP resource location.
  ///
  /// The location is one of the available GCP resource locations.
  ///
  /// This field is omitted if the default GCP resource location has not been
  /// finalized yet. To set a Project's default GCP resource location, call
  /// defaultLocation.finalize after you add Firebase resources to the Project.
  String? get locationId => get('locationId');
}
