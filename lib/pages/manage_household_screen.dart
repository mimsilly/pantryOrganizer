import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManageHouseholdScreen extends StatefulWidget {
  const ManageHouseholdScreen({Key? key}) : super(key: key);

  @override
  State<ManageHouseholdScreen> createState() => _ManageHouseholdScreenState();
}

class _ManageHouseholdScreenState extends State<ManageHouseholdScreen> {
  late String householdId;

  List<Map<String, dynamic>> members = [];
  List<String> pendingInvites = [];

  bool isLoadingMembers = true;
  bool isLoadingInvites = true;

  final _inviteEmailController = TextEditingController();
  bool inviteSent = false;

  @override
  void initState() {
    super.initState();
    _loadHouseholdIdAndData();
  }

  Future<void> _loadHouseholdIdAndData() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('selected_household_id');
    if (id == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    householdId = id;

    // Load members and invites separately but in parallel if you want:
    await Future.wait([
      _loadMembers(),
      _loadPendingInvites(),
    ]);
  }

  Future<void> _loadMembers() async {
    setState(() {
      isLoadingMembers = true;
    });

    try {
      final response = await Supabase.instance.client
          .from('memberships')
          .select('user_id, user_email, role')
          .eq('household_id', householdId);

      members = response.map<Map<String, dynamic>>((e) {
        return {
          'user_id': e['user_id'],
          'email': e['user_email'] ?? 'No email',
          'role': e['role'] ?? 'member',

        };
      }).toList();
    } catch (e) {
      debugPrint('Exception in _loadMembers: $e');
      members = [];
    } finally {
      if (mounted) {
        setState(() {
          isLoadingMembers = false;
        });
      }
    }
  }

  Future<void> _loadPendingInvites() async {
    setState(() {
      isLoadingInvites = true;
    });

    try {
      final response = await Supabase.instance.client
          .from('household_invites')
          .select('email')
          .eq('household_id', householdId)
          .eq('accepted', false);

      pendingInvites = response.map<String>((e) => e['email'] as String).toList();
    } catch (e) {
      debugPrint('Exception in _loadPendingInvites: $e');
      pendingInvites = [];
    } finally {
      if (mounted) {
        setState(() {
          isLoadingInvites = false;
        });
      }
    }
  }

  Future<void> _sendInvite() async {
    final email = _inviteEmailController.text.trim();
    if (email.isEmpty) return;

    try {
      final response = await Supabase.instance.client.rpc('invite_user', params: {
        'p_household_id': householdId,
        'p_invited_email': email,
      }).single();

      if (response['status'] == 'SUCCESS') {
        setState(() {
          inviteSent = true;
          _inviteEmailController.clear();
        });

        // Reload both members and invites to update UI
        await Future.wait([
          _loadMembers(),
          _loadPendingInvites(),
        ]);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite sent successfully')),
        );
      } else {
        final message = response['message'] ?? 'Unknown error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send invite: $message')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send invite: $e')),
      );
    }
  }

  @override
  void dispose() {
    _inviteEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Household')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Household Members Section
            const Text(
              'Household Members:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (isLoadingMembers)
              const Center(child: CircularProgressIndicator())
            else if (members.isEmpty)
              const Text('No members found.')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  return ListTile(
                    leading: Icon(
                      member['role'] == 'owner' ? Icons.manage_accounts  : Icons.person,
                      color: member['role'] == 'owner' ? Colors.amber : null,
                    ),
                    title: Text(member['email'] ?? 'No Email'),
                  );
                },

              ),

            const SizedBox(height: 16),

            // Pending Invites Section
            const Text(
              'Pending Invites:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (isLoadingInvites)
              const Center(child: CircularProgressIndicator())
            else if (pendingInvites.isEmpty)
              const Text('No pending invites.')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pendingInvites.length,
                itemBuilder: (context, index) {
                  final email = pendingInvites[index];
                  return Card(
                    color: Colors.orange.shade50,
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: const Icon(Icons.hourglass_empty),
                      title: Text(email),
                    ),
                  );
                },
              ),

            const Divider(height: 32),

            Card(
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Invite a new member:',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _inviteEmailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: ElevatedButton(
                        onPressed: _sendInvite,
                        child: const Text('Send Invite'),
                      ),
                    ),
                    if (inviteSent)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Invite sent successfully',
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
