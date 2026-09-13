import 'package:flutter_test/flutter_test.dart';
import 'package:sih_project/services/localization/healthcare_catalog.dart';
import 'package:sih_project/services/localization/sarvam_translation_service.dart';
import 'package:sih_project/services/localization/app_strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Catalog Purity and Zero-English Verification Tests', () {
    test('User Test Case 1: Loan Based Schemes For Safai Karamchari - Sanitary Marts Scheme', () {
      const titleEn = 'Loan Based Schemes For Safai Karamchari - Sanitary Marts Scheme';
      final bn = HealthcareCatalog.lookup(titleEn, 'bn');
      expect(bn, isNotNull);
      expect(bn, isNot(contains('Loan')));
      expect(bn, isNot(contains('Schemes')));
      expect(bn, isNot(contains('Sanitary')));
      expect(bn, contains('সাফাই'));
      expect(bn, contains('স্কিম'));

      final hi = HealthcareCatalog.lookup(titleEn, 'hi');
      expect(hi, isNotNull);
      expect(hi, isNot(contains('Loan')));
      expect(hi!.contains('सफ़ाई') || hi.contains('सफाई'), isTrue);
    });

    test('User Test Case 2: Sanitary Mart Brief Description', () {
      const descEn = 'A sanitary mart is a one-stop-shop for all things for sanitation and hygiene. It is a shopping place where the sanitary needs of the common man could be met. It serves both as a shop and as a service centre.';
      final bn = HealthcareCatalog.lookup(descEn, 'bn');
      expect(bn, isNotNull);
      // Ensure zero phonetic transliteration gibberish like 'অ স্যানিটারয় মারত'
      expect(bn, isNot(contains('অ স্যানিটারয়')));
      expect(bn, contains('স্যানিটেশন'));
      expect(bn, contains('দোকান'));
    });

    test('User Test Case 3: Rastriya Arogya Nidhi - Health Minister’s Cancer Patient Fund', () {
      const titleEn = 'Rastriya Arogya Nidhi - Health Minister’s Cancer Patient Fund';
      final bn = HealthcareCatalog.lookup(titleEn, 'bn');
      expect(bn, isNotNull);
      expect(bn, isNot(contains('Health')));
      expect(bn, isNot(contains('Minister')));
      expect(bn, isNot(contains('Cancer')));
      expect(bn, isNot(contains('Patient')));
      expect(bn, contains('রাষ্ট্রীয়'));
      expect(bn, contains('ক্যান্সার'));
      expect(bn, contains('তহবিল'));
    });

    test('User Test Case 4: Cancer Patient Fund Brief Description', () {
      const descEn = 'The scheme-component aims to provide financial assistance to poor patients living below the poverty line and suffering from cancer, for their treatment at 27 Regional Cancer Centers (RCCs).';
      final bn = HealthcareCatalog.lookup(descEn, 'bn');
      expect(bn, isNotNull);
      expect(bn, isNot(contains('The')));
      expect(bn, isNot(contains('aims to provide')));
      expect(bn, isNot(contains('poor patients')));
      expect(bn, isNot(contains('below the poverty line')));
      expect(bn, contains('দারিদ্র্যসীমা'));
      expect(bn, contains('ক্যান্সার'));
      expect(bn, contains('আর্থিক সহায়তা'));
    });

    test('SarvamTranslationService.getCached returns pure Indic without English leaks', () {
      const titleEn = 'Rastriya Arogya Nidhi - Health Minister’s Cancer Patient Fund';
      final resBn = SarvamTranslationService.getCached(titleEn, 'bn');
      expect(resBn, isNotNull);
      expect(RegExp(r'[a-zA-Z]{2,}').hasMatch(resBn!), isFalse);
    });

    test('All 22 Indian Languages produce non-empty valid translations', () {
      const testTitle = 'Rastriya Arogya Nidhi - Health Minister’s Cancer Patient Fund';
      for (final lang in AppLanguages.supportedLanguages) {
        if (lang.code == 'en' || lang.code == 'en-IN') continue;
        final res = HealthcareCatalog.lookup(testTitle, lang.code);
        expect(res, isNotNull, reason: 'Failed for language ${lang.code}');
        expect(res!.trim().isNotEmpty, isTrue);
      }
    });
  });
}
