import 'package:flutter/material.dart';
import 'package:pantry_organizer/secrets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Self-created files
import 'package:pantry_organizer/pages/auth_gate.dart';
import 'package:pantry_organizer/pages/select_household_screen.dart';
import 'package:pantry_organizer/pages/home_page.dart';
import 'package:pantry_organizer/pages/create_location.dart';
import 'package:pantry_organizer/pages/reset_password_request_page.dart';
import 'package:pantry_organizer/pages/reset_password_screen.dart';
import 'package:pantry_organizer/pages/manage_household_screen.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: apiURL,
    anonKey: apiKey
  );
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});



  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthGate(),
        '/households': (context) => const HouseholdScreen(),
        '/home': (context) => const HomePage(),
        '/create-location': (context) => const CreateLocationPage(),
        '/reset-password-request': (context) => const ResetPasswordRequestPage(),
        '/reset-password': (context) => const ResetPasswordScreen(),
        '/manage-household': (context) => const ManageHouseholdScreen(),
      },
    );
  }
}


