import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:poke_team_dex/firebase_options.dart';

// VAPID key from Firebase Console → Project Settings → Cloud Messaging
// → Web Push certificates → Generate key pair.
// Replace this placeholder before shipping.
const _vapidKey = 'BFO-cOPo8-ZOFk95-_PDxiXcQt-Epz8fVhjbc3QnyQrERTutZ4wGNl7BX8PhIbkfvcTFckYU4zrqZ0aU6idtk1w';

class FcmService {
  static Future<void> init() async {
    if (!isSupported) return;

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // Topic subscriptions work on Android, iOS and macOS.
    // Web does not support client-side topic subscriptions via the SDK.
    if (!kIsWeb) {
      await messaging.subscribeToTopic('app-updates');
    }

    // For web: get the registration token so it can be used for
    // direct messaging in the future (topic subscription requires
    // the backend to call Admin SDK subscribe_to_topic).
    if (kIsWeb) {
      try {
        await messaging.getToken(vapidKey: _vapidKey);
      } catch (_) {
        // Fails gracefully if VAPID key is not yet configured.
      }
    }
  }

  // FCM is supported on Android, iOS, macOS and Web.
  // Windows uses polling via the GitHub Releases API instead.
  static bool get isSupported {
    if (kIsWeb) return true;
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }
}
