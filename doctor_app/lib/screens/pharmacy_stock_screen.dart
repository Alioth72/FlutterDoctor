import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/api_client.dart';

class PharmacyItem {
  final String id;
  final String name;
  final String composition;
  final String category;
  final String form;
  int stockQuantity;
  final int minThreshold;
  final String location;
  final double pricePerUnit;
  final String manufacturer;
  final String expiryDate;
  bool isPendingOrder;
  int pendingOrderQty;
  String? pendingOrderId;

  PharmacyItem({
    required this.id,
    required this.name,
    required this.composition,
    required this.category,
    required this.form,
    required this.stockQuantity,
    required this.minThreshold,
    required this.location,
    required this.pricePerUnit,
    required this.manufacturer,
    required this.expiryDate,
    this.isPendingOrder = false,
    this.pendingOrderQty = 0,
    this.pendingOrderId,
  });
}

class PharmacyOrderRequest {
  final String orderId;
  final String medicineName;
  final int quantity;
  final String priority;
  final String orderDate;
  final String requestedBy;
  String status;
  final String notes;

  PharmacyOrderRequest({
    required this.orderId,
    required this.medicineName,
    required this.quantity,
    required this.priority,
    required this.orderDate,
    required this.requestedBy,
    required this.status,
    required this.notes,
  });
}

class PharmacyStockScreen extends StatefulWidget {
  const PharmacyStockScreen({super.key});

  @override
  State<PharmacyStockScreen> createState() => _PharmacyStockScreenState();
}

