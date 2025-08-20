import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'icon_config.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

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
  const CreateItemScreen({super.key});

  @override
  State<CreateItemScreen> createState() => _CreateItemScreenState();
}

class _CreateItemScreenState extends State<CreateItemScreen> {
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _unitValueController = TextEditingController();
  DateTime? _expiryDate;

  int? _selectedIcon;
  String? _selectedUnitText;

  String? _recentlyDeletedID;

  String? _selectedLocation;
  List<Map<String, dynamic>> _locations = [];
  final List<dynamic> _displayedIcons = [...itemsIcons];
  bool _loadingLocations = true;

  final List<String> unitsTextList = ['g', 'kg', 'ml', 'l', 'pcs'];

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

  Future<void> _pickRecentlyDeleted() async {
    // Push the RecentlyDeletedItems page and wait for a Map<String, dynamic>
    final deletedItem = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => RecentlyDeletedItemsPage()),
    );

    if (deletedItem != null) {

      _recentlyDeletedID = deletedItem["id"];

      setState(() {
        _nameController.text = deletedItem['name'] ?? '';
        _brandController.text = deletedItem['brand'] ?? '';
        _quantityController.text = '1';
        _unitValueController.text = '${deletedItem['unit_value'] ?? ''}';
        _updateUnitFromApi(deletedItem['unit_text']);

        // Restore icon if present
        if (deletedItem['image_url'] != null){
          if(_displayedIcons.length == itemsIcons.length) {
            _displayedIcons.add(deletedItem['image_url']);
          } else {
            _displayedIcons[_displayedIcons.length -1] = deletedItem['image_url'];
          }
        _selectedIcon = _displayedIcons.length - 1;}
        else if(deletedItem['icon_id'] != null){
        _selectedIcon = deletedItem['icon_id'];
        }


        // Restore location if available
        if (deletedItem['location_id'] != null) {
          _selectedLocation = deletedItem['location_id'];
        }

        // Restore expiration if available
        if (deletedItem['expiry'] != null && deletedItem['expiry'] is DateTime) {
          _expiryDate = deletedItem['expiry'];
        }
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
          _unitValueController.text = data['quantity'] ?? '';
          _updateUnitFromApi(data['product_quantity_unit'] ?? '');
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
    if (unitFromApi.isNotEmpty && !unitsTextList.contains(unitFromApi)) {
      unitsTextList.add(unitFromApi);
    }
    // Set the dropdown selected value
    _selectedUnitText = unitsTextList.contains(unitFromApi) ? unitFromApi : null;
  });
}

Future<void> _saveItem() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final householdId = prefs.getString('selected_household_id');

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

    if (_quantityController.text == "0") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a quantity.')),
      );
      return;
    }


    if(_recentlyDeletedID != null){

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
      }).eq('id', _recentlyDeletedID!);

      _recentlyDeletedID = null; // reset after update

    } else {
      await Supabase.instance.client.from('items').insert({
      'household_id': householdId,
      'location_id': _selectedLocation,
      'name': _nameController.text,
      'brand': _brandController.text,
      'quantity': int.tryParse(_quantityController.text) ?? 1,
      'unit_value': _unitValueController.text,
      'unit_text':_selectedUnitText,
      'expiration_date': _expiryDate?.toIso8601String(),
      'icon_id': _selectedIcon,
      'image_url': (_selectedIcon != null && _displayedIcons[_selectedIcon!] is String && _displayedIcons[_selectedIcon!].startsWith('http')) 
          ? _displayedIcons[_selectedIcon!] 
          : null,    });
    }

    Navigator.pop(context);
  } catch (e) {
    // Show the error on screen but don't close the screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error saving item: $e')),
    );
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
                    controller: _unitValueController, // separate controller for the number
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

            // Barcode scanner + Recently deleted
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _scanBarcode,
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Scan Barcode'),
                ),
                ElevatedButton.icon(
                  onPressed: _pickRecentlyDeleted,
                  icon: const Icon(Icons.auto_delete),
                  label: const Text('Recently Deleted'),
                ),
              ],
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



const double imageIconSize = 60;

