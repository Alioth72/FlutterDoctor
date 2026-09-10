// Generated for the shared SIH teleconsult Firebase project.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase is configured for Android only.');
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      _ => throw UnsupportedError(
        'Firebase is not configured for this platform.',
      ),
    };
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCuIamOiXGsM1BS9d-sjLDmb9bdcX-0WNI',
    appId: '1:119360388202:android:49006863c47c1f3a191e13',
    messagingSenderId: '119360388202',
    projectId: 'sih-teleconsultation',
    storageBucket: 'sih-teleconsultation.firebasestorage.app',
  );
}
