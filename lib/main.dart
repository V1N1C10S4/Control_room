import 'package:control_room/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:control_room/src/login_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Background message handler for FCM
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🛡 Inicializa App Check con reCAPTCHA v3
  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider('6LcoFxorAAAAANAQPpomjzPfyC6Bxx928CQvAzlE'),
  );

  // Configura handler para mensajes en segundo plano de FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Control Room',
      locale: Locale('es'),
      supportedLocales: [
        Locale('es'),
      ],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MyAppForm(),
    );
  }
}