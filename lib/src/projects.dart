part of '../firebase_management.dart';

class FirebaseManagementProjects {
  final FirebaseApiClient firebaseAPIClient;

  FirebaseManagementProjects._(this.firebaseAPIClient);

  /// Lists all Firebase projects associated with the currently logged-in
  /// account.
  Future<List<FirebaseProjectMetadata>> listFirebaseProjects(
      {int pageSize = 100}) async {
    return firebaseAPIClient.list('projects', 'results', pageSize: pageSize);
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
    return firebaseAPIClient.list('availableProjects', 'projectInfo',
        pageSize: pageSize);
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

  /// Returns the Google Analytics details associated with the Firebase project.
  Future<AnalyticsDetails> getAnalyticsDetails(String projectId) async {
    return firebaseAPIClient
        .get<AnalyticsDetails>('projects/$projectId/analyticsDetails');
  }

  /// Removes the Google Analytics association from the Firebase project.
  Future<void> removeAnalytics(String projectId,
      {String? analyticsPropertyId}) async {
    await firebaseAPIClient
        .post<Snapshot>('projects/$projectId:removeAnalytics', {
      if (analyticsPropertyId != null)
        'analyticsPropertyId': analyticsPropertyId,
    });
  }

  Future<AnalyticsDetails> addGoogleAnalytics(String projectId,
      {String? analyticsPropertyId, String? analyticsAccountId}) async {
    var s = await firebaseAPIClient
        .post<Snapshot>('projects/$projectId:addGoogleAnalytics', {
      if (analyticsPropertyId != null)
        'analyticsPropertyId': analyticsPropertyId,
      if (analyticsAccountId != null) 'analyticsAccountId': analyticsAccountId,
    });

    return OperationPoller<AnalyticsDetails>(firebaseAPIClient)
        .poll(s.child('name').as<String>());
  }

  /// Adds Firebase services to an existing Google Cloud Platform project.
  ///
  /// The specified project becomes a Firebase project, and Firebase services
  /// become available for the project.
  ///
  /// [projectId] is the project ID of the Google Cloud Platform project to
  /// which Firebase services will be added.
  ///
  /// [locationId] is deprecated and should not be used.
  ///
  /// Returns a [FirebaseProjectMetadata] after the operation completes.
  Future<FirebaseProjectMetadata> addFirebase(String projectId,
      {@Deprecated('This parameter is deprecated in the Firebase API')
      String? locationId}) async {
    var s = await firebaseAPIClient
        .post<Snapshot>('projects/$projectId:addFirebase', {
      if (locationId != null) 'locationId': locationId,
    });

    return OperationPoller<FirebaseProjectMetadata>(firebaseAPIClient)
        .poll(s.child('name').as<String>());
  }

  /// Updates the attributes of the specified Firebase project.
  ///
  /// All attributes specified in the update mask are replaced in the Firebase
  /// project by the values of the attributes provided. Attributes not specified
  /// in the update mask are not affected.
  ///
  /// [projectId] is the project ID of the Firebase project to update.
  ///
  /// [displayName] is the user-assigned display name of the Firebase project.
  ///
  /// [annotations] are user-defined key-value pairs intended for developers and
  /// client-side tools. They are not modified by Firebase services.
  Future<FirebaseProjectMetadata> updateFirebaseProject(String projectId,
      {String? displayName, Map<String, String>? annotations}) async {
    return firebaseAPIClient
        .patch<FirebaseProjectMetadata>('projects/$projectId', {
      if (displayName != null) 'displayName': displayName,
      if (annotations != null) 'annotations': annotations,
    });
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

  /// User-defined key-value pairs intended for developers and client-side tools.
  /// These annotations are not modified by Firebase services.
  Map<String, String>? get annotations => getMap<String>('annotations');
}

class AnalyticsDetails extends UnmodifiableSnapshotView {
  AnalyticsDetails(super.snapshot);

  AnalyticsProperty get analyticsProperty => get('analyticsProperty');

  List<StreamMapping> get streamMappings => getList('streamMappings')!;
}

/// Details of a Google Analytics property
class AnalyticsProperty extends UnmodifiableSnapshotView {
  AnalyticsProperty(super.snapshot);

  /// The globally unique, Google-assigned identifier of the Google Analytics
  /// property associated with the specified FirebaseProject.
  String get id => get('id');

  /// The user-assigned display name of the Google Analytics property associated
  /// with the specified FirebaseProject.
  String get displayName => get('displayName');

  /// The ID of the Google Analytics account for the Google Analytics property
  /// associated with the specified FirebaseProject.
  String get analyticsAccountId => get('analyticsAccountId');
}

/// A mapping of a Firebase App to a Google Analytics data stream
class StreamMapping extends UnmodifiableSnapshotView {
  StreamMapping(super.snapshot);

  /// The resource name of the Firebase App associated with the Google Analytics
  /// data stream.
  ///
  /// Format: projects/{projectId}/{android/ios/web}Apps/{appId}
  String get app => get('app');

  /// The unique Google-assigned identifier of the Google Analytics data stream
  /// associated with the Firebase App.
  ///
  /// Format: int64
  String get streamId => get('streamId');

  /// The unique Google-assigned identifier of the Google Analytics web stream
  /// associated with the Firebase Web App.
  ///
  /// Firebase SDKs use this ID to interact with Google Analytics APIs.
  ///
  /// Applicable for Firebase Web Apps only.
  String? get measurementId => get('measurementId');
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
