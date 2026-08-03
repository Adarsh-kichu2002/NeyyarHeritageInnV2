import 'package:flutter/material.dart';
import 'package:neyyar_heritage/screens/history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  /// 🔐 ROLE
  String role = 'admin';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    role = args?['role'] ?? 'admin';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /// ✅ STAFF → NO BOTTOM NAV
      bottomNavigationBar: role == 'staff'
          ? null
          : BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              items: const [
                BottomNavigationBarItem(
                    icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.history), label: 'History'),
              ],
            ),

      body: SafeArea(
        child: role == 'staff'
            ? _staffHome(context) // 👇 STAFF VIEW
            : (_currentIndex == 0
                ? _adminHome(context)
                : const HistoryScreen()),
      ),
    );
  }

  /// ==============================
  /// 👑 ADMIN FULL ACCESS
  /// ==============================
  Widget _adminHome(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Image.asset('assets/images/neyyar_logo.png', height: 80),
          const SizedBox(height: 40),

          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _actionBox(context,
                    icon: Icons.description,
                    title: 'Create Quotation',
                    route: '/create_quotation'),

                _actionBox(context,
                    icon: Icons.book_online_outlined,
                    title: 'Bookings',
                    route: '/confirm_screen'),

                _actionBox(context,
                    icon: Icons.receipt_long,
                    title: 'Create Bill',
                    route: '/bill_screen'),

                _actionBox(context,
                    icon: Icons.list_alt_outlined,
                    title: 'Bills',
                    route: '/bills_screen'),

                _actionBox(context,
                    icon: Icons.receipt_outlined,
                    title: 'GST',
                    route: '/gst_screen'),

                _actionBox(context,
                    icon: Icons.time_to_leave_outlined,
                    title: 'Create Itinerary',
                    route: '/create_itinerary'),

                _actionBox(context,
                    icon: Icons.place_outlined,
                    title: 'Itineraries',
                    route: '/itinerary_screen'),

                _actionBox(context,
                    icon: Icons.hotel_outlined,
                    title: 'Room Occupancy',
                    route: '/room_occupancy'),

                _actionBox(context,
                    icon: Icons.bar_chart_outlined,
                    title: 'Room Charts',
                    route: '/room_chart'),

                _actionBox(context,
                    icon: Icons.assessment_outlined,
                    title: 'Reports',
                    route: '/reports_screen'),     

                _actionBox(context,
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Total Income',
                    route: '/total_income'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ==============================
  /// 👨‍💼 STAFF LIMITED ACCESS
  /// ==============================
  Widget _staffHome(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Image.asset('assets/images/neyyar_logo.png', height: 80),
          const SizedBox(height: 40),

          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                /// ✅ ONLY ALLOWED SCREENS

                _actionBox(context,
                    icon: Icons.check_circle_outline,
                    title: 'Confirmed Quotations',
                    route: '/confirm_screen'),

                _actionBox(context,
                    icon: Icons.list_alt_outlined,
                    title: 'Bills',
                    route: '/bills_screen'),

                _actionBox(context,
                    icon: Icons.place_outlined,
                    title: 'Itineraries',
                    route: '/itinerary_screen'),

                _actionBox(context,
                    icon: Icons.bar_chart_outlined,
                    title: 'Room Charts',
                    route: '/room_chart'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ==============================
  /// COMMON ACTION BOX
  /// ==============================
  Widget _actionBox(BuildContext context,
      {required IconData icon,
      required String title,
      required String route}) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      child: Card(
        elevation: 4,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: Colors.blue),
              const SizedBox(height: 10),
              Text(title),
            ],
          ),
        ),
      ),
    );
  }
}
