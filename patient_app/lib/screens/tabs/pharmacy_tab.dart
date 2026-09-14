import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../services/localization/healthcare_catalog.dart';
import '../../widgets/dynamic_translated_text.dart';
import '../../services/ocr/pp_ocr_v6_service.dart';
import '../../widgets/prescription_attachment_sheet.dart';
import '../../widgets/prescription_detected_sheet.dart';

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

  final List<Map<String, String>> _categories = const [
    {'id': 'All', 'key': 'cat_all'},
    {'id': 'Jan Aushadhi', 'key': 'cat_jan_aushadhi'},
    {'id': 'Pain Relief', 'key': 'cat_pain_relief'},
    {'id': 'Fever & Cold', 'key': 'cat_fever_cold'},
    {'id': 'Chronic Care', 'key': 'cat_chronic_care'},
    {'id': 'Vitamins & Supplements', 'key': 'cat_vitamins'},
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
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    final addedMsg = langProvider.tr('added_to_cart');
    final translatedName = HealthcareCatalog.lookup(medName, langProvider.currentLanguageCode) ?? medName;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$addedMsg: $translatedName'),
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

  Future<void> _openPrescriptionWorkflow() async {
    PrescriptionAttachmentSheet.show(
      context,
      onSelected: (result) async {
        final assetPath = result['assetPath'] as String?;
        final imageBytes = result['imageBytes'] as Uint8List?;
        final title = result['title'] as String? ?? 'Prescription';

        // 1. Show OCR Progress Modal with scanning laser
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => _PrescriptionScanningDialog(prescriptionTitle: title),
        );

        // 2. Perform prescription OCR
        final detected = await PpOcrV6Service.instance.processPrescription(
          imageBytes: imageBytes,
          assetPath: assetPath,
        );

        // 3. Dismiss progress dialog
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        // 4. Show Detected Medicines Sheet with schedule, timing & meal instructions
        if (mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => PrescriptionDetectedSheet(
              medicines: detected,
              assetPath: assetPath,
              imageBytes: imageBytes,
              onAddToCart: (selectedMedicines) {
                _addPrescriptionMedicinesToCart(selectedMedicines);
              },
            ),
          );
        }
      },
    );
  }

  void _addPrescriptionMedicinesToCart(List<DetectedMedicine> medicines) {
    setState(() {
      for (final med in medicines) {
        final id = med.matchedCatalogId;
        _cart[id] = (_cart[id] ?? 0) + 1;
      }
    });

    final totalSaved = medicines.fold(0.0, (sum, m) => sum + (m.mrp - m.price));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Added ${medicines.length} prescribed medicines! Total Jan Aushadhi Savings: ₹${totalSaved.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);
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
                        hintText: langProvider.tr('search_pharmacy_hint'),
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
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openPrescriptionWorkflow,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    langProvider.tr('order_with_prescription'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    langProvider.tr('upload_prescription_sub'),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _openPrescriptionWorkflow,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF7C3AED),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(langProvider.tr('upload_btn'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                    child: Row(
                      children: [
                        const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF059669)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            langProvider.tr('jan_aushadhi_discount_banner'),
                            style: const TextStyle(
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
                        final catId = cat['id']!;
                        final catKey = cat['key']!;
                        final isSelected = _selectedCategory == catId;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(langProvider.tr(catKey)),
                            selected: isSelected,
                            onSelected: (val) {
                              setState(() {
                                _selectedCategory = catId;
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
                      '${langProvider.tr('no_meds_found')} "$_searchQuery"',
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
                                      child: DynamicTranslatedText(
                                        text: med['name'] as String,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: Color(0xFF0F172A),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                     if (med['isJanAushadhi'] == true) ...[
                                       const SizedBox(width: 4),
                                       Flexible(
                                         child: Container(
                                           padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                           decoration: BoxDecoration(
                                             color: const Color(0xFFECFDF5),
                                             borderRadius: BorderRadius.circular(4),
                                           ),
                                           child: FittedBox(
                                             fit: BoxFit.scaleDown,
                                             child: Text(
                                               langProvider.tr('jan_aushadhi_badge'),
                                               style: const TextStyle(
                                                 color: Color(0xFF059669),
                                                 fontSize: 9,
                                                 fontWeight: FontWeight.w800,
                                               ),
                                             ),
                                           ),
                                         ),
                                       ),
                                     ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                DynamicTranslatedText(
                                  text: med['generic'] as String,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                DynamicTranslatedText(
                                  text: med['pack'] as String,
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 10.5,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Price row with Wrap and spacing to prevent overflow
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      '₹${price.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      '₹${mrp.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade400,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '$discount% ${langProvider.tr('off_badge')}',
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

                          const SizedBox(width: 8),

                          // Add / Quantity Buttons
                          if (count == 0)
                            ElevatedButton(
                              onPressed: () => _addToCart(medId, med['name'] as String),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF5F3FF),
                                foregroundColor: const Color(0xFF7C3AED),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                minimumSize: const Size(54, 34),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: const BorderSide(color: Color(0xFFDDD6FE)),
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(langProvider.tr('add_btn'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                              ),
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
                        '$_totalCartItems ${langProvider.tr(_totalCartItems > 1 ? "items_plural" : "item_singular")}',
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
                      final itemWord = langProvider.tr(_totalCartItems > 1 ? 'items_plural' : 'item_singular');
                      final deliveryWord = langProvider.tr('delivery_2_hours');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$_totalCartItems $itemWord (₹${_totalCartPrice.toStringAsFixed(0)})! $deliveryWord.'),
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              langProvider.tr('place_order_btn'),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 16),
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

class _PrescriptionScanningDialog extends StatefulWidget {
  final String prescriptionTitle;
  const _PrescriptionScanningDialog({required this.prescriptionTitle});

  @override
  State<_PrescriptionScanningDialog> createState() => _PrescriptionScanningDialogState();
}

class _PrescriptionScanningDialogState extends State<_PrescriptionScanningDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.document_scanner_rounded,
                    size: 38,
                    color: Color(0xFF7C3AED),
                  ),
                ),
                SizedBox(
                  width: 86,
                  height: 86,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                    backgroundColor: Colors.purple.shade50,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Analyzing Prescription',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1B4B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.prescriptionTitle,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7C3AED),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Detecting medicines, dosage & schedule...',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
