import 'dart:convert';

import 'package:firebase_admin/firebase_admin.dart';
import 'operation.dart';
import 'package:snapshot/snapshot.dart';
import 'package:http/http.dart' as http;

import '../firebase_management.dart';

class FirebaseApiClient {
  static const firebaseApiOrigin = String.fromEnvironment('FIREBASE_API_URL',
      defaultValue: 'https://firebase.googleapis.com');

  static const version = 'v1beta1';

  static final decoder = SnapshotDecoder()
    ..register<Snapshot, FirebaseProjectMetadata>(
        (v) => FirebaseProjectMetadata(v))
    ..register<Snapshot, DefaultProjectResources>(
        (v) => DefaultProjectResources(v))
    ..register<Snapshot, CloudProjectInfo>((v) => CloudProjectInfo(v))
    ..register<Snapshot, AppMetadata>((v) => AppMetadata(v))
    ..register<Snapshot, Snapshot>((v) => v)
    ..register<Snapshot, AppConfigurationData>((v) => AppConfigurationData(v))
    ..register<Snapshot, OperationResult>((v) => OperationResult(v))
    ..register<Snapshot, AppAndroidShaData>((v) => AppAndroidShaData(v))
    ..register<String, ShaCertificateType>((v) => const {
          'SHA_1': ShaCertificateType.sha_1,
          'SHA_256': ShaCertificateType.sha_256,
        }[v]!)
    ..register<String, AppPlatform>((v) => const {
          'ANDROID': AppPlatform.android,
          'IOS': AppPlatform.ios,
          'WEB': AppPlatform.web,
        }[v]!)
    ..seal();

  final http.Client httpClient;

  final Credential credential;

  FirebaseApiClient(this.credential, {http.Client? httpClient})
      : httpClient = httpClient ?? http.Client();

  Future<T> get<T>(String path, {Map<String, String>? query}) async {
    var response = await httpClient.get(
        Uri.parse('$firebaseApiOrigin/$version/$path')
            .replace(queryParameters: query),
        headers: {
          'Authorization':
              'Bearer ${(await credential.getAccessToken()).accessToken}'
        });

    if (response.statusCode != 200) {
      var v = json.decode(response.body);
      throw FirebaseApiException(
          code: v['error']['status'],
          message: v['error']['message'],
          status: response.statusCode,
          request: response.request!);
    }

    return Snapshot.fromJson(json.decode(response.body), decoder: decoder)
        .as<T>();
  }

  Future<List<T>> list<T>(String path, String field,
      {int pageSize = 100}) async {
    var projects = <T>[];
    String? nextPageToken;

    do {
      var page = await get<Snapshot>(path, query: {
        'pageSize': '$pageSize',
        if (nextPageToken != null) 'nextPageToken': nextPageToken
      });
      projects.addAll(page.child(field).asList<T>() ?? []);
      nextPageToken = page.child('nextPageToken').as<String?>();
    } while (nextPageToken != null);

    return projects;
  }

  Future<T> post<T>(String path, Map<String, dynamic> body) async {
    var response =
        await httpClient.post(Uri.parse('$firebaseApiOrigin/$version/$path'),
            headers: {
              'Authorization':
                  'Bearer ${(await credential.getAccessToken()).accessToken}',
              'Content-Type': 'application/json'
            },
            body: json.encode(body));

    if (response.statusCode != 200) {
      var v = json.decode(response.body);
      throw FirebaseApiException(
          code: v['error']['status'],
          message: v['error']['message'],
          status: response.statusCode,
          request: response.request!);
    }

    return Snapshot.fromJson(json.decode(response.body), decoder: decoder)
        .as<T>();
  }
}

class FirebaseApiException extends FirebaseException {
  final http.BaseRequest request;

  final int status;

  FirebaseApiException(
      {required this.status,
      required String code,
      required String message,
      required this.request})
      : super(code: code, message: message);

  @override
  String toString() {
    return '${super.toString()} ($request)';
  }
}
