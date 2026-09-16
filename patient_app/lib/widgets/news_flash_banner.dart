import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../screens/rppg_screen.dart';
import '../screens/schemes/schemes_results_screen.dart';
import '../screens/tabs/appointments_tab.dart';

/// Data model representing a Poster / Banner item in the news flash carousel.
class NewsFlashItem {
  final String id;
  final String? imageUrl;
  final String? assetPath;
  final String? targetUrl;
  final String? label;
  final String? actionRoute;

  const NewsFlashItem({
    required this.id,
    this.imageUrl,
    this.assetPath,
    this.targetUrl,
    this.label,
    this.actionRoute,
  });
}

/// Service providing authentic national health scheme and service posters.
class NewsBannerService {
  static final List<NewsFlashItem> banners = [
    const NewsFlashItem(
      id: 'poster_pmjay',
      label: 'Ayushman Bharat PM-JAY',
      assetPath: 'assets/images/poster_pmjay.jpg',
      actionRoute: 'schemes',
    ),
    const NewsFlashItem(
      id: 'poster_rppg',
      label: 'AI Contactless Vitals Scan',
      assetPath: 'assets/images/poster_rppg.jpg',
      actionRoute: 'rppg',
    ),
    const NewsFlashItem(
      id: 'poster_teleconsult',
      label: 'National Rural Telemedicine',
      assetPath: 'assets/images/poster_teleconsult.jpg',
      actionRoute: 'appointments',
    ),
  ];
}

/// Full-width poster space carousel widget.
class NewsFlashBannerWidget extends StatefulWidget {
  final List<NewsFlashItem>? customBanners;
  final double height;

  const NewsFlashBannerWidget({
    super.key,
    this.customBanners,
    this.height = 175.0,
  });

  @override
  State<NewsFlashBannerWidget> createState() => _NewsFlashBannerWidgetState();
}

class _NewsFlashBannerWidgetState extends State<NewsFlashBannerWidget> {
  late final PageController _pageController;
  late final List<NewsFlashItem> _items;
  Timer? _autoSlideTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _items = widget.customBanners ?? NewsBannerService.banners;
    _pageController = PageController();
    _startTimer();
  }

  void _startTimer() {
    _autoSlideTimer?.cancel();
    if (_items.length <= 1) return;

    _autoSlideTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      final nextPage = (_currentPage + 1) % _items.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onPosterTap(NewsFlashItem item) {
    if (item.actionRoute == 'rppg') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const RppgScreen()),
      );
    } else if (item.actionRoute == 'schemes') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SchemesResultsScreen()),
      );
    } else if (item.actionRoute == 'appointments') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AppointmentsTab()),
      );
    } else if (item.targetUrl != null && item.targetUrl!.isNotEmpty) {
      // Future external redirect logic
    } else {
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      final labelText = item.id.isNotEmpty ? lang.tr(item.id) : (item.label ?? lang.tr('poster_space'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(labelText),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF7C3AED),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();
    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (idx) {
          setState(() {
            _currentPage = idx;
          });
        },
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.0),
            child: InkWell(
              onTap: () => _onPosterTap(item),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF5FF), // Soft clean lavender tint
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE9D5FF),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      // Poster Image (if provided later)
                      if (item.imageUrl != null)
                        Positioned.fill(
                          child: Image.network(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildBlankPlaceholder(item),
                          ),
                        )
                      else if (item.assetPath != null)
                        Positioned.fill(
                          child: Image.asset(
                            item.assetPath!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildBlankPlaceholder(item),
                          ),
                        )
                      else
                        // Blank Space for Poster (Waiting for future graphic and link)
                        Positioned.fill(
                          child: _buildBlankPlaceholder(item),
                        ),

                      // Carousel Page Dots (Bottom Center)
                      Positioned(
                        bottom: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                _items.length,
                                (dotIdx) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                  width: _currentPage == dotIdx ? 16 : 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: _currentPage == dotIdx
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Clean blank placeholder canvas ready for future poster graphics and links
  Widget _buildBlankPlaceholder(NewsFlashItem item) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDDD6FE), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.add_photo_alternate_outlined,
              size: 24,
              color: Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.id.isNotEmpty
                ? Provider.of<LanguageProvider>(context, listen: false).tr(item.id)
                : (item.label ?? Provider.of<LanguageProvider>(context, listen: false).tr('poster_space')),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6D28D9),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            Provider.of<LanguageProvider>(context, listen: false).tr('poster_sub'),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
