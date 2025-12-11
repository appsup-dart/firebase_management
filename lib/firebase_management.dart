library;

import 'dart:convert';

import 'package:firebase_admin/firebase_admin.dart';
import 'package:firebase_management/src/api.dart';
import 'package:http/http.dart' as http;
import 'package:plist_parser/plist_parser.dart';

import 'package:snapshot/snapshot.dart';

import 'src/operation.dart';

export 'package:firebase_admin/firebase_admin.dart'
    show Credential, Credentials;

part 'src/projects.dart';
part 'src/apps.dart';

class FirebaseManagement {
  final FirebaseApiClient _client;

  FirebaseManagement(Credential credential, {http.Client? httpClient})
      : _client = FirebaseApiClient(credential, httpClient: httpClient);

  FirebaseManagementProjects get projects =>
      FirebaseManagementProjects._(_client);

  FirebaseManagementApps get apps => FirebaseManagementApps._(_client);
}
