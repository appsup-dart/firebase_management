[![Ceasefire Now](https://badge.techforpalestine.org/default)](https://techforpalestine.org/learn-more)

[:heart: sponsor](https://github.com/sponsors/rbellens)




Tools for managing firebase projects




## Usage

```dart

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
    }
  }
```


## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/appsup-dart/firebase_management/issues


## Sponsor

Creating and maintaining this package takes a lot of time. If you like the result, please consider to [:heart: sponsor](https://github.com/sponsors/rbellens). 
With your support, I will be able to further improve and support this project.
Also, check out my other dart packages at [pub.dev](https://pub.dev/packages?q=publisher%3Aappsup.be).



