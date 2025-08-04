import 'package:flutter/material.dart';
import 'package:pantry_organizer/secrets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


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
      title: 'Pantry Organizer',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      return const HouseholdScreen();
    } else {
      return const AuthPage();
    }
  }
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


class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({super.key});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  late Future<List<Map<String, dynamic>>> _householdsFuture;
  final _householdNameController = TextEditingController();
  String _error = '';

  @override
  void initState() {
    super.initState();
    _householdsFuture = _fetchHouseholds();
  }

  Future<List<Map<String, dynamic>>> _fetchHouseholds() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;

    final result = await Supabase.instance.client
        .from('memberships')
        .select('''
          households!inner(
            id,
            name,
            created_by_email
          )
        ''')
        .eq('user_id', userId);

    return (result as List)
        .map((m) => m['households'] as Map<String, dynamic>)
        .toList();
  }


  Future<void> _createHousehold() async {
    final name = _householdNameController.text.trim();
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final userEmail = Supabase.instance.client.auth.currentUser!.email;


    if (name.isEmpty) {
      setState(() => _error = 'Please enter a household name');
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('households')
          .insert({'name': name, 'created_by': userId, 'created_by_email': userEmail})
          .select();

      final newHousehold = response[0];

      await Supabase.instance.client.from('memberships').insert({
        'user_id': userId,
        'household_id': newHousehold['id'],
        'role': 'owner',
      });

      setState(() {
        _householdsFuture = _fetchHouseholds(); // refresh
        _householdNameController.clear();
        _error = '';
      });
    } catch (e) {
      setState(() => _error = 'Failed to create household: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Households')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _householdNameController,
              decoration: const InputDecoration(labelText: 'New Household Name'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _createHousehold,
              child: const Text('Create Household'),
            ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 16),
            const Text('Your Households:', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _householdsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('No households found.');
                  }

                  final households = snapshot.data!;
                  return ListView.builder(
                    itemCount: households.length,
                    itemBuilder: (context, index) {
                      final h = households[index];
                      final creator = (h['created_by_email'] != null) ? h['created_by_email'] : 'Unknown';
                      return ListTile(
                        title: Text(h['name']),
                        subtitle: Text('Created by: $creator'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class HomePage extends StatefulWidget {
  final String householdId; // Added household ID parameter

  const HomePage({super.key, required this.householdId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<List<Map<String, dynamic>>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = Supabase.instance.client
        .from('items')
        .select('id, name, quantity, shelf_id, shelves(name)')
        .eq('household_id', widget.householdId) // Added household filter
        .order('name');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Pantry')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data!;

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final shelfName = item['shelves']['name'] ?? 'Unknown shelf';
              return ListTile(
                title: Text('${item['quantity']} x ${item['name']}'),
                subtitle: Text('in shelf: $shelfName'),
              );
            },
          );
        },
      ),
    );
  }
}