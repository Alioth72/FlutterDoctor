// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sih_project/services/ocr/pp_ocr_v6_service.dart';

class _RealNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _RealNetworkHttpOverrides();
  });

  group('Live Gemini 2.5 Flash Multimodal Vision Prescription OCR', () {
    final service = PpOcrV6Service.instance;

    test('Live call: Extract medicines from sample_rx_acute.jpg via Gemini API', () async {
      final file = File('assets/images/sample_rx_acute.jpg');
      expect(file.existsSync(), isTrue, reason: 'Sample prescription image must exist');

      final bytes = await file.readAsBytes();
      print('Sending ${bytes.length} bytes to Gemini 2.5 Flash...');

      final stopwatch = Stopwatch()..start();
      final detected = await service.processPrescription(imageBytes: bytes);
      stopwatch.stop();

      print('Gemini Vision OCR completed in ${stopwatch.elapsedMilliseconds} ms');
      print('Detected ${detected.length} medicines:');
      for (final med in detected) {
        print(' - [${med.matchedCatalogId}] ${med.name} (${med.strength})');
        print('   Frequency: ${med.frequency}, Timing: ${med.timingLabel}');
        print('   Meal: ${med.mealInstruction}, How to take: ${med.howToTake}');
        print('   Price: ₹${med.price}, MRP: ₹${med.mrp}, Savings: ${med.savingsPercent.toStringAsFixed(1)}%');
      }

      expect(detected.isNotEmpty, isTrue, reason: 'Should detect prescribed medicines');
      expect(detected.length, greaterThanOrEqualTo(2));

      final hasParacetamolOrAmox = detected.any((m) =>
          m.name.toLowerCase().contains('paracetamol') ||
          m.name.toLowerCase().contains('amoxicillin') ||
          m.matchedCatalogId == 'med_1' ||
          m.matchedCatalogId == 'med_2');
      expect(hasParacetamolOrAmox, isTrue);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('Live call: Extract medicines from sample_rx_chronic.jpg via Gemini API', () async {
      final file = File('assets/images/sample_rx_chronic.jpg');
      expect(file.existsSync(), isTrue);

      final bytes = await file.readAsBytes();
      final detected = await service.processPrescription(imageBytes: bytes);

      print('Detected ${detected.length} chronic care medicines:');
      for (final med in detected) {
        print(' - [${med.matchedCatalogId}] ${med.name} (${med.strength}) | ${med.frequency} | ${med.mealInstruction}');
      }

      expect(detected.isNotEmpty, isTrue);
      final hasChronicMeds = detected.any((m) =>
          m.name.toLowerCase().contains('pantoprazole') ||
          m.name.toLowerCase().contains('metformin') ||
          m.name.toLowerCase().contains('atorvastatin') ||
          m.matchedCatalogId == 'med_7' ||
          m.matchedCatalogId == 'med_3' ||
          m.matchedCatalogId == 'med_4');
      expect(hasChronicMeds, isTrue);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
