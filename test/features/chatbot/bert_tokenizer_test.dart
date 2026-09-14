import 'package:flutter_test/flutter_test.dart';
import 'package:chatbot_healthcare/features/chatbot/chatbot_embedding.dart';

void main() {
  late BertTokenizer tokenizer;

  setUp(() {
    tokenizer = BertTokenizer();
  });

  group('BertTokenizer', () {
    test('tokenizes basic medical text and lowercases input', () {
      final tokens = tokenizer.tokenize('Chest Pain and FEVER');
      expect(tokens, containsAllInOrder(['chest', 'pain', 'and', 'fever']));
    });

    test('splits punctuation marks from alphanumeric tokens', () {
      final tokens = tokenizer.tokenize('fever, headache! (mild)');
      expect(
        tokens,
        ['fever', ',', 'headache', '!', '(', 'mild', ')'],
      );
    });

    test('handles subword segmentation using ## prefix', () {
      final tokens = tokenizer.tokenize('cardiomyopathy');
      expect(tokens.length, greaterThan(1));
      // Subwords after the first token must start with ##
      for (int i = 1; i < tokens.length; i++) {
        expect(tokens[i].startsWith('##'), isTrue);
      }
    });

    test('encodes text with [CLS] and [SEP] special tokens', () {
      final encoded = tokenizer.encode('iron deficiency anemia', maxSeqLength: 16);

      // Verify lengths
      expect(encoded.inputIds.length, 16);
      expect(encoded.attentionMask.length, 16);
      expect(encoded.tokenTypeIds.length, 16);

      // [CLS] at index 0
      expect(encoded.tokens.first, BertTokenizer.clsToken);
      expect(encoded.inputIds.first, BertTokenizer.clsId);
      expect(encoded.attentionMask.first, 1);

      // [SEP] at end of active tokens
      expect(encoded.tokens.last, BertTokenizer.sepToken);
      final activeCount = encoded.tokens.length;
      expect(encoded.inputIds[activeCount - 1], BertTokenizer.sepId);

      // Padding tokens
      for (int i = activeCount; i < 16; i++) {
        expect(encoded.inputIds[i], BertTokenizer.padId);
        expect(encoded.attentionMask[i], 0);
        expect(encoded.tokenTypeIds[i], 0);
      }
    });

    test('enforces maxSeqLength and truncates long text correctly', () {
      final longQuery = List.generate(30, (i) => 'symptom').join(' ');
      final encoded = tokenizer.encode(longQuery, maxSeqLength: 10);

      expect(encoded.inputIds.length, 10);
      expect(encoded.attentionMask.length, 10);
      expect(encoded.inputIds.first, BertTokenizer.clsId);
      expect(encoded.inputIds.last, BertTokenizer.sepId);
    });

    test('returns empty token list for empty or whitespace-only input', () {
      expect(tokenizer.tokenize(''), isEmpty);
      expect(tokenizer.tokenize('   '), isEmpty);
    });

    test('loads custom vocabulary from string correctly', () {
      final customVocabString = '''
[PAD]
[UNK]
[CLS]
[SEP]
[MASK]
anemia
fatigue
pallor
''';

      final customTokenizer = BertTokenizer();
      customTokenizer.loadVocabFromString(customVocabString);

      expect(customTokenizer.vocabSize, 8);
      final encoded = customTokenizer.encode('anemia fatigue', maxSeqLength: 6);
      expect(encoded.tokens, ['[CLS]', 'anemia', 'fatigue', '[SEP]']);
      expect(encoded.inputIds[1], 5); // ID of 'anemia'
      expect(encoded.inputIds[2], 6); // ID of 'fatigue'
    });
  });
}
