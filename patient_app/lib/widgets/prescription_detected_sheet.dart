import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ocr/pp_ocr_v6_service.dart';

/// Modal sheet displaying medicines detected from scanned prescription.
/// Explicitly shows dosage timing (Morning/Afternoon/Night),
/// how to take instructions (Empty Stomach vs After Meals),
/// Jan Aushadhi generic savings, and auto-selected checkboxes.
class PrescriptionDetectedSheet extends StatefulWidget {
  final List<DetectedMedicine> medicines;
  final String? assetPath;
  final Uint8List? imageBytes;
  final Function(List<DetectedMedicine> selected) onAddToCart;

  const PrescriptionDetectedSheet({
    super.key,
    required this.medicines,
    this.assetPath,
    this.imageBytes,
    required this.onAddToCart,
  });

  @override
  State<PrescriptionDetectedSheet> createState() => _PrescriptionDetectedSheetState();
}

class _PrescriptionDetectedSheetState extends State<PrescriptionDetectedSheet> {
  late List<DetectedMedicine> _items;

  @override
  void initState() {
    super.initState();
    // Default all items to selected for auto-selection
    _items = widget.medicines;
    for (final item in _items) {
      item.isSelected = true;
    }
  }

  int get _selectedCount => _items.where((m) => m.isSelected).length;

  double get _totalPrice =>
      _items.where((m) => m.isSelected).fold(0.0, (sum, m) => sum + m.price);

  double get _totalMrp =>
      _items.where((m) => m.isSelected).fold(0.0, (sum, m) => sum + m.mrp);

  double get _totalSavings => math.max(0.0, _totalMrp - _totalPrice);

  void _showFullScreenPrescription(BuildContext context) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Header Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.document_scanner_rounded, color: Color(0xFFA78BFA), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Prescription Document',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Interactive Pinch-to-Zoom Image
              Container(
                color: const Color(0xFF0F172A),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.70,
                  minHeight: 220,
                  minWidth: double.infinity,
                ),
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.5,
                  clipBehavior: Clip.none,
                  child: Center(
                    child: widget.imageBytes != null
                        ? Image.memory(
                            widget.imageBytes!,
                            fit: BoxFit.contain,
                          )
                        : Image.asset(
                            widget.assetPath!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Text(
                                'Unable to render image',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ),
                  ),
                ),
              ),

              // Bottom Control & Zoom Hint Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFF0F172A),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.pinch_rounded, color: Color(0xFF94A3B8), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Pinch with two fingers to zoom • Drag to pan',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.document_scanner_rounded, color: Color(0xFF7C3AED), size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detected Medicines',
                        style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: Color(0xFF1E1B4B)),
                      ),
                      Text(
                        'Auto-Selected for You',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Prescription Attachment Preview Strip (Clickable to view full image)
          if (widget.imageBytes != null || widget.assetPath != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showFullScreenPrescription(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      // Thumbnail with zoom badge
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: widget.imageBytes != null
                                ? Image.memory(
                                    widget.imageBytes!,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                  )
                                : Image.asset(
                                    widget.assetPath!,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: 52,
                                      height: 52,
                                      color: const Color(0xFFEDE9FE),
                                      child: const Icon(Icons.receipt_rounded, color: Color(0xFF7C3AED)),
                                    ),
                                  ),
                          ),
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(
                                Icons.zoom_in_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                                SizedBox(width: 4),
                                Text(
                                  'Prescription Attached',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_items.length} medicine${_items.length == 1 ? '' : 's'} extracted • Tap to view photo',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      // Distinct "View Photo" action pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFDDD6FE)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fullscreen_rounded, size: 15, color: Color(0xFF7C3AED)),
                            SizedBox(width: 4),
                            Text(
                              'View',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Instruction Callout
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF7C3AED)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All detected medicines have been auto-selected below. Review dosage & schedule.',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF5B21B6)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Scrollable List of Detected Medicines or Empty State
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: const Icon(
                              Icons.document_scanner_outlined,
                              size: 42,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No Medicines Detected',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E1B4B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'The text could not be clearly recognized from this photo. Please retake the photo with better lighting or select your medicine directly from the Jan Aushadhi list.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.grey.shade600,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final med = _items[i];
                      return _buildMedicineCard(med);
                    },
                  ),
          ),
          const SizedBox(height: 14),

          // Total Savings & Add-to-Cart Action Bar
          if (_items.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_selectedCount of ${_items.length} Selected',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                      ),
                      Text(
                        '₹${_totalPrice.toStringAsFixed(0)} • Save ₹${_totalSavings.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Color(0xFF14532D)),
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: _selectedCount > 0
                        ? () {
                            HapticFeedback.heavyImpact();
                            final chosen = _items.where((m) => m.isSelected).toList();
                            Navigator.pop(context);
                            widget.onAddToCart(chosen);
                          }
                        : null,
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                    label: Text('Add $_selectedCount to Cart'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Close & Search Manually'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Color(0xFF7C3AED)),
                  foregroundColor: const Color(0xFF7C3AED),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(DetectedMedicine med) {
    return Container(
      decoration: BoxDecoration(
        color: med.isSelected ? const Color(0xFFFAF5FF) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: med.isSelected ? const Color(0xFF8B5CF6) : const Color(0xFFE2E8F0),
          width: med.isSelected ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title, Checkbox & Price Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: med.isSelected,
                  activeColor: const Color(0xFF7C3AED),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    setState(() => med.isSelected = val ?? false);
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Medicine Name & Generic
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      med.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1B4B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Generic: ${med.genericName}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),

              // Price & Savings Badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${med.price.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF7C3AED)),
                  ),
                  Text(
                    'MRP ₹${med.mrp.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Divider
          const Divider(height: 1, color: Color(0xFFEDE9FE)),
          const SizedBox(height: 8),

          // TIMING & SCHEDULE BADGES (Morning, Afternoon, Night)
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF7C3AED)),
              const SizedBox(width: 5),
              const Text(
                'Dosage Timing: ',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
              ),
              const SizedBox(width: 4),
              _buildTimeSlotBadge('Morning', '🌅', med.morning),
              const SizedBox(width: 4),
              _buildTimeSlotBadge('Noon', '☀️', med.afternoon),
              const SizedBox(width: 4),
              _buildTimeSlotBadge('Night', '🌙', med.night),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  med.frequency,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFF6D28D9)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // HOW TO TAKE (Administration Instructions)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.restaurant_rounded, size: 13, color: Color(0xFFD97706)),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How to take: ${med.mealInstruction}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                      ),
                      Text(
                        med.howToTake,
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    med.duration,
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlotBadge(String label, String icon, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: active ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 9)),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
              color: active ? const Color(0xFF15803D) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
