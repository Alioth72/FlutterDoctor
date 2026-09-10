class RuleEvaluation {
  final String status; // likely_eligible, verification_required, likely_not_eligible
  final String statusLabel; // You may be eligible, Verification required, Likely not eligible
  final String statusBadge;
  final List<String> matchedRules;
  final List<String> failedRules;
  final List<String> missingInformation;
  final String reason;

  const RuleEvaluation({
    required this.status,
    required this.statusLabel,
    required this.statusBadge,
    this.matchedRules = const [],
    this.failedRules = const [],
    this.missingInformation = const [],
    required this.reason,
  });

  factory RuleEvaluation.fromJson(Map<String, dynamic> json) {
    return RuleEvaluation(
      status: json['status'] as String? ?? 'likely_eligible',
      statusLabel: json['status_label'] as String? ?? 'You may be eligible',
      statusBadge: json['status_badge'] as String? ?? '🟢 You May Be Eligible',
      matchedRules: (json['matched_rules'] as List?)?.map((e) => e.toString()).toList() ?? [],
      failedRules: (json['failed_rules'] as List?)?.map((e) => e.toString()).toList() ?? [],
      missingInformation: (json['missing_information'] as List?)?.map((e) => e.toString()).toList() ?? [],
      reason: json['reason'] as String? ?? 'Eligible based on demographic profile.',
    );
  }
}

class GovernmentScheme {
  final String schemeId;
  final String schemeName;
  final String? level;
  final String? state;
  final String shortDescription;
  final List<String> benefitsSummary;
  final List<String> tags;
  final RuleEvaluation evaluation;

  const GovernmentScheme({
    required this.schemeId,
    required this.schemeName,
    this.level,
    this.state,
    required this.shortDescription,
    this.benefitsSummary = const [],
    this.tags = const [],
    required this.evaluation,
  });

  factory GovernmentScheme.fromJson(Map<String, dynamic> json) {
    final rawId = json['scheme_id'] as String? ?? json['id'] as String? ?? 'SCHEME_001';
    final rawName = json['scheme_name'] as String? ?? json['name'] as String? ?? 'Government Health Scheme';
    final rawState = json['state'] as String? ?? json['eligible_state'] as String?;
    final rawLevel = json['level'] as String? ?? (rawState != null ? 'State' : 'Central');
    final rawDesc = json['short_description'] as String? ?? json['brief_description'] as String? ?? json['details'] as String? ?? '';

    // Parse benefits summary
    List<String> rawBenefits = [];
    if (json['benefits_summary'] is List) {
      rawBenefits = (json['benefits_summary'] as List).map((e) => e.toString()).toList();
    } else if (json['benefits'] is String && (json['benefits'] as String).isNotEmpty) {
      rawBenefits = (json['benefits'] as String)
          .split(RegExp(r'[\n•;.]'))
          .map((b) => b.trim())
          .where((b) => b.length > 5)
          .take(3)
          .toList();
    }

    // Parse tags
    List<String> rawTags = [];
    if (json['tags'] is List) {
      rawTags = (json['tags'] as List).map((e) => e.toString()).toList();
    } else if (json['tags'] is String && (json['tags'] as String).isNotEmpty) {
      rawTags = (json['tags'] as String)
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .take(4)
          .toList();
    }

    return GovernmentScheme(
      schemeId: rawId,
      schemeName: rawName,
      level: rawLevel,
      state: rawState,
      shortDescription: rawDesc,
      benefitsSummary: rawBenefits,
      tags: rawTags,
      evaluation: json['evaluation'] != null
          ? RuleEvaluation.fromJson(json['evaluation'] as Map<String, dynamic>)
          : const RuleEvaluation(
              status: 'likely_eligible',
              statusLabel: 'You may be eligible',
              statusBadge: '🟢 You May Be Eligible',
              reason: 'Criteria matched with standard parameters.',
            ),
    );
  }
}

class SchemeDetail {
  final String schemeId;
  final String schemeName;
  final String? level;
  final String? state;
  final String? schemeCategory;
  final String details;
  final String benefits;
  final List<String> benefitsList;
  final String eligibilityText;
  final String applicationProcess;
  final List<String> applicationSteps;
  final String documents;
  final List<String> documentsList;
  final List<String> tags;
  final String? officialUrl;
  final RuleEvaluation? evaluation;

  const SchemeDetail({
    required this.schemeId,
    required this.schemeName,
    this.level,
    this.state,
    this.schemeCategory,
    required this.details,
    required this.benefits,
    this.benefitsList = const [],
    required this.eligibilityText,
    required this.applicationProcess,
    this.applicationSteps = const [],
    required this.documents,
    this.documentsList = const [],
    this.tags = const [],
    this.officialUrl,
    this.evaluation,
  });

