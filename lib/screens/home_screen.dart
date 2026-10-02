import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neyyar_heritage/screens/history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  DateTime? _lastBackPress;

  /// 🔐 ROLE
  String role = 'admin';

  static const Color _forest = Color(0xFF1B5E3B);
  static const Color _mint = Color(0xFFD7EEDC);
  static const Color _mintDeep = Color(0xFFC8E6C9);
  static const Color _iconBg = Color(0xFFC8E6C9);
  static const Color _pageBg = Color(0xFFF4F7F5);
  static const Color _subtitle = Color(0xFF6B7C72);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    role = args?['role'] ?? 'admin';
  }

  void _handleBack(bool didPop) {
    if (didPop) return;

    final now = DateTime.now();
    final withinWindow = _lastBackPress != null &&
        now.difference(_lastBackPress!) <= const Duration(seconds: 2);

    if (!withinWindow) {
      _lastBackPress = now;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final showNav = role != 'staff';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _handleBack(didPop),
      child: Scaffold(
        backgroundColor: _pageBg,
        // Overlay nav in a Stack — Scaffold's bottomNavigationBar slot
        // was painting the full-width white band behind the pill.
        body: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              bottom: false,
              child: role == 'staff'
                  ? _staffHome(context)
                  : (_currentIndex == 0
                      ? _adminHome(context)
                      : const HistoryScreen(bottomPadding: 100)),
            ),
            if (showNav)
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  child: _floatingBottomNav(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// ==============================
  /// 👑 ADMIN FULL ACCESS
  /// ==============================
  Widget _adminHome(BuildContext context) {
    const actions = <_HomeAction>[
      _HomeAction(
        icon: Icons.description_outlined,
        title: 'Create Quotation',
        subtitle: 'Create and send custom quotations',
        route: '/create_quotation',
      ),
      _HomeAction(
        icon: Icons.calendar_month_outlined,
        title: 'Bookings',
        subtitle: 'Manage room bookings',
        route: '/confirm_screen',
      ),
      _HomeAction(
        icon: Icons.receipt_long_outlined,
        title: 'Create Bill',
        subtitle: 'Create homestay bills',
        route: '/bill_screen',
      ),
      _HomeAction(
        icon: Icons.checklist_outlined,
        title: 'Bills',
        subtitle: 'View homestay bills',
        route: '/bills_screen',
      ),
      _HomeAction(
        icon: Icons.restaurant_outlined,
        title: 'Create Restaurant Bill',
        subtitle: 'Create restaurant bills',
        route: '/restaurant_customer',
        passRole: true,
      ),
      _HomeAction(
        icon: Icons.ramen_dining_outlined,
        title: 'Restaurant Bills',
        subtitle: 'View restaurant bills',
        route: '/restaurant_bills',
        passRole: true,
      ),
      _HomeAction(
        icon: Icons.restaurant_menu_outlined,
        title: 'Manage Restaurant Items',
        subtitle: 'Add and edit menu items',
        route: '/restaurant_item_management',
        passRole: true,
      ),
      _HomeAction(
        icon: Icons.receipt_outlined,
        title: 'GST',
        subtitle: 'GST invoices and reports',
        route: '/gst_screen',
      ),
      _HomeAction(
        icon: Icons.directions_car_outlined,
        title: 'Create Itinerary',
        subtitle: 'Plan guest itineraries',
        route: '/create_itinerary',
      ),
      _HomeAction(
        icon: Icons.place_outlined,
        title: 'Itineraries',
        subtitle: 'View and manage itineraries',
        route: '/itinerary_screen',
      ),
      _HomeAction(
        icon: Icons.hotel_outlined,
        title: 'Room Occupancy',
        subtitle: 'Check room availability',
        route: '/room_occupancy',
      ),
      _HomeAction(
        icon: Icons.bar_chart_outlined,
        title: 'Room Charts',
        subtitle: 'Visual room occupancy charts',
        route: '/room_chart',
      ),
      _HomeAction(
        icon: Icons.assessment_outlined,
        title: 'Reports',
        subtitle: 'View business reports',
        route: '/reports_screen',
      ),
      _HomeAction(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Total Income',
        subtitle: 'Track all income',
        route: '/total_income',
      ), 
    ];

    return _homeScroll(context, actions);
  }

  /// ==============================
  /// 👨‍💼 STAFF LIMITED ACCESS
  /// ==============================
  Widget _staffHome(BuildContext context) {
    const actions = <_HomeAction>[
      _HomeAction(
        icon: Icons.calendar_month_outlined,
        title: 'Bookings',
        subtitle: 'Manage room bookings',
        route: '/confirm_screen',
      ),
      _HomeAction(
        icon: Icons.checklist_outlined,
        title: 'Bills',
        subtitle: 'View homestay bills',
        route: '/bills_screen',
      ),
      _HomeAction(
        icon: Icons.restaurant_outlined,
        title: 'Create Restaurant Bill',
        subtitle: 'Create restaurant bills',
        route: '/restaurant_customer',
        passRole: true,
      ),
      _HomeAction(
        icon: Icons.ramen_dining_outlined,
        title: 'Restaurant Bills',
        subtitle: 'View restaurant bills',
        route: '/restaurant_bills',
        passRole: true,
      ),
      _HomeAction(
        icon: Icons.place_outlined,
        title: 'Itineraries',
        subtitle: 'View and manage itineraries',
        route: '/itinerary_screen',
      ),
      _HomeAction(
        icon: Icons.bar_chart_outlined,
        title: 'Room Charts',
        subtitle: 'Visual room occupancy charts',
        route: '/room_chart',
      ),
    ];

    return _homeScroll(context, actions, bottomPad: 16);
  }

  Widget _homeScroll(
    BuildContext context,
    List<_HomeAction> actions, {
    double bottomPad = 100,
  }) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _topHeader()),
        SliverToBoxAdapter(child: _heroBanner()),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.55,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _actionCard(context, actions[index]),
              childCount: actions.length,
            ),
          ),
        ),
      ],
    );
  }

  /// Logo only — no notification / profile icons
  Widget _topHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ColoredBox(
          color: _pageBg,
          child: Image.asset(
            'assets/images/neyyar_logo.png',
            height: 72,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }

  Widget _heroBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 168,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/home_hero.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
              // Left green wash so welcome text stays readable
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      _forest.withValues(alpha: 0.92),
                      _forest.withValues(alpha: 0.72),
                      _forest.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.35, 0.62, 1.0],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 22, 100, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome!',
                      style: TextStyle(
                        color: _mintDeep,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Manage bookings, bills & itineraries with ease.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                bottom: 12,
                child: Icon(
                  Icons.eco_outlined,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionCard(BuildContext context, _HomeAction action) {
    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      shadowColor: _forest.withValues(alpha: 0.12),
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          action.route,
          arguments: action.passRole ? {'role': role} : null,
        ),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: _iconBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(action.icon, size: 20, color: _forest),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  action.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _forest,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  action.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _subtitle,
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _floatingBottomNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: _navItem(
                index: 0,
                icon: Icons.home_rounded,
                label: 'Home',
              ),
            ),
            Container(
              width: 1,
              height: 28,
              color: Colors.grey.shade200,
            ),
            Expanded(
              child: _navItem(
                index: 1,
                icon: Icons.history_rounded,
                label: 'History',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? _mint : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? _forest : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
                color: selected ? _forest : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final bool passRole;

  const _HomeAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    this.passRole = false,
  });
}
