import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'icon_config.dart';

class CreateLocationPage extends StatefulWidget {
  const CreateLocationPage({super.key});

  @override
  State<CreateLocationPage> createState() => _CreateLocationPageState();
}

class _CreateLocationPageState extends State<CreateLocationPage> {
  final TextEditingController _nameController = TextEditingController();
  int? _selectedIconId;
  String? _error;
  bool _isLoading = false;


  Future<void> _createLocation() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedIconId == null) {
      setState(() => _error = 'Please enter a name and select an icon.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final householdId = prefs.getString('selected_household_id');

    if (householdId == null) {
      setState(() => _error = 'No household selected.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.from('locations').insert({
        'name': name,
        'household_id': householdId,
        'icon_id': _selectedIconId,
      });

      if (!mounted) return;
      Navigator.pop(context, true); // Return to HomePage
    } catch (e) {
      setState(() => _error = 'Failed to create location: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }



Widget _buildIconPicker() {
  return GridView.builder(
    itemCount: availableIcons.length,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(8),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
    ),
    itemBuilder: (context, index) {
      final isSelected = index == _selectedIconId;
      return GestureDetector(
        onTap: () => setState(() => _selectedIconId = index),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue[100] : Colors.grey[200],
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Image.asset(
              availableIcons[index],
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    },
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Location')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Location Name'),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Select Icon:', style: TextStyle(fontSize: 16)),
            ),
            _buildIconPicker(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createLocation,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Create'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
