import 'package:flutter/material.dart';
import 'package:pantry_organizer/pages/home_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pantry_organizer/pages/household_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';



class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      return FutureBuilder<String?>(
        future: _getSavedHouseholdId(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const CircularProgressIndicator();
          }

          final householdId = snapshot.data;
          if (householdId != null) {
            return const HomePage(); // household_id is stored, go to home
          } else {
            return const HouseholdScreen(); // user must select household
          }
        },
      );
    } else {
      return const AuthPage();
    }
  }
}

Future<String?> _getSavedHouseholdId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('selected_household_id');
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _error = '';

  Future<void> _login() async {
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      setState(() {});
    } catch (e) {
      setState(() {
        _error = 'Login failed: $e';
      });
    }
  }

  Future<void> _signUp() async {
    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text,
        password: _passwordController.text,
      );
      setState(() {
        _error = 'Signup success. Check your email if confirmation is required.';
      });
    } catch (e) {
      setState(() {
        _error = 'Signup failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login or Register')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _login, child: const Text('Login')),
            TextButton(onPressed: _signUp, child: const Text('Register')),
            if (_error.isNotEmpty) Text(_error, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}