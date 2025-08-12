import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'icon_config.dart';



enum ViewType { list, grid }
enum SortBy { name, expiration, location }
const double imageIconSize = 60;

class AllItemsList extends StatefulWidget {
  const AllItemsList({super.key});

  @override
  State<AllItemsList> createState() => _AllItemsListState();
}

class _AllItemsListState extends State<AllItemsList> {
  ViewType _currentView = ViewType.list;
  SortBy _sortBy = SortBy.name;


  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _fetchItems();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentView = ViewType.values[prefs.getInt('viewType') ?? 0];
      _sortBy = SortBy.values[prefs.getInt('sortBy') ?? 0];
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('viewType', _currentView.index);
    prefs.setInt('sortBy', _sortBy.index);
  }

  Future<void> _fetchItems() async {
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

      // Fetch items with their location details
      final response = await Supabase.instance.client
          .from('items')
          .select('id, name, quantity, unit, brand,expiration_date, image_url, icon_id, locations(color_id, name)')
          .eq('household_id', householdId);

      setState(() {
        _items = List<Map<String, dynamic>>.from(response);
        _sortItems();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading items: $e';
        _loading = false;
      });
    }
  }

  void _sortItems() {
    _items.sort((a, b) {
      switch (_sortBy) {
        case SortBy.name:
          return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
        case SortBy.expiration:
          return (a['expiration'] ?? '').toString().compareTo((b['expiration'] ?? '').toString());
        case SortBy.location:
          return (a['locations']?['name'] ?? '').toString()
              .compareTo((b['locations']?['name'] ?? '').toString());
      }
    });
  }

    Widget buildItemIcon(dynamic iconData, {double size = 40}) {
    if (iconData is IconData) {
      return Icon(iconData, size: size);
    } else if (iconData is String) {
      return Image.asset(iconData, width: size, height: size);
    } else {
      return Icon(Icons.help_outline, size: size); // fallback
    }
  }



  Widget _buildItemImage(Map<String, dynamic> item) {

    Widget buildIcon(dynamic iconData) {
      if (iconData is IconData) {
        return Icon(iconData, size: imageIconSize);
      } else if (iconData is String) {
        return Image.asset(iconData, width: imageIconSize, height: imageIconSize);
      } else {
        return Icon(Icons.help_outline, size: imageIconSize);
      }
    }

    if (item['image_url'] != null && item['image_url'].toString().isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: item['image_url'],
        width: imageIconSize,
        height: imageIconSize,
        fit: BoxFit.contain,
        placeholder: (context, url) => const CircularProgressIndicator(),
        errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: imageIconSize),
      );
    } else if (item['icon_id'] != null && item['icon_id'] is int && item['icon_id'] < itemsIcons.length) {
      return buildIcon(itemsIcons[item['icon_id']]);
    } else {
      return Icon(Icons.help_outline, size: imageIconSize);
    }
  }

  Widget buildItemNameWithBrand(Map<String, dynamic> item) {
    final name = item['name'] ?? 'Unnamed';
    final brand = item['brand'] ?? '';

    if (brand.isEmpty) {
      return Text(name, style: const TextStyle(fontSize: 16));
    } else {
      return Text.rich(
        TextSpan(
          text: name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
          children: [
            TextSpan(
              text: ' - $brand',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      );
    }
  }


  Widget buildItemRow(Map<String, dynamic> item) {
    return InkWell(
      onTap: () => _showQuantityDialog(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(child: buildItemNameWithBrand(item)),
            Text(
              '${item['quantity']}x',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuantityDialog(Map<String, dynamic> item) {
    int currentQuantity = item['quantity'] ?? 1;

    showDialog(
      context: context,
      barrierDismissible: true, // tap outside to close
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                height: 100,
                child: Stack(
                  children: [
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              if (currentQuantity > 1) {
                                setState(() => currentQuantity--);
                              }
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Quantity', style: TextStyle(fontSize: 16)),
                                Text(
                                  '$currentQuantity',
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    ).then((_) {
      // Update quantity in your data source if needed here
      // e.g. update in DB or state management
    });
  }


  Widget _buildListView() {
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final colorId = item['locations']?['color_id'] ?? 0;
        final bgColor = (colorId >= 0 && colorId < availableColors.length)
            ? availableColors[colorId] // lighter background
            : Colors.grey;

        return InkWell(
          onTap: () => _showQuantityDialog(item),
          child: Container(
            color: bgColor,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16), // add some padding
            child: ListTile(
              leading: _buildItemImage(item),
              title: Row(
                children: [
                  Expanded(child: buildItemNameWithBrand(item)),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      '${item['quantity'] ?? '-'}x',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                '${item['unit'] ?? ''} | Exp: ${item['expiration_date'] ?? '-'} | ${item['locations']?['name'] ?? ''}',
              ),
            ),
          ),
        );
      },
    );
  }



  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final colorId = item['locations']?['color_id'] ?? 0;
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
              _buildItemImage(item),
              const SizedBox(height: 6),
              buildItemNameWithBrand(item),
              Text(
                '${item['quantity'] ?? '-'}x ${item['unit'] ?? ''}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Items'),
        actions: [
          IconButton(
            icon: Icon(_currentView == ViewType.list ? Icons.grid_view : Icons.list),
            onPressed: () {
              setState(() {
                _currentView = _currentView == ViewType.list ? ViewType.grid : ViewType.list;
                _savePreferences();
              });
            },
          ),
          PopupMenuButton<SortBy>(
            initialValue: _sortBy,
            onSelected: (sort) {
              setState(() {
                _sortBy = sort;
                _sortItems();
                _savePreferences();
              });
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: SortBy.name, child: Text('Sort by Name')),
              PopupMenuItem(value: SortBy.expiration, child: Text('Sort by Expiration')),
              PopupMenuItem(value: SortBy.location, child: Text('Sort by Location')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _currentView == ViewType.list
                  ? _buildListView()
                  : _buildGridView(),
    );
  }
}
