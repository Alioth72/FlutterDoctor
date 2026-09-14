import 'package:flutter_test/flutter_test.dart';
import 'package:sih_project/services/ocr/pp_ocr_v6_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PP-OCRv6 Small Prescription Detection & Dosage Instruction Tests', () {
    final ocrService = PpOcrV6Service.instance;

    test('1. Acute OPD Prescription: Extracts medicines, timing (1-0-1, 0-0-1) & meal instructions', () async {
      final detected = await ocrService.processPrescription(
        assetPath: 'assets/images/sample_rx_acute.jpg',
      );

      expect(detected.length, greaterThanOrEqualTo(3));

      // Paracetamol 650mg
      final pcm = detected.firstWhere((m) => m.matchedCatalogId == 'med_1');
      expect(pcm.name, contains('Paracetamol'));
      expect(pcm.strength, '650mg');
      expect(pcm.frequency, '1-0-1');
      expect(pcm.morning, isTrue);
      expect(pcm.afternoon, isFalse);
      expect(pcm.night, isTrue);
      expect(pcm.timingLabel, contains('Morning & Night'));
      expect(pcm.mealInstruction, contains('Food'));
      expect(pcm.howToTake, isNotEmpty);
      expect(pcm.isSelected, isTrue, reason: 'Must be auto-selected');
      expect(pcm.savingsPercent, greaterThan(60.0));

      // Amoxyclav 625mg
      final amox = detected.firstWhere((m) => m.matchedCatalogId == 'med_2');
      expect(amox.name, contains('Amoxicillin'));
      expect(amox.frequency, '1-0-1');
      expect(amox.morning, isTrue);
      expect(amox.night, isTrue);
      expect(amox.duration, contains('5 days'));
      expect(amox.isSelected, isTrue);

      // Cetirizine 10mg
      final cet = detected.firstWhere((m) => m.matchedCatalogId == 'med_8');
      expect(cet.name, contains('Cetirizine'));
      expect(cet.frequency, '0-0-1');
      expect(cet.morning, isFalse);
      expect(cet.afternoon, isFalse);
      expect(cet.night, isTrue);
      expect(cet.mealInstruction, contains('Bedtime'));
      expect(cet.isSelected, isTrue);
    });

    test('2. Chronic Care Prescription: Extracts Metformin, Atorvastatin & Pantoprazole with Empty Stomach instructions', () async {
      final detected = await ocrService.processPrescription(
        assetPath: 'assets/images/sample_rx_chronic.jpg',
      );

      expect(detected.length, greaterThanOrEqualTo(3));

      // Pantoprazole 40mg - Empty stomach check
      final panto = detected.firstWhere((m) => m.matchedCatalogId == 'med_7');
      expect(panto.name, contains('Pantoprazole'));
      expect(panto.frequency, '1-0-0');
      expect(panto.morning, isTrue);
      expect(panto.afternoon, isFalse);
      expect(panto.night, isFalse);
      expect(panto.mealInstruction.toLowerCase(), contains('empty stomach'));
      expect(panto.howToTake.toLowerCase(), contains('before breakfast'));
      expect(panto.isSelected, isTrue);

      // Metformin 500mg
      final met = detected.firstWhere((m) => m.matchedCatalogId == 'med_3');
      expect(met.name, contains('Metformin'));
      expect(met.frequency, '1-0-1');
      expect(met.morning, isTrue);
      expect(met.night, isTrue);
      expect(met.mealInstruction.toLowerCase(), contains('food'));
      expect(met.isSelected, isTrue);

      // Atorvastatin 10mg - Bedtime check
      final ator = detected.firstWhere((m) => m.matchedCatalogId == 'med_4');
      expect(ator.name, contains('Atorvastatin'));
      expect(ator.frequency, '0-0-1');
      expect(ator.morning, isFalse);
      expect(ator.night, isTrue);
      expect(ator.mealInstruction.toLowerCase(), contains('bedtime'));
      expect(ator.isSelected, isTrue);
    });

    test('3. Dynamic camera capture fallback: All medicines auto-selected with full schedule details', () async {
      final detected = await ocrService.processPrescription();

      expect(detected.isNotEmpty, isTrue);
      for (final med in detected) {
        expect(med.isSelected, isTrue, reason: 'All detected items must be auto-selected');
        expect(med.timingLabel, isNotEmpty);
        expect(med.mealInstruction, isNotEmpty);
        expect(med.howToTake, isNotEmpty);
        expect(med.duration, isNotEmpty);
        expect(med.price, greaterThan(0));
        expect(med.mrp, greaterThan(med.price));
      }
    });
  });
}
