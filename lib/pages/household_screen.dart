import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
                        onTap: () async {
                          final SharedPreferences prefs = await SharedPreferences.getInstance();
                          await prefs.setString('selected_household_id', h['id']);

                          if (!context.mounted) return;
                          Navigator.pushReplacementNamed(context, '/home');
                        },
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