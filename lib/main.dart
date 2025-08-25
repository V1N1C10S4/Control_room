import 'package:control_room/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:control_room/src/login_screen.dart';
import 'package:control_room/src/home_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:web/web.dart' as html;

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

  // Inicializa App Check
  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider('6LcoFxorAAAAANAQPpomjzPfyC6Bxx928CQvAzlE'),
  );

  // Configura FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Widget _initialScreen() {
    final usuario = html.window.sessionStorage.getItem('usuario');
    final region = html.window.sessionStorage.getItem('region');
    final isSupervisor = html.window.sessionStorage.getItem('isSupervisor');

    if (usuario != null && region != null && isSupervisor != null) {
      final bool isSup = isSupervisor.toLowerCase() == 'true';
      return HomeScreen(usuario: usuario, region: region, isSupervisor: isSup);
    }

    return const MyAppForm(); // Pantalla de login
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Control Room',
      locale: const Locale('es'),
      supportedLocales: const [
        Locale('es'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _initialScreen(),
    );
  }
}