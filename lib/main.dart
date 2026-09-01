import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/health_profile_provider.dart';
import 'providers/appointment_provider.dart';
import 'providers/schemes_provider.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
        title: 'Patient Health Portal',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF00796B), // Medical Teal
            brightness: Brightness.light,
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
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
