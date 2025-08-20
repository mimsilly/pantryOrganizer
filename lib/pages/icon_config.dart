// icon_config.dart


import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

final locationsIcons = [
  'assets/locationIcons/basement.png', 
  'assets/locationIcons/cellar.png',
  'assets/locationIcons/kitchen.png',
  'assets/locationIcons/pantry_0.png',
  'assets/locationIcons/pantry_1.png',
  'assets/locationIcons/pantry_2.png',
  'assets/locationIcons/refrigerator.png',
  'assets/locationIcons/storage.png',
];

final itemsIcons = [
  'assets/foodIcons/pasta.png',
  'assets/foodIcons/rice.png',
  'assets/foodIcons/wheat.png',
  'assets/foodIcons/canned-food.png',
  'assets/foodIcons/glass-bottle.png',
  'assets/foodIcons/lentils.png',
  'assets/foodIcons/spices.png',
  'assets/foodIcons/cereal.png',
  'assets/foodIcons/bread.png',
  'assets/foodIcons/honeyjam.png',
  'assets/foodIcons/cookie.png',
  'assets/foodIcons/chips.png',
  'assets/foodIcons/fruit.png',
  'assets/foodIcons/vegetable.png',
  'assets/foodIcons/meat.png',
  'assets/foodIcons/ready-meal.png',
  'assets/foodIcons/pizza.png',
  'assets/foodIcons/popsicle.png',
  'assets/foodIcons/sweets.png',
  'assets/foodIcons/water-bottle.png',
  'assets/foodIcons/beer.png',
    Symbols.egg, 
];


// Soft, low-intensity background colors
final List<Color> availableColors = [
  const Color(0xFFFFE5B4), // soft peach
  const Color(0xFFFFF8A5), // cornsilk
  const Color(0xFFD1F2EB), // mint
  const Color(0xFFE8DAEF), // lavender
  const Color(0xFFFFE4E1), // misty rose
  const Color(0xFFF0F8FF), // alice blue
  const Color(0xFFE6E6FA), // lavender light
  const Color(0xFFEFA6AA), // strawberry

];


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