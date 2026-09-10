import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/health_profile_provider.dart';
import 'providers/appointment_provider.dart';
import 'providers/schemes_provider.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init note: $e');
  }
  runApp(const PatientApp());
}

class PatientApp extends StatelessWidget {
  const PatientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => HealthProfileProvider()..loadProfile(),
        ),
        ChangeNotifierProvider(
          create: (_) => AppointmentProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => SchemesProvider()..loadSavedProfile(),
        ),
      ],
      child: MaterialApp(
        title: 'ASHWINI Patient App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          final clampedTextScaler = mediaQuery.textScaler.clamp(
            minScaleFactor: 0.85,
            maxScaleFactor: 1.15,
          );
          return MediaQuery(
            data: mediaQuery.copyWith(textScaler: clampedTextScaler),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const AuthGate(),
      ),
    );
  }
}

/// Determines whether to show the Signup screen or the Home screen based on stored profile state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<HealthProfileProvider>(context);

    if (!provider.isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (provider.isOnboarded) {
      return const HomeScreen();
    }

    return const SignupScreen();
  }
}
