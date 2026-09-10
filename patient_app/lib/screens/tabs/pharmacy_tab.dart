import 'package:flutter/material.dart';

class PharmacyTab extends StatefulWidget {
  const PharmacyTab({super.key});

  @override
  State<PharmacyTab> createState() => _PharmacyTabState();
}

class _PharmacyTabState extends State<PharmacyTab> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Map<String, int> _cart = {};

  final List<String> _categories = const [
    'All',
    'Jan Aushadhi',
    'Pain Relief',
    'Fever & Cold',
    'Chronic Care',
    'Vitamins & Supplements',
  ];

  final List<Map<String, dynamic>> _medicines = const [
    {
      'id': 'med_1',
      'name': 'Paracetamol 650mg',
      'generic': 'Acetaminophen BP 650mg',
      'category': 'Fever & Cold',
      'brand': 'Jan Aushadhi Generic',
      'isJanAushadhi': true,
      'pack': '10 tablets strip',
      'price': 12.0,
      'mrp': 42.0,
      'inStock': true,
    },
    {
      'id': 'med_2',
      'name': 'Amoxicillin & Potassium Clavulanate',
      'generic': 'Amoxyclav 625mg',
      'category': 'Jan Aushadhi',
      'brand': 'PMBJP Generic',
      'isJanAushadhi': true,
      'pack': '6 tablets strip',
      'price': 48.0,
      'mrp': 160.0,
      'inStock': true,
    },
    {
      'id': 'med_3',
      'name': 'Metformin HCl 500mg',
      'generic': 'Metformin Sustained Release',
      'category': 'Chronic Care',
      'brand': 'Jan Aushadhi Generic',
      'isJanAushadhi': true,
      'pack': '10 tablets strip',
      'price': 14.0,
      'mrp': 55.0,
      'inStock': true,
    },
    {
      'id': 'med_4',
      'name': 'Atorvastatin 10mg',
      'generic': 'Atorvastatin Calcium IP',
      'category': 'Chronic Care',
      'brand': 'Jan Aushadhi Generic',
      'isJanAushadhi': true,
      'pack': '10 tablets strip',
      'price': 18.0,
      'mrp': 78.0,
      'inStock': true,
    },
    {
      'id': 'med_5',
      'name': 'Ibuprofen 400mg',
      'generic': 'Ibuprofen IP 400mg',
      'category': 'Pain Relief',
      'brand': 'Ashwini Central Pharmacy',
      'isJanAushadhi': false,
      'pack': '10 tablets strip',
      'price': 16.0,
      'mrp': 35.0,
      'inStock': true,
    },
    {
      'id': 'med_6',
      'name': 'Vitamin C 500mg Chewable',
      'generic': 'Ascorbic Acid & Sodium Ascorbate',
      'category': 'Vitamins & Supplements',
      'brand': 'Jan Aushadhi Generic',
      'isJanAushadhi': true,
      'pack': '15 chewable tabs',
      'price': 22.0,
      'mrp': 65.0,
      'inStock': true,
    },
    {
      'id': 'med_7',
      'name': 'Pantoprazole 40mg Gastro-Resistant',
      'generic': 'Pantoprazole Sodium IP',
      'category': 'Chronic Care',
      'brand': 'Jan Aushadhi Generic',
      'isJanAushadhi': true,
      'pack': '10 tablets strip',
      'price': 24.0,
      'mrp': 85.0,
      'inStock': true,
    },
    {
      'id': 'med_8',
      'name': 'Cetirizine 10mg',
      'generic': 'Cetirizine Dihydrochloride IP',
      'category': 'Fever & Cold',
      'brand': 'Jan Aushadhi Generic',
      'isJanAushadhi': true,
      'pack': '10 tablets strip',
      'price': 10.0,
      'mrp': 38.0,
      'inStock': true,
    },
  ];

  List<Map<String, dynamic>> get _filteredMedicines {
    return _medicines.where((med) {
      final matchesCategory = _selectedCategory == 'All' ||
          med['category'] == _selectedCategory ||
          (_selectedCategory == 'Jan Aushadhi' && med['isJanAushadhi'] == true);
      final query = _searchQuery.toLowerCase().trim();
      final matchesQuery = query.isEmpty ||
          (med['name'] as String).toLowerCase().contains(query) ||
          (med['generic'] as String).toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  int get _totalCartItems {
    return _cart.values.fold(0, (sum, count) => sum + count);
  }

  double get _totalCartPrice {
    double total = 0.0;
    _cart.forEach((medId, count) {
      final med = _medicines.firstWhere((m) => m['id'] == medId);
      total += (med['price'] as double) * count;
    });
    return total;
  }

  void _addToCart(String medId, String medName) {
    setState(() {
      _cart[medId] = (_cart[medId] ?? 0) + 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added $medName to cart'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF7C3AED),
      ),
    );
  }

  void _removeFromCart(String medId) {
    if ((_cart[medId] ?? 0) > 0) {
      setState(() {
        if (_cart[medId] == 1) {
          _cart.remove(medId);
        } else {
          _cart[medId] = _cart[medId]! - 1;
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredMedicines;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search medicines, generics, salt composition...',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF7C3AED)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Upload Prescription Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order with Prescription',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Upload photo of doctor prescription for fast delivery',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Prescription upload opened. Choose from Camera/Gallery.'),
                                backgroundColor: Color(0xFF7C3AED),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF7C3AED),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Upload', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Jan Aushadhi Scheme Highlight Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified_rounded, size: 18, color: Color(0xFF059669)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'PM Jan Aushadhi Generic Medicines available at up to 80% discount.',
                            style: TextStyle(
                              color: Color(0xFF065F46),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _categories.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(cat),
                            selected: isSelected,
                            onSelected: (val) {
                              setState(() {
                                _selectedCategory = cat;
                              });
                            },
                            backgroundColor: Colors.white,
                            selectedColor: const Color(0xFFEDE9FE),
                            labelStyle: TextStyle(
                              color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF475569),
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 12,
                            ),
                            side: BorderSide(
                              color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.4 : 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Medicine Catalog List
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.medication_liquid_outlined, size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'No medicines found for "$_searchQuery"',
                      style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 100.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final med = filtered[index];
                    final medId = med['id'] as String;
                    final count = _cart[medId] ?? 0;
                    final price = med['price'] as double;
                    final mrp = med['mrp'] as double;
                    final discount = (((mrp - price) / mrp) * 100).round();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Medicine Icon
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F3FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFEDE9FE)),
                            ),
                            child: const Icon(
                              Icons.medication_rounded,
                              color: Color(0xFF7C3AED),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Medicine Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        med['name'] as String,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    if (med['isJanAushadhi'] == true)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'JAN AUSHADHI',
                                          style: TextStyle(
                                            color: Color(0xFF059669),
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  med['generic'] as String,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  med['pack'] as String,
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 10.5,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Price row
                                Row(
                                  children: [
                                    Text(
                                      '₹${price.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '₹${mrp.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade400,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '$discount% OFF',
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Add / Quantity Buttons
                          if (count == 0)
                            ElevatedButton(
                              onPressed: () => _addToCart(medId, med['name'] as String),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF5F3FF),
                                foregroundColor: const Color(0xFF7C3AED),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: const BorderSide(color: Color(0xFFDDD6FE)),
                                ),
                              ),
                              child: const Text('ADD', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                            )
                          else
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, size: 14, color: Colors.white),
                                    onPressed: () => _removeFromCart(medId),
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    padding: EdgeInsets.zero,
                                  ),
                                  Text(
                                    '$count',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add, size: 14, color: Colors.white),
                                    onPressed: () => _addToCart(medId, med['name'] as String),
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
      bottomSheet: _totalCartItems > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_totalCartItems ITEM${_totalCartItems > 1 ? "S" : ""}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF7C3AED),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '₹${_totalCartPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Order placed for $_totalCartItems items (₹${_totalCartPrice.toStringAsFixed(0)})! Delivery within 2 hours.'),
                          backgroundColor: const Color(0xFF059669),
                        ),
                      );
                      setState(() {
                        _cart.clear();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Text('Proceed to Buy', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