class RecentlyDeletedItemsPage extends StatefulWidget {
  const RecentlyDeletedItemsPage({super.key});

  @override
  State<RecentlyDeletedItemsPage> createState() => _RecentlyDeletedItemsPageState();
}

class _RecentlyDeletedItemsPageState extends State<RecentlyDeletedItemsPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDeletedItems();
  }

  Future<void> _fetchDeletedItems() async {
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

      // ✅ Fetch items with quantity = 0 (deleted ones)
      final response = await Supabase.instance.client
          .from('items')
          .select(
              'id, name, quantity, unit_value, unit_text, brand, icon_id, image_url, location_id, expiration_date, updated_at, locations(color_id, name)')
          .eq('household_id', householdId)
          .eq('quantity', 0);

      setState(() {
        _items = List<Map<String, dynamic>>.from(response);

        // Sort by latest updated_at (descending)
        _items.sort((a, b) {
          final aDate = DateTime.tryParse(a['updated_at'] ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = DateTime.tryParse(b['updated_at'] ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });

        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading deleted items: $e';
        _loading = false;
      });
    }
  }

  Widget _buildItemImage(Map<String, dynamic> item) {
    if (item['image_url'] != null && item['image_url'].toString().isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: item['image_url'],
        width: imageIconSize,
        height: imageIconSize,
        fit: BoxFit.contain,
        placeholder: (context, url) => const CircularProgressIndicator(),
        errorWidget: (context, url, error) =>
            const Icon(Icons.broken_image, size: imageIconSize),
      );
    } else if (item['icon_id'] != null &&
        item['icon_id'] is int &&
        item['icon_id'] < itemsIcons.length) {
      final iconData = itemsIcons[item['icon_id']];
      if (iconData is IconData) {
        return Icon(iconData, size: imageIconSize);
      } else if (iconData is String) {
        return Image.asset(iconData, width: imageIconSize, height: imageIconSize);
      }
    }
    return const Icon(Icons.help_outline, size: imageIconSize);
  }

  Future<void> _showQuantityDialog(Map<String, dynamic> item) async {
    int currentQuantity = item['quantity'] ?? 1;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top row: edit (left) + close (right)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            Navigator.of(context).pop(); // close dialog
                            Navigator.pop(context, item); // ✅ Return to caller (edit item)
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    // Image centered
                    Center(child: _buildItemImage(item)),
                    const SizedBox(height: 8),
                    // Name + brand centered underneath
                    Center(child: buildItemNameWithBrand(item)),
                    const SizedBox(height: 16),
                    // Quantity controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            if (currentQuantity > 0) {
                              setState(() => currentQuantity--);
                            }
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              const Text('Quantity', style: TextStyle(fontSize: 16)),
                              Text(
                                '$currentQuantity',
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () {
                            setState(() => currentQuantity++);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Restock button
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          await Supabase.instance.client
                              .from('items')
                              .update({'quantity': currentQuantity})
                              .eq('id', item['id']);

                          Navigator.of(context).pop(); // close dialog
                          Navigator.of(context).popUntil((route) => route.isFirst);
                          Navigator.pushReplacementNamed(context, '/home');
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error restocking item: $e')),
                          );
                        }
                      },
                      child: const Text('Restock Item'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];

        // Determine background color from location
        final colorId = item['locations']?['color_id'] ?? 0;
        final bgColor = (colorId >= 0 && colorId < availableColors.length)
            ? availableColors[colorId]
            : Colors.grey[200];

        // Format deleted date
        final updatedAt = DateTime.tryParse(item['updated_at'] ?? '');
        final deletedText = updatedAt != null
            ? 'Deleted: ${DateFormat('dd/MM/yy').format(updatedAt.toLocal())}'
            : 'Deleted: Unknown';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showQuantityDialog(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center, // vertically center everything
                children: [
                  _buildItemImage(item),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center, // vertical center
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildItemNameWithBrand(item),
                        const SizedBox(height: 4),
                        Text(
                          item['locations']?['name'] ?? 'Unknown location',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      deletedText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
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
      appBar: AppBar(title: const Text("Recently Deleted")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _fetchDeletedItems,
                  child: _buildListView(),
                ),
    );
  }
}
