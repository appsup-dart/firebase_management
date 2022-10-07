library firebase_management;

import 'dart:convert';

import 'package:firebase_admin/firebase_admin.dart';
import 'package:firebase_management/src/api.dart';
import 'package:plist_parser/plist_parser.dart';

import 'package:snapshot/snapshot.dart';

export 'package:firebase_admin/firebase_admin.dart'
    show Credential, Credentials;

part 'src/projects.dart';
part 'src/apps.dart';

class FirebaseManagement {
  final FirebaseApiClient _client;

  FirebaseManagement(Credential credential)
      : _client = FirebaseApiClient(credential);

  FirebaseManagementProjects get projects =>
      FirebaseManagementProjects._(_client);

  FirebaseManagementApps get apps => FirebaseManagementApps._(_client);
}
