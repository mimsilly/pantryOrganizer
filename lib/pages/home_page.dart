import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:pantry_organizer/services/auth_services.dart';
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

      return response.isNotEmpty;
    } catch (e) {
      debugPrint('Exception in _canManageHousehold: $e');
      return false;
    }
  }

  void _goToCreateLocation() async {
    final result = await Navigator.pushNamed(context, '/create-location');
    if (result == true) {
      _fetchLocations();
    }
  }

  void _goToSettings() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _goToAllItems() {
    Navigator.pushNamed(context, '/all-items-list');
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = 70.0; 
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Home'),
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: _goToSettings,
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
                  leading: const Icon(Symbols.wifi_home),
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
                    leading: const Icon(Icons.edit),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        "Your current locations",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(10),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _locations.length,
                        itemBuilder: (context, index) {
                          final location = _locations[index];
                          final iconPath = locationsIcons[location['icon_id'] ?? 0];

                          // Fetch stored color_id and get from availableColors
                          final colorId = location['color_id'] ?? 0;
                          final bgColor = (colorId >= 0 && colorId < availableColors.length)
                              ? availableColors[colorId]
                              : Colors.grey[200];

                          return Container(
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(iconPath, width: iconSize, height: iconSize),
                                const SizedBox(height: 8),
                                Text(
                                  location['name'] ?? 'Unnamed',
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _goToAllItems,
                          child: const Text('Show All Items'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _goToCreateLocation,
                          child: const Text('Create Location'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
    );
  }
}
