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

    test('3. Dynamic image OCR: Recognizes medicines from prescription image bytes', () async {
      final detected = await ocrService.processPrescription(
        assetPath: 'assets/images/sample_rx_acute.jpg',
      );

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

    test('4. Gemini 18-Key Rotation Pool Integrity', () {
      expect(PpOcrV6Service.apiKeysCount, 18, reason: 'Must contain all 18 verified active Gemini API keys');
    });

    test('5. Gemini Multimodal Clinical JSON Parser & Jan Aushadhi Savings Matching', () {
      const mockGeminiJson = '''
      [
        {
          "name": "Tab Paracetamol",
          "strength": "650mg",
          "dosage_form": "Tablet",
          "frequency": "1-0-1",
          "morning": true,
          "afternoon": false,
          "night": true,
          "timing_label": "Morning & Night (Twice daily)",
          "meal_instruction": "After Food",
          "how_to_take": "Take with 1 glass of water after food.",
          "duration": "5 Days",
          "raw_text": "Tab Paracetamol 650mg 1-0-1 x 5d"
        },
        {
          "name": "Cap Amoxyclav",
          "strength": "625mg",
          "dosage_form": "Capsule",
          "frequency": "1-0-1",
          "morning": true,
          "afternoon": false,
          "night": true,
          "timing_label": "Morning & Night",
          "meal_instruction": "After Food",
          "how_to_take": "Take with water at start of meal.",
          "duration": "5 Days",
          "raw_text": "Cap Amoxyclav 625mg 1-0-1 x 5d"
        },
        {
          "name": "Tab Cetirizine",
          "strength": "10mg",
          "dosage_form": "Tablet",
          "frequency": "0-0-1",
          "morning": false,
          "afternoon": false,
          "night": true,
          "timing_label": "Night (Once daily)",
          "meal_instruction": "At Bedtime",
          "how_to_take": "Take 1 tablet before sleeping.",
          "duration": "5 Days",
          "raw_text": "Tab Cetirizine 10mg 0-0-1 x 5d"
        }
      ]
      ''';

      final results = ocrService.parseGeminiJsonResponse(mockGeminiJson);
      expect(results.length, 3);

      final pcm = results.firstWhere((m) => m.matchedCatalogId == 'med_1');
      expect(pcm.name, contains('Paracetamol'));
      expect(pcm.strength, '650mg');
      expect(pcm.frequency, '1-0-1');
      expect(pcm.morning, isTrue);
      expect(pcm.afternoon, isFalse);
      expect(pcm.night, isTrue);
      expect(pcm.mealInstruction, 'After Food');
      expect(pcm.savingsPercent, greaterThan(65.0));
      expect(pcm.price, 12.0);
      expect(pcm.mrp, 42.0);

      final amox = results.firstWhere((m) => m.matchedCatalogId == 'med_2');
      expect(amox.name, contains('Amoxicillin'));
      expect(amox.strength, '625mg');
      expect(amox.frequency, '1-0-1');
      expect(amox.price, 48.0);
      expect(amox.mrp, 160.0);
      expect(amox.savingsPercent, greaterThan(65.0));

      final cet = results.firstWhere((m) => m.matchedCatalogId == 'med_8');
      expect(cet.name, contains('Cetirizine'));
      expect(cet.strength, '10mg');
      expect(cet.frequency, '0-0-1');
      expect(cet.price, 10.0);
      expect(cet.mrp, 38.0);
      expect(cet.savingsPercent, greaterThan(70.0));
    });
  });
}

