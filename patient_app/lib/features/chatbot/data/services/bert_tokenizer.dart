/// Output of the [BertTokenizer] containing tensor-ready sequences.
class TokenizedInput {
  const TokenizedInput({
    required this.inputIds,
    required this.attentionMask,
    required this.tokenTypeIds,
    required this.tokens,
  });

  final List<int> inputIds;
  final List<int> attentionMask;
  final List<int> tokenTypeIds;
  final List<String> tokens;

  @override
  String toString() => 'TokenizedInput(tokens: $tokens, length: ${inputIds.length})';
}

/// Pure-Dart implementation of BERT WordPiece tokenizer for medical queries.
class BertTokenizer {
  BertTokenizer({Map<String, int>? initialVocab}) {
    if (initialVocab != null) {
      _vocab = Map.from(initialVocab);
    } else {
      _vocab = _createDefaultMedicalVocab();
    }
    _rebuildIdToToken();
  }

  static const String padToken = '[PAD]';
  static const String unkToken = '[UNK]';
  static const String clsToken = '[CLS]';
  static const String sepToken = '[SEP]';
  static const String maskToken = '[MASK]';

  static const int padId = 0;
  static const int unkId = 100;
  static const int clsId = 101;
  static const int sepId = 102;
  static const int maskId = 103;

  late Map<String, int> _vocab;
  late Map<int, String> _idToToken;

  int get vocabSize => _vocab.length;

  String? idToToken(int id) => _idToToken[id];

  void loadVocabFromString(String content) {
    _vocab.clear();
    final lines = content.split(RegExp(r'\r?\n'));
    for (int i = 0; i < lines.length; i++) {
      final token = lines[i].trim();
      if (token.isNotEmpty) {
        _vocab[token] = i;
      }
    }
    _rebuildIdToToken();
  }

  void _rebuildIdToToken() {
    _idToToken = {for (final e in _vocab.entries) e.value: e.key};
  }

  List<String> tokenize(String text) {
    if (text.trim().isEmpty) return [];

    final normalized = text.toLowerCase().trim();
    final basicTokens = _basicTokenize(normalized);
    final result = <String>[];

    for (final token in basicTokens) {
      final subTokens = _wordPieceTokenize(token);
      result.addAll(subTokens);
    }

    return result;
  }

  TokenizedInput encode(String text, {int maxSeqLength = 64}) {
    final tokens = tokenize(text);
    final maxTokens = maxSeqLength > 2 ? maxSeqLength - 2 : 0;
    final truncatedTokens = tokens.length > maxTokens
        ? tokens.sublist(0, maxTokens)
        : tokens;

    final tokenList = <String>[clsToken, ...truncatedTokens, sepToken];

    final inputIds = <int>[];
    final attentionMask = <int>[];
    final tokenTypeIds = <int>[];

    for (final token in tokenList) {
      final id = _vocab[token] ?? unkId;
      inputIds.add(id);
      attentionMask.add(1);
      tokenTypeIds.add(0);
    }

    while (inputIds.length < maxSeqLength) {
      inputIds.add(padId);
      attentionMask.add(0);
      tokenTypeIds.add(0);
    }

    return TokenizedInput(
      inputIds: inputIds,
      attentionMask: attentionMask,
      tokenTypeIds: tokenTypeIds,
      tokens: tokenList,
    );
  }

  List<String> _basicTokenize(String text) {
    final regex = RegExp(r'[\w]+|[^\w\s]');
    return regex.allMatches(text).map((m) => m.group(0)!).toList();
  }

  List<String> _wordPieceTokenize(String word) {
    if (word.length > 100) return [unkToken];

    final subTokens = <String>[];
    int start = 0;
    bool isBad = false;

    while (start < word.length) {
      int end = word.length;
      String? curSubStr;

      while (start < end) {
        var sub = word.substring(start, end);
        if (start > 0) {
          sub = '##$sub';
        }

        if (_vocab.containsKey(sub)) {
          curSubStr = sub;
          break;
        }
        end--;
      }

      if (curSubStr == null) {
        isBad = true;
        break;
      }

      subTokens.add(curSubStr);
      start = end;
    }

    if (isBad) {
      return [unkToken];
    }
    return subTokens;
  }

