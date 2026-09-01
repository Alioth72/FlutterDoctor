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
    return GovernmentScheme(
      schemeId: json['scheme_id'] as String? ?? 'SCHEME_001',
      schemeName: json['scheme_name'] as String? ?? 'Government Health Scheme',
      level: json['level'] as String? ?? 'Central',
      state: json['state'] as String?,
      shortDescription: json['short_description'] as String? ?? '',
      benefitsSummary: (json['benefits_summary'] as List?)?.map((e) => e.toString()).toList() ?? [],
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
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
    return SchemeDetail(
      schemeId: json['scheme_id'] as String? ?? '',
      schemeName: json['scheme_name'] as String? ?? '',
      level: json['level'] as String?,
      state: json['state'] as String?,
      schemeCategory: json['scheme_category'] as String?,
      details: json['details'] as String? ?? '',
      benefits: json['benefits'] as String? ?? '',
      benefitsList: (json['benefits_list'] as List?)?.map((e) => e.toString()).toList() ?? [],
      eligibilityText: json['eligibility_text'] as String? ?? '',
      applicationProcess: json['application_process'] as String? ?? '',
      applicationSteps: (json['application_steps'] as List?)?.map((e) => e.toString()).toList() ?? [],
      documents: json['documents'] as String? ?? '',
      documentsList: (json['documents_list'] as List?)?.map((e) => e.toString()).toList() ?? [],
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      officialUrl: json['official_url'] as String?,
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
    return EligibilityCheckResult(
      totalEvaluated: (json['total_schemes_evaluated'] as num?)?.toInt() ?? 0,
      likelyEligibleCount: (json['likely_eligible_count'] as num?)?.toInt() ?? 0,
      verificationRequiredCount: (json['verification_required_count'] as num?)?.toInt() ?? 0,
      likelyNotEligibleCount: (json['likely_not_eligible_count'] as num?)?.toInt() ?? 0,
      profileSummary: json['profile_summary'] as String? ?? '',
      schemes: (json['results'] as List?)
              ?.map((item) => GovernmentScheme.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
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