  factory SchemeDetail.fromJson(Map<String, dynamic> json) {
    final rawId = json['scheme_id'] as String? ?? json['id'] as String? ?? '';
    final rawName = json['scheme_name'] as String? ?? json['name'] as String? ?? '';
    final rawState = json['state'] as String? ?? json['eligible_state'] as String?;
    final rawLevel = json['level'] as String? ?? (rawState != null ? 'State' : 'Central');
    final rawCategory = json['scheme_category'] as String? ?? json['category'] as String? ?? 'Health & Wellness';
    final rawDetails = json['details'] as String? ?? json['detailed_description'] as String? ?? json['brief_description'] as String? ?? '';
    final rawDocs = json['documents'] as String? ?? json['documents_required'] as String? ?? '';
    final rawApp = json['application_process'] as String? ?? json['application'] as String? ?? '';
    final rawBenefits = json['benefits'] as String? ?? '';
    final rawUrl = json['official_url'] as String? ?? json['apply_url'] as String?;

    // Smart documents parser into points
    List<String> parsedDocs = (json['documents_list'] as List?)?.map((e) => e.toString()).toList() ?? [];
    if (parsedDocs.isEmpty || parsedDocs.length <= 1) {
      final cleanedDocs = rawDocs.replaceAll(RegExp(r'^(?:Copies of the following documents[^:-]*[:-]|Documents required[^:-]*[:-]|Following documents are required[^:-]*[:-])\s*', caseSensitive: false), '');
      final parts = cleanedDocs.split(RegExp(r'(?:\.\s+|\n+|•|;\s*)'));
      parsedDocs = parts
          .map((p) => p.trim())
          .where((p) => p.length > 3 && !p.toLowerCase().startsWith('note') && !p.toLowerCase().startsWith('for registration') && !p.toLowerCase().startsWith('for the application'))
          .toList();
      if (parsedDocs.isEmpty && rawDocs.isNotEmpty) {
        parsedDocs = [rawDocs];
      }
    }

    // Smart application steps parser
    List<String> parsedSteps = (json['application_steps'] as List?)?.map((e) => e.toString()).toList() ?? [];
    if (parsedSteps.isEmpty || parsedSteps.length <= 1) {
      final cleanedApp = rawApp.replaceAll(RegExp(r'[\ufeff\r\t]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      final stagePattern = RegExp(r'\s*(?:\b(?:Registration Process|Application Process of the Welfare Scheme|Application Process|Processing at [A-Za-z\s]+Secretariat|Processing at [A-Za-z\s]+|Payment Procedure|Track Application Status|Check Your Application Status|Pay Annual Contribution|Verification Process)\b:?\s*)', caseSensitive: false);
      final stages = cleanedApp.split(stagePattern);

      final rawChunks = <String>[];
      for (final stage in stages) {
        final stageClean = stage.replaceAll(RegExp(r'^[ .:-•]+|[ .:-•]+$'), '');
        if (stageClean.isEmpty) continue;
        final stepItems = stageClean.split(RegExp(r'(?:\bStep\s*\d+[:.]?|\bStep\s*[A-Za-z][:.]?|(?<=[.!?])\s+(?=[A-Z0-9]\.\s+|\d+\.\s+))', caseSensitive: false));
        for (final item in stepItems) {
          final itemClean = item.replaceAll(RegExp(r'^[ .:-•]+|[ .:-•]+$'), '');
          if (itemClean.length > 10) rawChunks.add(itemClean);
        }
      }

      final finalSteps = <String>[];
      for (final chunk in rawChunks) {
        final sentences = chunk.split(RegExp(r'(?<=[.!?])\s+(?=(?:Visit|Click|Upload|Save|Provide|Select|Once|After|Payment|Track|Download|Submit|Now|Revisit|Keep)\b)'));
        String buffer = '';
        for (final s in sentences) {
          final sClean = s.replaceAll(RegExp(r'^[ .:-•]+|[ .:-•]+$'), '');
          if (sClean.isEmpty) continue;
          if (buffer.isEmpty) {
            buffer = sClean;
          } else if (buffer.length + sClean.length < 160 && !buffer.endsWith('http://') && !buffer.endsWith('https://')) {
            buffer += '. $sClean';
          } else {
            finalSteps.add(buffer.endsWith('.') ? buffer : '$buffer.');
            buffer = sClean;
          }
        }
        if (buffer.isNotEmpty) {
          finalSteps.add(buffer.endsWith('.') ? buffer : '$buffer.');
        }
      }

      parsedSteps = [];
      for (final s in finalSteps) {
        if (parsedSteps.isNotEmpty && s.length < 40 && !s.toLowerCase().startsWith('step')) {
          final last = parsedSteps.removeLast();
          final cleanLast = last.endsWith('.') ? last.substring(0, last.length - 1) : last;
          parsedSteps.add('$cleanLast. $s');
        } else {
          parsedSteps.add(s);
        }
      }

      if (parsedSteps.isEmpty && rawApp.isNotEmpty) {
        parsedSteps = [rawApp];
      }
    }

    // Smart benefits parser
    List<String> parsedBenefits = (json['benefits_list'] as List?)?.map((e) => e.toString()).toList() ?? [];
    if (parsedBenefits.isEmpty || parsedBenefits.length <= 1) {
      parsedBenefits = rawBenefits
          .split(RegExp(r'[\n•;.]'))
          .map((b) => b.trim())
          .where((b) => b.length > 8)
          .toList();
    }

    return SchemeDetail(
      schemeId: rawId,
      schemeName: rawName,
      level: rawLevel,
      state: rawState,
      schemeCategory: rawCategory,
      details: rawDetails,
      benefits: rawBenefits,
      benefitsList: parsedBenefits,
      eligibilityText: json['eligibility_text'] as String? ?? json['eligibility'] as String? ?? '',
      applicationProcess: rawApp,
      applicationSteps: parsedSteps,
      documents: rawDocs,
      documentsList: parsedDocs,
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      officialUrl: rawUrl,
      evaluation: json['evaluation'] != null
          ? RuleEvaluation.fromJson(json['evaluation'] as Map<String, dynamic>)
          : null,
    );
  }
}

class EligibilityCheckResult {
  final int totalEvaluated;
  final int likelyEligibleCount;
  final int verificationRequiredCount;
  final int likelyNotEligibleCount;
  final String profileSummary;
  final List<GovernmentScheme> schemes;

  const EligibilityCheckResult({
    required this.totalEvaluated,
    required this.likelyEligibleCount,
    required this.verificationRequiredCount,
    required this.likelyNotEligibleCount,
    required this.profileSummary,
    required this.schemes,
  });

  factory EligibilityCheckResult.fromJson(Map<String, dynamic> json) {
    final schemesList = (json['results'] as List?) ?? (json['schemes'] as List?);
    final parsedSchemes = schemesList
            ?.map((item) => GovernmentScheme.fromJson(item as Map<String, dynamic>))
            .toList() ??
        [];

    final likelyCount = (json['likely_eligible_count'] as num?)?.toInt() ??
        parsedSchemes.where((s) => s.evaluation.status == 'likely_eligible').length;
    final verifCount = (json['verification_required_count'] as num?)?.toInt() ??
        parsedSchemes.where((s) => s.evaluation.status == 'verification_required').length;
    final notCount = (json['likely_not_eligible_count'] as num?)?.toInt() ??
        parsedSchemes.where((s) => s.evaluation.status == 'likely_not_eligible').length;

    return EligibilityCheckResult(
      totalEvaluated: (json['total_schemes_evaluated'] as num?)?.toInt() ??
          (json['available_count'] as num?)?.toInt() ??
          parsedSchemes.length,
      likelyEligibleCount: likelyCount,
      verificationRequiredCount: verifCount,
      likelyNotEligibleCount: notCount,
      profileSummary: json['profile_summary'] as String? ?? '',
      schemes: parsedSchemes,
    );
  }
}

class AiExplanation {
  final String schemeId;
  final String schemeName;
  final String explanation;
  final List<String> keyHighlights;
  final List<String> requiredDocuments;
  final List<String> nextSteps;
  final String source;

  const AiExplanation({
    required this.schemeId,
    required this.schemeName,
    required this.explanation,
    required this.keyHighlights,
    required this.requiredDocuments,
    required this.nextSteps,
    required this.source,
  });

  factory AiExplanation.fromJson(Map<String, dynamic> json) {
    return AiExplanation(
      schemeId: json['scheme_id'] as String? ?? '',
      schemeName: json['scheme_name'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      keyHighlights: (json['key_highlights'] as List?)?.map((e) => e.toString()).toList() ?? [],
      requiredDocuments: (json['required_documents'] as List?)?.map((e) => e.toString()).toList() ?? [],
      nextSteps: (json['next_steps'] as List?)?.map((e) => e.toString()).toList() ?? [],
      source: json['source'] as String? ?? 'Official Government Scheme Registry',
    );
  }
}
