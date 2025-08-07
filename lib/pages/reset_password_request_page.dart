import 'package:flutter/material.dart';
import 'package:pantry_organizer/services/auth_services.dart';

class ResetPasswordRequestPage extends StatefulWidget {
  const ResetPasswordRequestPage({super.key});

  @override
  State<ResetPasswordRequestPage> createState() => _ResetPasswordRequestPageState();
}

class _ResetPasswordRequestPageState extends State<ResetPasswordRequestPage> {
  final _emailController = TextEditingController();
  bool _emailSent = false;
  String _error = '';

  Future<void> _sendResetEmail() async {
    try {
      AuthServices.requestResetPassword(_emailController.text);
      setState(() {
        _emailSent = true;
        _error = '';
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _emailSent
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('An email has been sent to your address.'),
                ],
              )
            : Column(
                children: [
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _sendResetEmail,
                    child: const Text('Send reset email'),
                  ),
                  if (_error.isNotEmpty) Text(_error, style: const TextStyle(color: Colors.red)),
                ],
              ),
      ),
    );
  }
}
