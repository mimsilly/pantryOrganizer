import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'icon_config.dart';

Widget buildItemIcon(dynamic iconData, {double size = 40}) {
  if (iconData is IconData) return Icon(iconData, size: size);
  if (iconData is String) {
    if (iconData.startsWith("http")) {
      return CachedNetworkImage(
        imageUrl: iconData,
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholder: (context, url) => const CircularProgressIndicator(),
        errorWidget: (context, url, error) => Icon(Icons.broken_image, size: size),
      );
    } else {
      return Image.asset(iconData, width: size, height: size);
    }
  }
  return Icon(Icons.help_outline, size: size);
}

class EditItemScreen extends StatefulWidget {
  final Map<String, dynamic> item;

  const EditItemScreen({super.key, required this.item});

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _quantityController;
  late TextEditingController _unitValueController;
  DateTime? _expiryDate;

  int? _selectedIcon;
  String? _selectedUnitText;
  String? _selectedLocation;
  List<Map<String, dynamic>> _locations = [];
  bool _loadingLocations = true;

  final List<dynamic> _displayedIcons = [...itemsIcons];
  final List<String> unitsTextList = ['g', 'kg', 'ml', 'l', 'pcs'];

  @override
  void initState() {
    super.initState();

    final item = widget.item;

    _nameController = TextEditingController(text: item['name'] ?? '');
    _brandController = TextEditingController(text: item['brand'] ?? '');
    _quantityController = TextEditingController(text: '${item['quantity'] ?? 1}');
    _unitValueController = TextEditingController(text: '${item['unit_value'] ?? ''}');
    _selectedUnitText = item['unit_text'];
    _selectedLocation = item['location_id'];
    _expiryDate = item['expiration_date'] != null
        ? DateTime.tryParse(item['expiration_date'])
        : null;

    // Handle icon
    if (item['image_url'] != null) {
      _displayedIcons.add(item['image_url']);
      _selectedIcon = _displayedIcons.length - 1;
    } else {
      _selectedIcon = item['icon_id'];
    }

    _fetchLocations();
  }

  Future<void> _fetchLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final householdId = prefs.getString('selected_household_id');
      if (householdId == null) return;

      final response = await Supabase.instance.client
          .from('locations')
          .select()
          .eq('household_id', householdId);

      setState(() {
        _locations = List<Map<String, dynamic>>.from(response);
        _loadingLocations = false;
      });
    } catch (e) {
      setState(() {
        _loadingLocations = false;
      });
    }
  }

  Future<void> _editItem() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final householdId = prefs.getString('selected_household_id');
      if (householdId == null || _selectedLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a location.')),
        );
        return;
      }

      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a name.')),
        );
        return;
      }

      await Supabase.instance.client.from('items').update({
        'household_id': householdId,
        'location_id': _selectedLocation,
        'name': _nameController.text,
        'brand': _brandController.text,
        'quantity': int.tryParse(_quantityController.text) ?? 1,
        'unit_value': _unitValueController.text,
        'unit_text': _selectedUnitText,
        'expiration_date': _expiryDate?.toIso8601String(),
        'icon_id': _selectedIcon,
        'image_url': (_selectedIcon != null &&
                _displayedIcons[_selectedIcon!] is String &&
                _displayedIcons[_selectedIcon!].startsWith('http'))
            ? _displayedIcons[_selectedIcon!]
            : null,
      }).eq('id', widget.item['id']);

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error editing item: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Item')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Name & Brand
            Row(
              children: [
                Expanded(child: TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _brandController, decoration: const InputDecoration(labelText: 'Brand'))),
              ],
            ),
            const SizedBox(height: 10),

            // Quantity & Unit
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    int current = int.tryParse(_quantityController.text) ?? 1;
                    if (current > 1) _quantityController.text = '${current - 1}';
                    setState(() {});
                  },
                ),
                SizedBox(width: 50, child: TextField(controller: _quantityController, textAlign: TextAlign.center)),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    int current = int.tryParse(_quantityController.text) ?? 1;
                    _quantityController.text = '${current + 1}';
                    setState(() {});
                  },
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _unitValueController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Value'),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _selectedUnitText,
                  hint: const Text('Unit'),
                  items: unitsTextList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _selectedUnitText = v),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Icons
            Wrap(
              spacing: 10,
              children: List.generate(_displayedIcons.length, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(color: _selectedIcon == index ? Colors.blue : Colors.transparent, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: buildItemIcon(_displayedIcons[index], size: 40),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // Locations
            if (_loadingLocations) const CircularProgressIndicator(),
            if (!_loadingLocations)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _locations.length,
                itemBuilder: (context, index) {
                  final loc = _locations[index];
                  final isSelected = _selectedLocation == loc['id'];

                  final iconPath = locationsIcons[loc['icon_id'] ?? 0];
                  final colorId = loc['color_id'] ?? 0;
                  final bgColor = (colorId >= 0 && colorId < availableColors.length)
                      ? availableColors[colorId]
                      : Colors.grey[200];

                  return GestureDetector(
                    onTap: () => setState(() => _selectedLocation = loc['id']),
                    child: Container(
                      decoration: BoxDecoration(
                        color: bgColor,
                        border: Border.all(color: isSelected ? Colors.blue : Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(iconPath, width: 24, height: 24),
                          const SizedBox(height: 4),
                          Text(
                            loc['name'] ?? 'Unnamed',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 10),

            // Expiration Date
            Row(
              children: [
                const Text('Expiration: '),
                Text(_expiryDate != null ? '${_expiryDate!.toLocal()}'.split(' ')[0] : 'None'),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _expiryDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) setState(() => _expiryDate = date);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Edit button
            ElevatedButton(
              onPressed: _editItem,
              child: const Text('Edit'),
            ),
          ],
        ),
      ),
    );
  }
}
