// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCJycpIn0CzrANDmkUj2I2xok6BhMk-y8g',
    appId: '1:841314423983:web:526bf09989eb8eac73705a',
    messagingSenderId: '841314423983',
    projectId: 'appenitaxiusuarios',
    authDomain: 'appenitaxiusuarios.firebaseapp.com',
    storageBucket: 'appenitaxiusuarios.appspot.com',
    measurementId: 'G-40HG8NDJFY',
    databaseURL: 'https://appenitaxiusuarios-default-rtdb.firebaseio.com/', // Asegúrate de incluir esta línea
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCW9hcUNGcig9gaRzqY10RA7xj_Wv7lfKM',
    appId: '1:841314423983:android:cdc8f25b70c9991073705a',
    messagingSenderId: '841314423983',
    projectId: 'appenitaxiusuarios',
    storageBucket: 'appenitaxiusuarios.appspot.com',
    databaseURL: 'https://appenitaxiusuarios-default-rtdb.firebaseio.com/', // Asegúrate de incluir esta línea
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAKW6JX-rpTCKFiEGJ3fLTg9lzM0GMHV4k',
    appId: '1:841314423983:ios:30d0cf565ec1385573705a',
    messagingSenderId: '841314423983',
    projectId: 'appenitaxiusuarios',
    storageBucket: 'appenitaxiusuarios.appspot.com',
    iosBundleId: 'com.example.controlRoom',
    databaseURL: 'https://appenitaxiusuarios-default-rtdb.firebaseio.com/', // Asegúrate de incluir esta línea
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAKW6JX-rpTCKFiEGJ3fLTg9lzM0GMHV4k',
    appId: '1:841314423983:ios:30d0cf565ec1385573705a',
    messagingSenderId: '841314423983',
    projectId: 'appenitaxiusuarios',
    storageBucket: 'appenitaxiusuarios.appspot.com',
    iosBundleId: 'com.example.controlRoom',
    databaseURL: 'https://appenitaxiusuarios-default-rtdb.firebaseio.com/', // Asegúrate de incluir esta línea
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCJycpIn0CzrANDmkUj2I2xok6BhMk-y8g',
    appId: '1:841314423983:web:67f4c5d20bd10e4373705a',
    messagingSenderId: '841314423983',
    projectId: 'appenitaxiusuarios',
    authDomain: 'appenitaxiusuarios.firebaseapp.com',
    storageBucket: 'appenitaxiusuarios.appspot.com',
    measurementId: 'G-Z5C7K924QE',
    databaseURL: 'https://appenitaxiusuarios-default-rtdb.firebaseio.com/', // Asegúrate de incluir esta línea
  );
}