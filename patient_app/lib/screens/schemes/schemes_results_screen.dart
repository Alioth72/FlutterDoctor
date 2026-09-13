import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/government_scheme.dart';
import '../../providers/schemes_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/dynamic_translated_text.dart';
import 'eligibility_form_screen.dart';
import 'scheme_detail_screen.dart';

class SchemesResultsScreen extends StatefulWidget {
  const SchemesResultsScreen({super.key});

  @override
  State<SchemesResultsScreen> createState() => _SchemesResultsScreenState();
}

class _SchemesResultsScreenState extends State<SchemesResultsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = Provider.of<SchemesProvider>(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    final profile = provider.profile;
    final results = provider.results;

    if (provider.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              langProvider.tr('evaluating_schemes'),
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final allSchemes = provider.filteredSchemes;
    final displayedSchemes = _searchQuery.isEmpty
        ? allSchemes
        : allSchemes.where((s) {
            return s.schemeName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                s.tags.any((t) => t.toLowerCase().contains(_searchQuery.toLowerCase()));
          }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        if (profile != null) {
          await provider.evaluateEligibility(profile);
        }
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 32.0),
        itemCount: displayedSchemes.isEmpty ? 2 : displayedSchemes.length + 1,
        itemBuilder: (context, index) {
          // Item 0: Header, Profile Summary, Search, Filters
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Profile Summary Card with [ Update Information ]
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFA5D6A7), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_pin_rounded, color: Color(0xFF2E7D32), size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              langProvider.tr('based_on_profile'),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            DynamicTranslatedText(
                              text: profile?.summaryText ?? 'Age: 25 • Delhi • ₹1–2.5 L income',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          side: const BorderSide(color: Color(0xFF2E7D32), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EligibilityFormScreen(initialProfile: profile),
                            ),
                          );
                        },
                        child: Text(
                          langProvider.tr('update_btn'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 2. Header & Subtitle
                Text(
                  langProvider.tr('govt_health_benefits'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  langProvider.tr('schemes_eligible_subtitle'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Search Bar
                TextField(
                  stylusHandwritingEnabled: false,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: langProvider.tr('search_schemes_hint'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Filter Categories (🟢 You May Be Eligible • 🟡 Verification Required • 🔴 Likely Not Eligible)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: '${langProvider.tr('filter_all')} (${results?.totalEvaluated ?? results?.schemes.length ?? 0})',
                        value: 'all',
                        isSelected: provider.selectedFilter == 'all',
                        onTap: () => provider.setFilter('all'),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: '🟢 ${langProvider.tr('filter_likely_eligible')} (${results?.likelyEligibleCount ?? 0})',
                        value: 'likely_eligible',
                        isSelected: provider.selectedFilter == 'likely_eligible',
                        activeColor: const Color(0xFFE8F5E9),
                        activeBorder: const Color(0xFF81C784),
                        onTap: () => provider.setFilter('likely_eligible'),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: '🟡 ${langProvider.tr('filter_verification_req')} (${results?.verificationRequiredCount ?? 0})',
                        value: 'verification_required',
                        isSelected: provider.selectedFilter == 'verification_required',
                        activeColor: const Color(0xFFFFF8E1),
                        activeBorder: const Color(0xFFFFD54F),
                        onTap: () => provider.setFilter('verification_required'),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: '🔴 ${langProvider.tr('filter_likely_not_eligible')} (${results?.likelyNotEligibleCount ?? 0})',
                        value: 'likely_not_eligible',
                        isSelected: provider.selectedFilter == 'likely_not_eligible',
                        activeColor: const Color(0xFFFFEBEE),
                        activeBorder: const Color(0xFFEF9A9A),
                        onTap: () => provider.setFilter('likely_not_eligible'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          }

          // Empty State
          if (displayedSchemes.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(
                      langProvider.tr('no_schemes_found'),
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            );
          }

          // Items 1..N: Scheme Cards
          final scheme = displayedSchemes[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14.0),
            child: _buildSchemeCard(context, scheme),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required bool isSelected,
    required VoidCallback onTap,
    Color? activeColor,
    Color? activeBorder,
  }) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      selected: isSelected,
      selectedColor: activeColor ?? theme.colorScheme.primaryContainer,
      side: BorderSide(
        color: isSelected ? (activeBorder ?? theme.colorScheme.primary) : Colors.grey.shade300,
        width: isSelected ? 1.5 : 1.0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (_) => onTap(),
    );
  }

  /// Scheme Card matching requirements
  Widget _buildSchemeCard(BuildContext context, GovernmentScheme scheme) {
    final theme = Theme.of(context);
    final eval = scheme.evaluation;

    Color badgeBg;
    Color badgeBorder;
    Color badgeText;
    if (eval.status == 'likely_eligible') {
      badgeBg = const Color(0xFFE8F5E9);
      badgeBorder = const Color(0xFFA5D6A7);
      badgeText = const Color(0xFF2E7D32);
    } else if (eval.status == 'verification_required') {
      badgeBg = const Color(0xFFFFF8E1);
      badgeBorder = const Color(0xFFFFE082);
      badgeText = const Color(0xFFF57F17);
    } else {
      badgeBg = const Color(0xFFFFEBEE);
      badgeBorder = const Color(0xFFFFCDD2);
      badgeText = const Color(0xFFC62828);
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade300, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Hospital Icon
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.local_hospital_rounded, color: theme.colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: DynamicTranslatedText(
                    text: scheme.schemeName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: badgeBorder, width: 1.2),
              ),
              child: Text(
                eval.status == 'likely_eligible'
                    ? '🟢 ${Provider.of<LanguageProvider>(context, listen: false).tr('filter_likely_eligible')}'
                    : (eval.status == 'verification_required'
                        ? '🟡 ${Provider.of<LanguageProvider>(context, listen: false).tr('filter_verification_req')}'
                        : '🔴 ${Provider.of<LanguageProvider>(context, listen: false).tr('filter_likely_not_eligible')}'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: badgeText,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Short Description
            DynamicTranslatedText(
              text: scheme.shortDescription,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.black87,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),

            // Benefits Summary Chips
            if (scheme.benefitsSummary.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: scheme.benefitsSummary.map((benefit) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DynamicTranslatedText(
                      text: benefit,
                      prefix: '• ',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Action: View Details
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SchemeDetailScreen(
                        schemeId: scheme.schemeId,
                        basicScheme: scheme,
                      ),
                    ),
                  );
                },
                icon: Text(
                  Provider.of<LanguageProvider>(context, listen: false).tr('view_details'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                label: const Icon(Icons.arrow_forward_rounded, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
