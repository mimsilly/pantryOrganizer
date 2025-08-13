import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'icon_config.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;


Widget buildItemIcon(dynamic iconData, {double size = 40}) {
  if (iconData is IconData) return Icon(iconData, size: size);
  if (iconData is String){
    if(iconData.startsWith("http")){
      return CachedNetworkImage(
        imageUrl: iconData,
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholder: (context, url) => const CircularProgressIndicator(),
        errorWidget: (context, url, error) => Icon(Icons.broken_image, size: size),
      );

    }
    else {
      return Image.asset(iconData, width: size, height: size);
    }
  } 
  return Icon(Icons.help_outline, size: size);
}

class CreateItemScreen extends StatefulWidget {
  const CreateItemScreen({Key? key}) : super(key: key);

  @override
  State<CreateItemScreen> createState() => _CreateItemScreenState();
}

class _CreateItemScreenState extends State<CreateItemScreen> {
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _unitNumberController = TextEditingController();
  DateTime? _expiryDate;

  int? _selectedIcon;
  String? _selectedUnit;

  String? _selectedLocation;
  List<Map<String, dynamic>> _locations = [];
  final List<dynamic> _displayedIcons = [...itemsIcons];
  bool _loadingLocations = true;

  final List<String> units = ['g', 'kg', 'ml', 'l', 'pcs'];

  @override
  void initState() {
    super.initState();
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

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => BarcodeScannerScreen()),
    );
    if (barcode != null) {
      final data = await _fetchFoodFacts(barcode);
      if (data != null) {
        setState(() {
          _nameController.text = data['product_name'] ?? '';
          _brandController.text = data['brands'] ?? '';
          _unitNumberController.text = data['quantity'] ?? '';
          final unitFromApi = data['product_quantity_unit'] ?? '';
          _updateUnitFromApi(unitFromApi);
          if (data['image_url'] != null){
            if(_displayedIcons.length == itemsIcons.length) {
              _displayedIcons.add(data['image_url']);
            } else {
              _displayedIcons[_displayedIcons.length -1] = data['image_url'];
            }
          _selectedIcon = _displayedIcons.length - 1;}
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchFoodFacts(String barcode) async {
    final url = Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json');
    try {
      final res = await http.get(url);
      final jsonData = jsonDecode(res.body);
      if (jsonData['status'] == 1) return jsonData['product'];
    } catch (e) {debugPrint('Error when getting food data: $e');}
    return null;
  }

  void _updateUnitFromApi(String unitFromApi) {
  setState(() {
    // Add the unit to the list if it's not already there
    if (unitFromApi.isNotEmpty && !units.contains(unitFromApi)) {
      units.add(unitFromApi);
    }
    // Set the dropdown selected value
    _selectedUnit = units.contains(unitFromApi) ? unitFromApi : null;
  });
}

Future<void> _saveItem() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final householdId = prefs.getString('selected_household_id');
    final valueWithUnit = '${_unitNumberController.text}${_selectedUnit ?? ''}';

    if (householdId == null || _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location.')),
      );
      return;
    }

      if (_nameController.text == "") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a name.')),
      );
      return;
    }

    await Supabase.instance.client.from('items').insert({
      'household_id': householdId,
      'location_id': _selectedLocation,
      'name': _nameController.text,
      'brand': _brandController.text,
      'quantity': int.tryParse(_quantityController.text) ?? 1,
      'unit': valueWithUnit,
      'expiration_date': _expiryDate?.toIso8601String(),
      'icon_id': _selectedIcon,
      'image_url': (_selectedIcon != null && _displayedIcons[_selectedIcon!] is String) 
          ? _displayedIcons[_selectedIcon!] 
          : null,    });

    Navigator.pop(context);
  } catch (e) {
    // Show the error on screen but don't close the screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error saving item: $e')),
    );
    debugPrint('Error saving item: $e');
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Item')),
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
                    controller: _unitNumberController, // separate controller for the number
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Value'),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _selectedUnit,
                  hint: const Text('Unit'),
                  items: units.map((e) => DropdownMenuItem(child: Text(e), value: e)).toList(),
                  onChanged: (v) => setState(() => _selectedUnit = v),
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

                // Get the icon path, fall back to a default if missing
                final iconPath = locationsIcons[loc['icon_id'] ?? 0];

                // Optional: set a background color similar to home_page
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
                        Image.asset(iconPath, width: 24, height: 24), // smaller icons
                        const SizedBox(height: 4),
                        Text(
                          loc['name'] ?? 'Unnamed',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), // smaller text
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
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) setState(() => _expiryDate = date);
                  },
                ),
              ],
            ),

            // Barcode scanner
            ElevatedButton.icon(
              onPressed: _scanBarcode,
              icon: const Icon(Icons.qr_code),
              label: const Text('Scan Barcode'),
            ),
            const SizedBox(height: 20),

            // Save button
            ElevatedButton(
              onPressed: _saveItem,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates, // avoids repeated frames
    facing: CameraFacing.back,
  );

  bool _isProcessing = false;
  bool _torchOn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        actions: [
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              _controller.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) async {
              if (_isProcessing) return; // throttle
              _isProcessing = true;

              try {
                final barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final code = barcodes.first.rawValue;
                  if (code != null) {
                    Navigator.pop(context, code);
                  }
                }
              } catch (e) {
                debugPrint('Barcode scan error: $e');
              } finally {
                _isProcessing = false;
              }
            },

          ),
          // Optional overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
