import 'package:firebase_management/firebase_management.dart';

void main() async {
  // applicationDefault() will look for credentials in the following locations:
  // * the service-account.json file in the package main directory
  // * the env variable GOOGLE_APPLICATION_CREDENTIALS
  // * a configuration file, specific for this library, stored in the user's home directory
  // * gcloud's application default credentials
  var credential = Credentials.applicationDefault();

  // when no credentials found, login using openid
  // the credentials are stored on disk for later use
  credential ??= await Credentials.login();

  // create an instance of the FirebaseManagement class
  var firebaseManagement = FirebaseManagement(credential);

  // get the list of projects
  var projects = await firebaseManagement.projects.listFirebaseProjects();

  for (var p in projects) {
    print('${p.displayName} - ${p.projectId}');

    // get the list of apps
    var apps = await firebaseManagement.apps.listFirebaseApps(p.projectId);
    for (var a in apps) {
      print(
          '  ${a.platform.toString().substring('AppPlatform.'.length)} - ${a.displayName} - ${a.appId}');

      var config =
          await firebaseManagement.apps.getAppConfig(a.appId, a.platform);
      print(config.configFileContents);
      print(config.sdkConfig);
    }
    return;
  }
}
