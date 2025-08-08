import 'package:flutter/material.dart';
import 'package:pantry_organizer/services/auth_services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({super.key});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  final Color logOutColor = Colors.red[300]!;

  late Future<List<Map<String, dynamic>>> _householdsFuture;
  late Future<List<Map<String, dynamic>>> _pendingInvitesFuture;
  final _householdNameController = TextEditingController();
  String _error = '';

  @override
  void initState() {
    super.initState();
    _householdsFuture = _fetchHouseholds();
    _pendingInvitesFuture = _fetchPendingInvites();
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

  Future<List<Map<String, dynamic>>> _fetchPendingInvites() async {
    final userEmail = Supabase.instance.client.auth.currentUser!.email;

    final invites = await Supabase.instance.client
        .from('household_invites')
        .select('id, household_id')
        .eq('email', userEmail!)
        .eq('accepted', false);

    if (invites.isEmpty) return [];

    final householdIds = invites.map((i) => i['household_id']).toList();

    final households = await Supabase.instance.client
        .from('households')
        .select('id, name, created_by_email')
        .inFilter('id', householdIds);

    // merge invite_id into the household data
    return households.map<Map<String, dynamic>>((h) {
      final invite = invites.firstWhere((i) => i['household_id'] == h['id']);
      return {
        ...h,
        'invite_id': invite['id'],
      };
    }).toList();
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
          .insert({
            'name': name,
            'created_by': userId,
            'created_by_email': userEmail
          })
          .select();

      final newHousehold = response[0];

      await Supabase.instance.client.from('memberships').insert({
        'user_id': userId,
        'household_id': newHousehold['id'],
        'role': 'owner',
      });

      setState(() {
        _householdsFuture = _fetchHouseholds();
        _householdNameController.clear();
        _error = '';
      });
    } catch (e) {
      setState(() => _error = 'Failed to create household: $e');
    }
  }

  Future<void> _acceptInvite(String inviteId) async {
    try {
      await Supabase.instance.client.rpc('accept_invite', params: {
        'invite_id': inviteId,
      });
      setState(() {
        _pendingInvitesFuture = _fetchPendingInvites();
        _householdsFuture = _fetchHouseholds();
      });
    } catch (e) {
      setState(() => _error = 'Failed to accept invite: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Households')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Your households
            const Text(
              'Your Households:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
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
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: households.length,
                  itemBuilder: (context, index) {
                    final h = households[index];
                    final creator = (h['created_by_email'] != null)
                        ? h['created_by_email']
                        : 'Unknown';
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(h['name']),
                        subtitle: Text('Created by: $creator'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () async {
                          final SharedPreferences prefs =
                              await SharedPreferences.getInstance();
                          await prefs.setString(
                              'selected_household_id', h['id']);

                          if (!context.mounted) return;
                          Navigator.pushReplacementNamed(context, '/home');
                        },
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 16),

            // Pending invites
            const Text(
              'Pending Invites:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _pendingInvitesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text('No pending invites.');
                }

                final invites = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: invites.length,
                  itemBuilder: (context, index) {
                    final invite = invites[index];
                    return Card(
                      color: Colors.orange.shade50,
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(invite['name']),
                        subtitle: Text(
                          'Created by: ${invite['created_by_email'] ?? 'Unknown'}',
                        ),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            await _acceptInvite(invite['invite_id']);
                          },
                          child: const Text('Accept'),
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 24),

            // Create household section
            Card(
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create a new household:',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _householdNameController,
                      decoration: const InputDecoration(
                        labelText: 'New Household Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: ElevatedButton(
                        onPressed: _createHousehold,
                        child: const Text('Create Household'),
                      ),
                    ),
                    if (_error.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _error,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Logout section
            const SizedBox(height: 40), // extra space from create household
            Center(
              child: Text(
                'Log out',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: logOutColor),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: GestureDetector(
                onTap: () async {
                  AuthServices.logOut();
                  if (!context.mounted) return;
                  Navigator.pushReplacementNamed(context, '/');
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: logOutColor, // slightly transparent red
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
