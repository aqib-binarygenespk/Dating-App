import 'dart:io' show Platform;
import 'package:flutter/foundation.dart'; // kDebugMode, kReleaseMode
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:dating_app/routes/Routes.dart';
import 'package:dating_app/themesfolder/theme.dart';
import 'package:dating_app/hive_utils/hive_boxes.dart';
import 'package:dating_app/Dashbaord/chat/chat_services.dart';
import 'package:dating_app/Dashbaord/profile/profile_controller.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';

// ===== Dev toggles =====
const bool kForceAppCheckDebugOnIOS = true;
const bool kRunStorageProbesInDebug = false;

// Idempotent Firebase init (survives hot restart)
Future<FirebaseApp> ensureFirebaseInitialized() async {
  if (Firebase.apps.isEmpty) {
    return await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  return Firebase.app();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Hive ---
  await Hive.initFlutter();
  await Future.wait([
    Hive.openBox(HiveBoxes.userBox),
    Hive.openBox(HiveBoxes.chatBox),
    Hive.openBox(HiveBoxes.settingsBox),
  ]);

  // --- Firebase (idempotent) ---
  await ensureFirebaseInitialized();

  // --- App Check ---
  await _activateAppCheck();

  // --- Optional: debug storage probes ---
  if (kDebugMode && kRunStorageProbesInDebug) {
    final chatService = ChatService();
    try { await chatService.storageWriteProbe(); } catch (_) {}
    try { await chatService.storageHealthcheck(); } catch (_) {}
    assert(() { chatService.storageDualPing(); return true; }());
  }

  runApp(const MyApp());
}

Future<void> _activateAppCheck() async {
  try {
    if (Platform.isIOS) {
      await FirebaseAppCheck.instance.activate(
        appleProvider: (kForceAppCheckDebugOnIOS || !kReleaseMode)
            ? AppleProvider.debug
            : AppleProvider.appAttest,
      );
    } else if (Platform.isAndroid) {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kReleaseMode
            ? AndroidProvider.playIntegrity
            : AndroidProvider.debug,
      );
    } else {
      await FirebaseAppCheck.instance.activate();
    }
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);

    try {
      await FirebaseAppCheck.instance.getToken(true);
    } catch (e) {
      debugPrint('🪪 App Check getToken error (ok in debug): $e');
    }
  } catch (e) {
    debugPrint('⚠️ App Check activate failed: $e');
  }
}

// Global binding that conditionally wires ProfileController when a token exists.
class InitialBindings extends Bindings {
  @override
  void dependencies() {
    // If you have other singletons, register them here (e.g., services).

    // Create ProfileController only when we already have a saved token.
    final box = Hive.box(HiveBoxes.userBox);
    final token = box.get('auth_token') ?? box.get('token') ?? box.get('access_token');

    if (token != null && token.toString().trim().isNotEmpty) {
      // fenix:true => if disposed after Get.offAll, it will be recreated on demand by Get.find
      Get.lazyPut<ProfileController>(() => ProfileController(), fenix: true);
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'The PairUp',
      theme: AppTheme.themeData,
      initialRoute: '/SplashScreen',
      getPages: AppRoutes.routes,
      initialBinding: InitialBindings(),
    );
  }
}
