import 'package:flutter_test/flutter_test.dart';
import 'package:sih_project/services/localization/healthcare_catalog.dart';
import 'package:sih_project/services/localization/indic_transliterator.dart';
import 'package:sih_project/services/localization/sarvam_translation_service.dart';

void main() {
  setUp(() async {
    await SarvamTranslationService.init();
  });

  test('Debug HealthcareCatalog and Sarvam Translation', () async {
    const title1 = 'Scheme for Containing Population Decline of Small Minority Communities ';
    const title2 = 'Pradhan Mantri Ujjwala Yojana';
    const loc = 'Kasturba Gandhi Marg, New Delhi';

    final title1Pa = HealthcareCatalog.lookup(title1, 'pa');
    expect(title1Pa, 'ਛੋਟੇ ਘੱਟ ਗਿਣਤੀ ਭਾਈਚਾਰਿਆਂ ਦੀ ਆਬਾਦੀ ਵਿੱਚ ਗਿਰਾਵਟ ਨੂੰ ਰੋਕਣ ਲਈ ਸਕੀਮ');

    final title2Pa = HealthcareCatalog.lookup(title2, 'pa');
    expect(title2Pa, 'ਪ੍ਰਧਾਨ ਮੰਤਰੀ ਉੱਜਵਲਾ ਯੋਜਨਾ');

    final locPa = HealthcareCatalog.lookup(loc, 'pa');
    expect(locPa, 'ਕਸਤੂਰਬਾ ਗਾਂਧੀ ਮਾਰਗ, ਨਵੀਂ ਦਿੱਲੀ');

    expect(SarvamTranslationService.getCached(title1, 'pa'), title1Pa);
    expect(SarvamTranslationService.getCached(title2, 'pa'), title2Pa);
    expect(SarvamTranslationService.getCached(loc, 'pa'), locPa);

    const desc1 = "The objective of the scheme is to reverse the declining trend of Parsi population by adopting a scientific protocol and structured interventions, stabilize their population and increase the population of Parsis in India.";
    const desc2 = "A scheme by Ministry of Petroleum and Natural Gas for Providing free LPG connections to women belonging to the Below Poverty Line (BPL) households.";
    const benefitSample = "- **Infertility Treatment Assistance:** Financial assistance up to ₹6,00,000/-, including IVF (₹1,50,000/- per cycle for a maximum of 4 cycles), surrogacy, ICSI, and donor costs as per the approved treatment plan.  - **Childbearing Medical Expenses:** Financial assistance up to ₹4,00,000/- covering diagnostic tests, medicines, hospitalization, and delivery charges (₹2,00,000/- before delivery and remaining after delivery).";

    expect(HealthcareCatalog.lookup(desc1, 'pa'), isNotNull);
    expect(HealthcareCatalog.lookup(desc2, 'pa'), isNotNull);
    expect(HealthcareCatalog.lookup(benefitSample, 'pa'), isNotNull);

    final resDesc1 = await SarvamTranslationService.translate(desc1, targetLanguageCode: 'pa');
    expect(resDesc1.contains('ਪਾਰਸੀ'), true);

    final resDesc2 = await SarvamTranslationService.translate(desc2, targetLanguageCode: 'pa');
    expect(resDesc2.contains('ਐਲਪੀਜੀ'), true);

    final transliteratedDesc1 = IndicTransliterator.transliterateSentence(desc1, 'pa');
    expect(transliteratedDesc1.isNotEmpty, true);

    final transliteratedBenefit = IndicTransliterator.transliterateSentence(benefitSample, 'pa');
    expect(transliteratedBenefit.isNotEmpty, true);
  });
}