class _PharmacyStockScreenState extends State<PharmacyStockScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All'; // 'All', 'In Stock', 'Low Stock', 'Out of Stock', 'Orders Pending'

  late List<PharmacyItem> _inventory;
  late List<PharmacyOrderRequest> _ordersList;

  @override
  void initState() {
    super.initState();
    _inventory = [
      PharmacyItem(
        id: 'MED-101',
        name: 'Paracetamol 650mg (Dolo 650)',
        composition: 'Paracetamol IP 650 mg',
        category: 'Analgesic / Antipyretic',
        form: 'Tablet',
        stockQuantity: 450,
        minThreshold: 50,
        location: 'Rack A-04, Shelf 2',
        pricePerUnit: 30.50,
        manufacturer: 'Micro Labs Ltd.',
        expiryDate: '11/2027',
      ),
      PharmacyItem(
        id: 'MED-102',
        name: 'Amoxicillin & Clavulanate 625mg (Augmentin)',
        composition: 'Amoxicillin 500mg + Potassium Clavulanate 125mg',
        category: 'Antibiotic',
        form: 'Tablet',
        stockQuantity: 15,
        minThreshold: 40,
        location: 'Rack B-02, Shelf 1',
        pricePerUnit: 185.00,
        manufacturer: 'GSK Pharmaceuticals',
        expiryDate: '08/2026',
      ),
      PharmacyItem(
        id: 'MED-103',
        name: 'Metformin 500mg ER (Glycomet)',
        composition: 'Metformin Hydrochloride 500 mg',
        category: 'Antidiabetic',
        form: 'Tablet',
        stockQuantity: 310,
        minThreshold: 60,
        location: 'Rack C-01, Shelf 3',
        pricePerUnit: 42.00,
        manufacturer: 'USV Pvt Ltd.',
        expiryDate: '03/2028',
      ),
      PharmacyItem(
        id: 'MED-104',
        name: 'Azithromycin 500mg (Azee 500)',
        composition: 'Azithromycin Dihydrate 500 mg',
        category: 'Antibiotic',
        form: 'Tablet',
        stockQuantity: 0,
        minThreshold: 30,
        location: 'Rack B-05, Shelf 4',
        pricePerUnit: 118.50,
        manufacturer: 'Cipla Ltd.',
        expiryDate: '05/2026',
      ),
      PharmacyItem(
        id: 'MED-105',
        name: 'Atorvastatin 10mg (Lipivas)',
        composition: 'Atorvastatin Calcium 10 mg',
        category: 'Cardiovascular / Statin',
        form: 'Tablet',
        stockQuantity: 180,
        minThreshold: 50,
        location: 'Rack D-03, Shelf 2',
        pricePerUnit: 78.00,
        manufacturer: 'Sun Pharmaceutical',
        expiryDate: '01/2027',
      ),
      PharmacyItem(
        id: 'MED-106',
        name: 'Insulin Glargine 100IU/ml (Lantus Pen)',
        composition: 'Recombinant Human Insulin Glargine 100 IU/ml',
        category: 'Antidiabetic',
        form: 'Injection Pen',
        stockQuantity: 6,
        minThreshold: 20,
        location: 'Cold Storage Refrigerator 1',
        pricePerUnit: 640.00,
        manufacturer: 'Sanofi India',
        expiryDate: '12/2026',
      ),
      PharmacyItem(
        id: 'MED-107',
        name: 'Ondansetron 4mg/2ml Inj (Emset)',
        composition: 'Ondansetron HCl 2 mg/ml',
        category: 'Anti-Emetic',
        form: 'Injection Vial',
        stockQuantity: 95,
        minThreshold: 25,
        location: 'Rack E-01, Shelf 1',
        pricePerUnit: 24.50,
        manufacturer: 'Cipla Ltd.',
        expiryDate: '09/2027',
      ),
      PharmacyItem(
        id: 'MED-108',
        name: 'Pantoprazole 40mg (Pan 40)',
        composition: 'Pantoprazole Sodium 40 mg',
        category: 'Gastroenterology / PPI',
        form: 'Tablet',
        stockQuantity: 520,
        minThreshold: 80,
        location: 'Rack A-02, Shelf 3',
        pricePerUnit: 54.00,
        manufacturer: 'Alkem Laboratories',
        expiryDate: '04/2028',
      ),
      PharmacyItem(
        id: 'MED-109',
        name: 'Levofloxacin 500mg (Levoquin)',
        composition: 'Levofloxacin Hemihydrate 500 mg',
        category: 'Antibiotic',
        form: 'Tablet',
        stockQuantity: 0,
        minThreshold: 25,
        location: 'Rack B-04, Shelf 2',
        pricePerUnit: 92.00,
        manufacturer: 'Lupin Ltd.',
        expiryDate: '10/2026',
        isPendingOrder: true,
        pendingOrderQty: 100,
        pendingOrderId: 'PO-4819',
      ),
      PharmacyItem(
        id: 'MED-110',
        name: 'Ceftriaxone 1g Inj (Monomax)',
        composition: 'Ceftriaxone Sodium 1000 mg',
        category: 'Antibiotic',
        form: 'Injection Vial',
        stockQuantity: 12,
        minThreshold: 30,
        location: 'Rack E-03, Shelf 2',
        pricePerUnit: 68.00,
        manufacturer: 'Aristo Pharmaceuticals',
        expiryDate: '02/2027',
      ),
    ];

    _ordersList = [
      PharmacyOrderRequest(
        orderId: 'PO-4819',
        medicineName: 'Levofloxacin 500mg (Levoquin)',
        quantity: 100,
        priority: 'Urgent Restock',
        orderDate: 'Today, 10:15 AM',
        requestedBy: 'Dr. Rajesh V. Sharma',
        status: 'In Transit (Dispatched by Supplier)',
        notes: 'Out of stock in OPD pharmacy. High patient demand.',
      ),
      PharmacyOrderRequest(
        orderId: 'PO-4790',
        medicineName: 'Inj Injection Paracetamol 100ml IV',
        quantity: 50,
        priority: 'Emergency Stat',
        orderDate: 'Yesterday, 04:30 PM',
        requestedBy: 'Dr. Ananya Sen',
        status: 'Approved by Pharmacy Admin',
        notes: 'For ICU & Emergency Ward requirement.',
      ),
    ];
    _loadLiveInventory();
  }

  Future<void> _loadLiveInventory() async {
    try {
      final liveItems = await ApiClient.getInventory();
      if (liveItems.isNotEmpty && mounted) {
        setState(() {
          for (final live in liveItems.reversed) {
            _inventory.removeWhere((i) => i.id == live.id || i.name == live.name);
            _inventory.insert(0, live);
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PharmacyItem> get _filteredInventory {
    final query = _searchController.text.trim().toLowerCase();
    return _inventory.where((item) {
      final matchesSearch = item.name.toLowerCase().contains(query) ||
          item.composition.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query) ||
          item.location.toLowerCase().contains(query) ||
          item.id.toLowerCase().contains(query);

      if (!matchesSearch) return false;

      if (_selectedFilter == 'In Stock') {
        return item.stockQuantity > item.minThreshold;
      } else if (_selectedFilter == 'Low Stock') {
        return item.stockQuantity > 0 && item.stockQuantity <= item.minThreshold;
      } else if (_selectedFilter == 'Out of Stock') {
        return item.stockQuantity == 0;
      } else if (_selectedFilter == 'Orders Pending') {
        return item.isPendingOrder;
      }
      return true;
    }).toList();
  }

  int get _lowStockCount => _inventory.where((i) => i.stockQuantity > 0 && i.stockQuantity <= i.minThreshold).length;
  int get _outOfStockCount => _inventory.where((i) => i.stockQuantity == 0).length;
  int get _pendingOrdersCount => _inventory.where((i) => i.isPendingOrder).length + _ordersList.length;

  void _placeOrderForItem(PharmacyItem item) {
    final qtyCtrl = TextEditingController(text: '100');
    final notesCtrl = TextEditingController();
    String priority = 'Routine Restock';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_shopping_cart_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Place Pharmacy Restock Order',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.headingText),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Current Stock: ${item.stockQuantity} strip(s) | Rack: ${item.location}',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Order Quantity (Strips/Units):',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.headingText),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'e.g. 50, 100, 200...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [50, 100, 200, 500].map((q) {
                        return ActionChip(
                          label: Text('+$q'),
                          onPressed: () => setDialogState(() => qtyCtrl.text = q.toString()),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'Order Priority Level:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.headingText),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: priority,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: ['Routine Restock', 'Urgent Restock', 'Emergency Stat Order']
                          .map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => priority = val);
                      },
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Justification / Pharmacy Notes',
                        hintText: 'e.g. High OPD prescription rate, urgent stock requirement...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final qty = int.tryParse(qtyCtrl.text) ?? 50;
                    final poNumber = 'PO-${(4000 + DateTime.now().millisecond % 5000)}';

                    setState(() {
                      item.isPendingOrder = true;
                      item.pendingOrderQty = qty;
                      item.pendingOrderId = poNumber;

                      _ordersList.insert(
                        0,
                        PharmacyOrderRequest(
                          orderId: poNumber,
                          medicineName: item.name,
                          quantity: qty,
                          priority: priority,
                          orderDate: 'Just Now',
                          requestedBy: 'Dr. Rajesh V. Sharma',
                          status: 'Order Placed (Submitted to Pharmacy)',
                          notes: notesCtrl.text.isEmpty ? 'Doctor stock replenishment request' : notesCtrl.text,
                        ),
                      );
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Order $poNumber placed for $qty units of ${item.name}!'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Submit Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addNewMedicineOrderDialog() {
    final nameCtrl = TextEditingController();
    final compCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '50');
    final notesCtrl = TextEditingController();
    String category = 'Antibiotic';
    String form = 'Tablet';
    String priority = 'Routine Restock';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.post_add_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Request New Unlisted Medicine',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.headingText),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Medicine Trade Name & Strength',
                        hintText: 'e.g. Ciprofloxacin 500mg',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: compCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Salt Composition',
                        hintText: 'e.g. Ciprofloxacin Hydrochloride 500mg',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: category,
                            decoration: const InputDecoration(labelText: 'Category'),
                            items: ['Antibiotic', 'Analgesic', 'Cardiac', 'Antidiabetic', 'Respiratory', 'Other']
                                .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12))))
                                .toList(),
                            onChanged: (val) => setDialogState(() => category = val!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: form,
                            decoration: const InputDecoration(labelText: 'Form'),
                            items: ['Tablet', 'Capsule', 'Injection', 'Syrup', 'IV Drip']
                                .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 12))))
                                .toList(),
                            onChanged: (val) => setDialogState(() => form = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Initial Order Quantity (Units/Strips)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Clinical Justification for Pharmacy Admin',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.isNotEmpty) {
                      final poNum = 'PO-${(5000 + DateTime.now().millisecond % 4000)}';
                      final newItem = PharmacyItem(
                        id: 'MED-${(200 + _inventory.length)}',
                        name: nameCtrl.text,
                        composition: compCtrl.text.isEmpty ? nameCtrl.text : compCtrl.text,
                        category: category,
                        form: form,
                        stockQuantity: 0,
                        minThreshold: 30,
                        location: 'Pending Pharmacy Assignment',
                        pricePerUnit: 0.0,
                        manufacturer: 'Special Procurement',
                        expiryDate: 'N/A',
                        isPendingOrder: true,
                        pendingOrderQty: int.tryParse(qtyCtrl.text) ?? 50,
                        pendingOrderId: poNum,
                      );

                      setState(() {
                        _inventory.add(newItem);
                        _ordersList.insert(
                          0,
                          PharmacyOrderRequest(
                            orderId: poNum,
                            medicineName: newItem.name,
                            quantity: newItem.pendingOrderQty,
                            priority: priority,
                            orderDate: 'Just Now',
                            requestedBy: 'Dr. Rajesh V. Sharma',
                            status: 'Special Procurement Order Requested',
                            notes: notesCtrl.text.isEmpty ? 'New medicine addition request' : notesCtrl.text,
                          ),
                        );
                      });

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Order $poNum created for new medicine "${newItem.name}"!'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  },
                  child: const Text('Submit Order Request'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPlacedOrdersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.local_shipping_outlined, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Active Pharmacy Reorder Requests',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.headingText),
                            ),
                            Text(
                              'Track restock status & pending shipments',
                              style: TextStyle(fontSize: 12, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _ordersList.length,
                  itemBuilder: (context, index) {
                    final ord = _ordersList[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                ord.orderId,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.infoBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  ord.status,
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.info),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ord.medicineName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.headingText),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Qty Requested: ${ord.quantity} Strips • Priority: ${ord.priority}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.bodyText),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Order Date: ${ord.orderDate} • By: ${ord.requestedBy}',
                            style: const TextStyle(fontSize: 11, color: AppColors.muted),
                          ),
                          if (ord.notes.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Notes: ${ord.notes}',
                              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.muted),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredInventory;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pharmacy Stock & Orders',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Ashwini Central Pharmacy • Real-Time Inventory',
              style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add_check_rounded, color: Colors.white),
            tooltip: 'View Active Restock Orders',
            onPressed: _showPlacedOrdersSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Inventory Overview Stats Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatChip('Total Items', '${_inventory.length}', AppColors.primary),
                _buildStatChip('Low Stock', '$_lowStockCount', AppColors.warning),
                _buildStatChip('Out of Stock', '$_outOfStockCount', AppColors.danger),
                GestureDetector(
                  onTap: _showPlacedOrdersSheet,
                  child: _buildStatChip('Orders Pending', '$_pendingOrdersCount', AppColors.info),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Search & Add New Order Controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search medicine name, salt, rack...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: AppColors.muted),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _addNewMedicineOrderDialog,
                  icon: const Icon(Icons.add, size: 18, color: Colors.white),
                  label: const Text('Order New', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Filter Tab Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['All', 'In Stock', 'Low Stock', 'Out of Stock', 'Orders Pending'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.bodyText,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedFilter = filter);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 10),

          // Inventory List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 48, color: AppColors.muted),
                        const SizedBox(height: 12),
                        Text(
                          'No medicine matching "$_selectedFilter" query.',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.headingText),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tap "Order New" above to request a custom medicine restock.',
                          style: TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _buildInventoryCard(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildInventoryCard(PharmacyItem item) {
    Color statusColor;
    Color statusBg;
    String statusText;

    if (item.stockQuantity == 0) {
      statusColor = AppColors.danger;
      statusBg = AppColors.dangerBg;
      statusText = 'OUT OF STOCK (0 Units)';
    } else if (item.stockQuantity <= item.minThreshold) {
      statusColor = AppColors.warning;
      statusBg = AppColors.warningBg;
      statusText = 'LOW STOCK (${item.stockQuantity} Left)';
    } else {
      statusColor = AppColors.success;
      statusBg = AppColors.successBg;
      statusText = 'IN STOCK (${item.stockQuantity} Strips)';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.stockQuantity == 0 ? AppColors.danger.withValues(alpha: 0.3) : AppColors.border,
          width: item.stockQuantity == 0 ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusBg.withValues(alpha: 0.6),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.headingText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Salt: ${item.composition}',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.bodyText, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Grid
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.category_outlined, size: 15, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${item.category} (${item.form})',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.headingText),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 15, color: AppColors.info),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.location,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.info),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Supplier: ${item.manufacturer}',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                      ),
                    ),
                    Text(
                      'Unit Price: ₹${item.pricePerUnit.toStringAsFixed(2)} | Exp: ${item.expiryDate}',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Order Status Banner if order is already pending
                if (item.isPendingOrder) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppColors.infoBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.pending_actions_rounded, size: 18, color: AppColors.info),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Order Request Active (${item.pendingOrderId ?? "PO-4819"}) — ${item.pendingOrderQty} Strips Ordered',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.info),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Min Threshold: ${item.minThreshold} strips',
                      style: const TextStyle(fontSize: 11, color: AppColors.muted, fontStyle: FontStyle.italic),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _placeOrderForItem(item),
                      icon: Icon(
                        item.isPendingOrder ? Icons.add_shopping_cart : Icons.shopping_bag_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(
                        item.isPendingOrder ? 'Reorder Additional' : 'Place Restock Order',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: item.stockQuantity == 0 ? AppColors.danger : AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
