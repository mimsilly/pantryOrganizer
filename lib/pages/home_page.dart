import 'package:flutter/material.dart';
import 'package:pantry_organizer/services/auth_services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'icon_config.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Map<String, dynamic>> _locations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLocations();
  }

  Future<void> _fetchLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final householdId = prefs.getString('selected_household_id');

      if (householdId == null) {
        setState(() {
          _error = 'No household selected.';
          _loading = false;
        });
        return;
      }

      final response = await Supabase.instance.client
          .from('locations')
          .select()
          .eq('household_id', householdId);

      setState(() {
        _locations = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading locations: $e';
        _loading = false;
      });
    }
  }

// Helper function to check ownership:
Future<bool> _canManageHousehold() async {
  final prefs = await SharedPreferences.getInstance();
  final householdId = prefs.getString('selected_household_id');
  if (householdId == null) return false;

  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return false;

  try {
    final response = await Supabase.instance.client
        .from('memberships')
        .select()
        .eq('household_id', householdId)
        .eq('user_id', userId)
        .eq('role', 'owner');

    // Return true if any matching membership exists
    return response.isNotEmpty;
  } catch (e) {
    // Handle any other exceptions
    debugPrint('Exception in _canManageHousehold: $e');
    return false;
  }
}
  void _goToCreateLocation() async {
    final result = await Navigator.pushNamed(context, '/create-location');

    if (result == true) {
      _fetchLocations(); // Reload locations
    }
  }


  void _goToSettings() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = screenWidth / 3;
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Home'),
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            _goToSettings();
          },
        ),
      ),
      drawer: Drawer(
        child: FutureBuilder(
          future: _canManageHousehold(),
          builder: (context, AsyncSnapshot<bool> snapshot) {
            final canManage = snapshot.data ?? false;

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                const DrawerHeader(
                  decoration: BoxDecoration(color: Colors.blue),
                  child: Text('Settings', style: TextStyle(color: Colors.white, fontSize: 24)),
                ),
                ListTile(
                  leading: const Icon(Icons.home),
                  title: const Text('Change Household'),
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('selected_household_id');
                    if (!context.mounted) return;
                    Navigator.pushReplacementNamed(context, '/households');
                  },
                ),
                if (canManage)
                  ListTile(
                    leading: const Icon(Icons.edit),  // pen icon
                    title: const Text('Manage Household'),
                    onTap: () {
                      Navigator.pushNamed(context, '/manage-household');
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Log Out'),
                  onTap: () async {
                    AuthServices.logOut();
                    if (!context.mounted) return;
                    Navigator.pushReplacementNamed(context, '/');
                  },
                ),
              ],
            );
          },
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(10),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _locations.length,
                        itemBuilder: (context, index) {
                          final location = _locations[index];
                          final iconPath = availableIcons[location['icon_id'] ?? 0];

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(iconPath, width: itemWidth, height: itemWidth), 
                                const SizedBox(height: 8),
                                Text(
                                  location['name'] ?? 'Unnamed',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _goToCreateLocation,
                          child: const Text('Create Location'),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
