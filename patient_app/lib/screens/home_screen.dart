import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import 'tabs/home_tab.dart';
import 'tabs/pharmacy_tab.dart';
import 'tabs/schemes_tab.dart';
import 'tabs/profile_tab.dart';
import '../widgets/patient_drawer.dart';
import '../widgets/dynamic_floating_voice_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeTab(),
    PharmacyTab(),
    SchemesTab(),
    ProfileTab(),
  ];

  String _getTitle(int index, LanguageProvider lang) {
    switch (index) {
      case 0:
        return lang.tr('app_name');
      case 1:
        return lang.tr('nav_pharmacy');
      case 2:
        return lang.tr('nav_schemes');
      case 3:
        return lang.tr('nav_profile');
      default:
        return lang.tr('app_name');
    }
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      key: _scaffoldKey,
      drawer: const PatientDrawer(),
      body: NestedScrollView(
        floatHeaderSlivers: true,
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              expandedHeight: 94.0,
              floating: true,
              pinned: false,
              snap: true,
              backgroundColor: const Color(0xFF7C3AED),
              surfaceTintColor: Colors.transparent,
              elevation: 4,
              shadowColor: const Color(0xFF7C3AED).withValues(alpha: 0.35),
              shape: const ConvexDownwardShapeBorder(arcHeight: 14.0),
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: ClipPath(
                  clipper: const ConvexDownwardClipper(arcHeight: 14.0),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x337C3AED),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          // Menu Hamburger Button
                          InkWell(
                            onTap: () => _scaffoldKey.currentState?.openDrawer(),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.28),
                                  width: 1.2,
                                ),
                              ),
                              child: const Icon(
                                Icons.menu_rounded,
                                size: 24,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Header Title & Portal Subtitle
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _getTitle(_currentIndex, langProvider),
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    if (_currentIndex == 0) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.22),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.35),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          langProvider.tr('patient_badge'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (_currentIndex == 0)
                                  Text(
                                    langProvider.tr('portal_title'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white.withValues(alpha: 0.82),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Ashwini Brand Logo on right
                          Container(
                            width: 44,
                            height: 44,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/images/ashwini_logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ];
        },
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                IndexedStack(
                  index: _currentIndex,
                  children: _screens,
                ),
                DynamicFloatingVoiceButton(
                  parentWidth: constraints.maxWidth,
                  parentHeight: constraints.maxHeight,
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: langProvider.tr('nav_home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.medication_outlined),
            selectedIcon: const Icon(Icons.medication_rounded),
            label: langProvider.tr('nav_pharmacy'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.health_and_safety_outlined),
            selectedIcon: const Icon(Icons.health_and_safety),
            label: langProvider.tr('nav_schemes'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: langProvider.tr('nav_profile'),
          ),
        ],
      ),
    );
  }
}

/// Custom ShapeBorder for SliverAppBar that curves smoothly downwards in a convex arc.
class ConvexDownwardShapeBorder extends ShapeBorder {
  final double arcHeight;

  const ConvexDownwardShapeBorder({this.arcHeight = 14.0});

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return getOuterPath(rect, textDirection: textDirection);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final path = Path();
    path.moveTo(rect.left, rect.top);
    path.lineTo(rect.left, rect.bottom - arcHeight);
    path.quadraticBezierTo(
      rect.left + rect.width / 2,
      rect.bottom + arcHeight,
      rect.right,
      rect.bottom - arcHeight,
    );
    path.lineTo(rect.right, rect.top);
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => ConvexDownwardShapeBorder(arcHeight: arcHeight * t);
}

/// Custom Clipper for the FlexibleSpaceBar background container to match the downward convex arc.
class ConvexDownwardClipper extends CustomClipper<Path> {
  final double arcHeight;

  const ConvexDownwardClipper({this.arcHeight = 14.0});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(0, size.height - arcHeight);
    path.quadraticBezierTo(
      size.width / 2,
      size.height + arcHeight,
      size.width,
      size.height - arcHeight,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant ConvexDownwardClipper oldClipper) =>
      oldClipper.arcHeight != arcHeight;
}