  static Map<String, int> _createDefaultMedicalVocab() {
    final vocab = <String, int>{
      padToken: padId,
      unkToken: unkId,
      clsToken: clsId,
      sepToken: sepId,
      maskToken: maskId,
    };

    int nextId = 104;

    void addToken(String token) {
      if (!vocab.containsKey(token)) {
        vocab[token] = nextId++;
      }
    }

    for (int i = 97; i <= 122; i++) {
      final ch = String.fromCharCode(i);
      addToken(ch);
      addToken('##$ch');
    }
    for (int i = 48; i <= 57; i++) {
      final d = String.fromCharCode(i);
      addToken(d);
      addToken('##$d');
    }

    for (final p in [
      '.', ',', '?', '!', ':', ';', '-', '(', ')', '[', ']', '/', '\\', '%', '+', '='
    ]) {
      addToken(p);
    }

    final commonSubwords = [
      '##s', '##es', '##ed', '##ing', '##er', '##ly', '##al', '##ic', '##y',
      '##tion', '##sion', '##itis', '##oma', '##pathy', '##osis', '##emia',
      '##derm', '##cardio', '##myo', '##path', '##gen', '##ic', '##ous',
      '##ar', '##ate', '##able', '##ible', '##ment', '##ism', '##ist',
      '##t', '##d', '##n', '##m', '##r', '##l', '##e', '##a', '##o', '##u',
      '##an', '##in', '##on', '##at', '##or', '##re', '##de', '##un', '##dis'
    ];
    for (final sw in commonSubwords) {
      addToken(sw);
    }

    final coreTerms = [
      'what', 'is', 'are', 'the', 'causes', 'cause', 'symptom', 'symptoms',
      'treatment', 'treatments', 'diagnosis', 'how', 'to', 'treat', 'prevent',
      'pain', 'chest', 'head', 'headache', 'fever', 'cough', 'cold', 'flu',
      'blood', 'pressure', 'high', 'low', 'heart', 'attack', 'failure',
      'anemia', 'iron', 'deficiency', 'vitamin', 'weakness', 'fatigue',
      'skin', 'rash', 'hair', 'keratoderma', 'woolly',
      'disease', 'disorder', 'syndrome', 'infection', 'bacterial', 'viral',
      'diabetes', 'type', 'sugar', 'glucose', 'insulin', 'cancer', 'tumor',
      'severe', 'mild', 'acute', 'chronic', 'breathing', 'breath', 'shortness',
      'emergency', 'urgent', 'doctor', 'hospital', 'medicine', 'drug',
      'dose', 'allergy', 'allergic', 'asthma', 'kidney', 'liver', 'stomach',
      'nausea', 'vomiting', 'diarrhea', 'stroke', 'dizziness', 'seizure',
      'swelling', 'edema', 'inflammation', 'joint', 'arthritis', 'muscle',
      'medquad', 'nhp', 'india', 'guidelines', 'care', 'test', 'exam',
      'and', 'or', 'in', 'of', 'for', 'with', 'on', 'at', 'by', 'from',
      'as', 'into', 'like', 'through', 'after', 'over', 'between', 'out',
      'against', 'during', 'without', 'before', 'under', 'around', 'among',
      'a', 'an', 'this', 'that', 'these', 'those', 'my', 'your', 'his',
      'her', 'its', 'our', 'their', 'i', 'you', 'he', 'she', 'it', 'we',
      'they', 'me', 'him', 'us', 'them', 'have', 'has', 'had', 'do',
      'does', 'did', 'be', 'am', 'was', 'were', 'been', 'being', 'can',
      'could', 'will', 'would', 'shall', 'should', 'may', 'might', 'must',
      'not', 'no', 'yes', 'so', 'if', 'but', 'because', 'when', 'where',
      'which', 'who', 'whom', 'why', 'very', 'too', 'also', 'just'
    ];
    for (final term in coreTerms) {
      addToken(term);
    }

    return vocab;
  }
}
