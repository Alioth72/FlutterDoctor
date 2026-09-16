import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/government_scheme.dart';
import '../../providers/schemes_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/dynamic_translated_text.dart';

class SchemeDetailScreen extends StatefulWidget {
  final String schemeId;
  final GovernmentScheme? basicScheme;

  const SchemeDetailScreen({
    super.key,
    required this.schemeId,
    this.basicScheme,
  });

  @override
  State<SchemeDetailScreen> createState() => _SchemeDetailScreenState();
}

class _SchemeDetailScreenState extends State<SchemeDetailScreen> {
  SchemeDetail? _detail;
  AiExplanation? _aiExplanation;
  bool _isLoading = true;
  bool _isAiLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSchemeDetails();
  }

  Future<void> _loadSchemeDetails() async {
    final provider = Provider.of<SchemesProvider>(context, listen: false);
    try {
      final detail = await provider.fetchSchemeDetail(widget.schemeId);
      if (mounted) {
        setState(() {
          _detail = detail;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _requestAiExplanation() async {
    setState(() => _isAiLoading = true);
    final provider = Provider.of<SchemesProvider>(context, listen: false);
    final ai = await provider.explainWithAi(widget.schemeId);
    if (mounted) {
      setState(() {
        _aiExplanation = ai;
        _isAiLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = _detail;
    final eval = scheme?.evaluation ?? widget.basicScheme?.evaluation;

    final langProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(langProvider.tr('govt_benefits_title')),
        elevation: 0,
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16.0 + (MediaQuery.viewPaddingOf(context).bottom > 20
              ? (MediaQuery.viewPaddingOf(context).bottom * 0.35 + 6.0)
              : 0.0),
        ),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -2),
              blurRadius: 6,
            ),
          ],
        ),
        child: SafeArea(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              final url = scheme?.officialUrl ?? 'https://www.myscheme.gov.in';
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(langProvider.tr('official_portal_title')),
                  content: Text('${langProvider.tr('official_portal_title')}:\n$url\n\n${langProvider.tr('eligibility_engine_note')}.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(langProvider.tr('close_btn'))),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${langProvider.tr('open_portal_btn')}: $url')),
                        );
                      },
                      child: Text(langProvider.tr('open_portal_btn')),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 20),
            label: Text(
              langProvider.tr('apply_website_btn'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Scheme Name Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.local_hospital_rounded,
                          size: 32,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DynamicTranslatedText(
                              text: scheme?.schemeName ?? widget.basicScheme?.schemeName ?? 'Government Health Scheme',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DynamicTranslatedText(
                              text: '${scheme?.level ?? "National"} • ${scheme?.schemeCategory ?? "Health & Family Welfare"}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Eligibility Status Banner
                  if (eval != null) _buildStatusBanner(context, eval),
                  const SizedBox(height: 22),

                  // 1. DETAILS Section
                  _buildSectionHeader(context, title: langProvider.tr('scheme_details_title'), icon: Icons.info_outline_rounded),
                  const SizedBox(height: 10),
                  DynamicTranslatedText(
                    text: scheme?.details ?? 'Detailed information regarding the scheme and clinical subsidies.',
                    style: const TextStyle(fontSize: 14, height: 1.45, color: Colors.black87),
                  ),
                  const SizedBox(height: 22),

                  // 2. BENEFITS Section
                  _buildSectionHeader(context, title: langProvider.tr('benefits_title'), icon: Icons.verified_rounded),
                  const SizedBox(height: 10),
                  if (scheme != null && scheme.benefitsList.isNotEmpty)
                    ...scheme.benefitsList.map((b) => _buildBulletItem(b, icon: Icons.check_circle_outline, color: theme.colorScheme.primary))
                  else
                    DynamicTranslatedText(text: scheme?.benefits ?? 'Comprehensive healthcare coverage.'),
                  const SizedBox(height: 22),

                  // 3. WHY YOU MAY BE ELIGIBLE
                  if (eval != null) ...[
                    _buildSectionHeader(context, title: langProvider.tr('why_eligible_title'), icon: Icons.rule_rounded),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: eval.status == 'likely_eligible'
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: eval.status == 'likely_eligible'
                              ? const Color(0xFFA5D6A7)
                              : const Color(0xFFFFE082),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (eval.matchedRules.isNotEmpty)
                            ...eval.matchedRules.map((m) => _buildCheckItem(m, isPass: true)),
                          if (eval.missingInformation.isNotEmpty)
                            ...eval.missingInformation.map((m) => _buildCheckItem(m, isPass: false, isWarning: true)),
                          if (eval.failedRules.isNotEmpty)
                            ...eval.failedRules.map((f) => _buildCheckItem(f, isPass: false)),
                          const SizedBox(height: 8),
                          DynamicTranslatedText(
                            text: eval.reason,
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                  ],

                  // 4. DOCUMENTS REQUIRED
                  _buildSectionHeader(context, title: langProvider.tr('documents_required'), icon: Icons.description_outlined),
                  const SizedBox(height: 10),
                  if (scheme != null && scheme.documentsList.isNotEmpty)
                    ...scheme.documentsList.map((d) => _buildBulletItem(d, icon: Icons.article_outlined, color: Colors.indigo))
                  else
                    DynamicTranslatedText(text: scheme?.documents ?? 'Aadhaar Card, Income Proof, Residence Certificate.'),
                  const SizedBox(height: 22),

                  // 5. HOW TO APPLY
                  _buildSectionHeader(context, title: langProvider.tr('how_to_apply'), icon: Icons.how_to_reg_rounded),
                  const SizedBox(height: 10),
                  if (scheme != null && scheme.applicationSteps.isNotEmpty)
                    ...scheme.applicationSteps.asMap().entries.map((entry) {
                      return _buildNumberedStep(context, entry.key + 1, entry.value);
                    })
                  else
                    DynamicTranslatedText(text: scheme?.applicationProcess ?? 'Apply online or visit your local health centre.'),
                  const SizedBox(height: 24),

                  // 6. GROUNDED AI EXPLAINER CARD
                  _buildAiExplainerCard(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusBanner(BuildContext context, RuleEvaluation eval) {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    Color bg;
    Color border;
    Color text;
    IconData icon;

    if (eval.status == 'likely_eligible') {
      bg = const Color(0xFFE8F5E9);
      border = const Color(0xFF81C784);
      text = const Color(0xFF2E7D32);
      icon = Icons.check_circle_rounded;
    } else if (eval.status == 'verification_required') {
      bg = const Color(0xFFFFF8E1);
      border = const Color(0xFFFFD54F);
      text = const Color(0xFFF57F17);
      icon = Icons.pending_actions_rounded;
    } else {
      bg = const Color(0xFFFFEBEE);
      border = const Color(0xFFEF9A9A);
      text = const Color(0xFFC62828);
      icon = Icons.cancel_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: text, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DynamicTranslatedText(
                  text: eval.statusLabel,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: text,
                  ),
                ),
                Text(
                  langProvider.tr('eligibility_engine_note'),
                  style: TextStyle(fontSize: 11, color: text.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, {required String title, required IconData icon}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildBulletItem(String text, {required IconData icon, required Color color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: DynamicTranslatedText(
              text: text,
              style: const TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String text, {required bool isPass, bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWarning
                ? Icons.warning_amber_rounded
                : (isPass ? Icons.check_circle_rounded : Icons.cancel_rounded),
            size: 16,
            color: isWarning ? Colors.amber.shade900 : (isPass ? Colors.green.shade800 : Colors.red.shade800),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DynamicTranslatedText(
              text: text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isWarning ? Colors.amber.shade900 : (isPass ? Colors.green.shade900 : Colors.red.shade900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberedStep(BuildContext context, int stepNum, String stepText) {
    final theme = Theme.of(context);
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.25), width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${langProvider.tr('step_label')} $stepNum',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DynamicTranslatedText(
              text: stepText,
              style: const TextStyle(fontSize: 13, height: 1.45, fontWeight: FontWeight.w500, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiExplainerCard(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCE93D8), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFF8E24AA),
                child: Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  langProvider.tr('ai_explainer_title'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            langProvider.tr('ai_explainer_sub'),
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          if (_aiExplanation == null) ...[
            FilledButton.tonalIcon(
              onPressed: _isAiLoading ? null : _requestAiExplanation,
              icon: _isAiLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.psychology_rounded),
              label: Text(_isAiLoading ? langProvider.tr('analyzing_scheme_msg') : langProvider.tr('explain_simple_btn')),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE1BEE7)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DynamicTranslatedText(
                    text: _aiExplanation!.explanation,
                    style: const TextStyle(fontSize: 13, height: 1.45, color: Colors.black87),
                  ),
                  if (_aiExplanation!.keyHighlights.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 16, color: Color(0xFF8E24AA)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            langProvider.tr('key_highlights_title'),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ..._aiExplanation!.keyHighlights.map(
                      (h) => Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8E24AA))),
                            Expanded(child: DynamicTranslatedText(text: h, style: const TextStyle(fontSize: 12, height: 1.3))),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_aiExplanation!.requiredDocuments.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.folder_shared_rounded, size: 16, color: Color(0xFF1565C0)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            langProvider.tr('docs_checklist_title'),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ..._aiExplanation!.requiredDocuments.map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, size: 15, color: Color(0xFF1976D2)),
                            const SizedBox(width: 6),
                            Expanded(child: DynamicTranslatedText(text: d, style: const TextStyle(fontSize: 12, height: 1.35, color: Colors.black87))),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_aiExplanation!.nextSteps.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.directions_walk_rounded, size: 16, color: Color(0xFF2E7D32)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            langProvider.tr('village_guide_title'),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ..._aiExplanation!.nextSteps.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 9,
                              backgroundColor: const Color(0xFF2E7D32),
                              child: Text(
                                '${entry.key + 1}',
                                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: DynamicTranslatedText(text: entry.value, style: const TextStyle(fontSize: 12, height: 1.35, color: Colors.black87))),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  DynamicTranslatedText(
                    text: 'Source: ${_aiExplanation!.source}',
                    style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
