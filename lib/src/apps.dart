part of firebase_management;

class FirebaseManagementApps {
  final FirebaseApiClient _client;

  FirebaseManagementApps._(this._client);

  /// Lists all Firebase apps registered in a Firebase project, optionally
  /// filtered by a platform.
  ///
  /// Repeatedly calls the paginated API until all pages have been read.
  Future<List<AppMetadata>> listFirebaseApps(String projectId,
      {AppPlatform platform = AppPlatform.any, int pageSize = 100}) async {
    return _client.list('projects/$projectId${_getSuffix(platform)}', 'apps');
  }

  /// Gets the configuration artifact associated with the specified a Firebase
  /// app.
  Future<AppConfigurationData> getAppConfig(
      String appId, AppPlatform platform) async {
    var s = await _client
        .get<Snapshot>('projects/-${_getSuffix(platform)}/$appId/config');
    if (platform == AppPlatform.web) {
      return AppConfigurationData(s.set(null).setPath('sdkConfig', s));
    }

    var contents =
        utf8.decode(base64.decode(s.child('configFileContents').as<String>()));

    s = s.setPath('configFileContents', contents);

    if (platform == AppPlatform.android) {
      return AppConfigurationData(s.setPath(
          'sdkConfig', _parseAndroidConfig(json.decode(contents), appId)));
    }

    return AppConfigurationData(s.setPath('sdkConfig',
        _parseIosConfig(PlistParser().parse(contents).cast(), appId)));
  }

  Map<String, String> _parseIosConfig(
      Map<String, dynamic> config, String appId) {
    return {
      'projectId': config['PROJECT_ID'],
      'messagingSenderId': config['GCM_SENDER_ID'],
      'databaseURL': config['DATABASE_URL'],
      'storageBucket': config['STORAGE_BUCKET'],
      'apiKey': config['API_KEY'],
      'appId': appId,
      'iosClientId': config['CLIENT_ID'],
    };
  }

  Map<String, String> _parseAndroidConfig(
      Map<String, dynamic> config, String appId) {
    var clients = config['client'] as List;
    var client = clients
        .firstWhere((c) => c['client_info']['mobilesdk_app_id'] == appId);

    var androidClient = (client['oauth_client'] as List).firstWhere(
        (element) => element['android_info'] != null,
        orElse: () => null);

    return {
      'projectId': config['project_info']['project_id'],
      'messagingSenderId': config['project_info']['project_number'],
      'databaseURL': config['project_info']['firebase_url'],
      'storageBucket': config['project_info']['storage_bucket'],
      'apiKey': (client['api_key'] as List).first['current_key'],
      'appId': appId,
      if (androidClient != null) 'androidClientId': androidClient['client_id'],
    };
  }

  String _getSuffix(AppPlatform platform) {
    switch (platform) {
      case AppPlatform.ios:
        return '/iosApps';
      case AppPlatform.android:
        return '/androidApps';
      case AppPlatform.web:
        return '/webApps';
      case AppPlatform.any:
      case AppPlatform.unspecified:
        return ':searchApps'; // List apps in any platform
    }
  }
}

class AppMetadata extends UnmodifiableSnapshotView {
  AppMetadata(Snapshot snapshot) : super(snapshot);

  String get name => get('name');

  String get projectId => get('projectId');

  String? get displayName => get('displayName');

  String get appId => get('appId');

  AppPlatform get platform => get('platform');

  String get namespace => get('namespace');

  String? get bundleId => get('bundleId');

  String? get appStoreId => get('appStoreId');

  String? get packageName => get('packageName');

  List<String>? get appUrls => getList('appUrls');
}

class AppConfigurationData extends AppMetadata {
  AppConfigurationData(Snapshot snapshot) : super(snapshot);

  String? get configFilename => get('configFilename');

  String? get configFileContents => get('configFileContents');

  Map<String, String> get sdkConfig => getMap<String>('sdkConfig')!;
}

class AppAndroidShaData extends UnmodifiableSnapshotView {
  AppAndroidShaData(Snapshot snapshot) : super(snapshot);

  String get name => get('name');

  String get shaHash => get('shaHash');

  ShaCertificateType get certType => ShaCertificateType.sha_1;

  Map<String, String>? get sdkConfig => getMap('sdkConfig');
}

enum AppPlatform {
  unspecified,
  android,
  ios,
  web,
  any,
}

enum ShaCertificateType {
  unspecified,
  sha_1,
  sha_256,
}
