// File generated-style placeholder for FlutterFire.
// Replace via: dart pub global activate flutterfire_cli && flutterfire configure
// Do not commit real production secrets beyond the usual public client config.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for the current platform.
///
/// Values below are **placeholders**. Replace them with output from
/// `flutterfire configure` (or copy from the Firebase console) before
/// talking to a real Firebase project. Emulator mode still needs a
/// syntactically valid options object to initialize.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS '
          '(Android-first prototype).',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macOS.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // PLACEHOLDER — replace with FlutterFire / Firebase console values.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_WITH_WEB_API_KEY',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'femm-prototype-REPLACE',
    authDomain: 'femm-prototype-REPLACE.firebaseapp.com',
    storageBucket: 'femm-prototype-REPLACE.appspot.com',
  );

  // PLACEHOLDER — replace with FlutterFire / Firebase console values.
  // Must match apps/mobile/android/app/google-services.json.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_WITH_ANDROID_API_KEY',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'femm-prototype-REPLACE',
    storageBucket: 'femm-prototype-REPLACE.appspot.com',
  );
}
