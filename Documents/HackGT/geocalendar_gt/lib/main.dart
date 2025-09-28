import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geocalendar_gt/task_provider.dart';
import 'package:geocalendar_gt/home_with_map.dart';
import 'package:geocalendar_gt/add_task.dart';
import 'package:geocalendar_gt/notification_service.dart';
import 'package:geocalendar_gt/location.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
// After running `flutterfire configure`, this file will be generated.
// ignore: unnecessary_import
// import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseReady = false;
  // Firebase initialization using generated options when available.
  // Steps (once):
  // 1. Run: dart pub global activate flutterfire_cli
  // 2. Run: flutterfire configure -y -a com.example.geocalendar_gt (replace with real package id)
  // 3. Uncomment the firebase_options import above.
  try {
    // If firebase_options.dart exists, prefer that; otherwise fall back to default (mobile may locate from native files)
    // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (e) {
    debugPrint('Firebase initialization skipped/failed: $e');
  }

  // Initialize notifications only on supported platforms (not web)
  if (!kIsWeb) {
    try {
      await NotificationService().init();
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  // Start location listener (guard Firestore usage internally)
  try {
    LocationService().startLocationListener(firebaseReady: firebaseReady);
  } catch (e) {
    debugPrint('Location listener failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TaskProvider(),
      child: MaterialApp(
        title: 'GeoRemind',
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurpleAccent,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF0B0E14),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            filled: true,
            fillColor: Color(0xFF0F1720),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (c) => const LoginScreen(),
          '/home': (c) => const HomeWithMap(),
          '/add': (c) => const AddTaskScreen(),
        },
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 16),
              const Text(
                "Welcome to GeoRemind",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: hook up Google sign-in
                  Navigator.pushReplacementNamed(context, '/home');
                },
                icon: const Icon(Icons.login),
                label: const Text("Continue with Google"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  // TODO: Email login
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text("Sign in with Email"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
