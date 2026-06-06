import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';

import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/create_quotation_screen.dart';
import 'screens/room_select_screen.dart';
import 'screens/quotation_preview_screen.dart';
import 'screens/history_screen.dart';
import 'screens/quotation_history_tab.dart';
import 'history/quotation_history_store.dart';

import 'screens/bill_screen.dart';
import 'screens/bill_list_screen.dart';
import 'screens/bill_preview_screen.dart';
import 'screens/bill_history_tab.dart';
import 'history/bill_history_store.dart';
import 'screens/payment_screen.dart';
import 'screens/bills_screen.dart';

import 'screens/create_itinerary.dart';
import 'screens/itinerary_preview_screen.dart';
import 'history/itinerary_history.dart';
import 'screens/itinerary_history_tab.dart';
import 'screens/itinerary_screen.dart';

import 'screens/confirm_screen.dart';
import 'history/confirm_store.dart';

import 'screens/room_occupancy_screen.dart';
import 'screens/room_chart.dart';

import 'screens/reports_screen.dart';
import 'screens/money_chart_screen.dart';
import 'screens/money_report_screen.dart';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Firebase FIRST
  await Firebase.initializeApp();

  // SharedPreferences (optional but safe)
  await SharedPreferences.getInstance();

  runApp(const MyRoot());
}

class MyRoot extends StatelessWidget {
  const MyRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<QuotationHistoryStore>(
          create: (_) => QuotationHistoryStore(),
          lazy: false,
        ),
        ChangeNotifierProvider<BillHistoryStore>(
          create: (_) => BillHistoryStore(),
          lazy: false,
        ),
        ChangeNotifierProvider<ConfirmStore>(
          create: (_) => ConfirmStore(),
          lazy: false,
        ),
      ],
      child: const MyApp(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Neyyar Heritage Inn',

      theme: ThemeData(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),

      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/welcome': (_) => const WelcomeScreen(),
        '/home': (_) => const HomeScreen(),

        '/create_quotation': (_) => const CreateQuotationScreen(),
        '/room_select_screen': (_) => const RoomSelectScreen(),
        '/quotation_preview_screen': (_) => const QuotationPreviewScreen(),

        '/history': (_) => const HistoryScreen(),
        '/quotation_history_tab': (_) => const QuotationHistoryTab(),

        '/bill_screen': (_) => const BillScreen(),
        '/bill_list': (_) => const BillListScreen(),
        '/bill_preview': (_) => const BillPreviewScreen(),
        '/bill_history_tab': (_) => const BillHistoryTab(),
        '/payment_screen': (_) => const PaymentScreen(),
        '/bills_screen': (_) => const BillsScreen(),

        '/create_itinerary': (_) => const CreateItineraryScreen(),
        '/itinerary_preview': (_) =>  const ItineraryPreviewScreen(),  
        '/itinerary_history': (_) => const ItineraryHistoryScreen(),
        '/itinerary_history_tab': (_) => const ItineraryHistoryTab(docs: [], viewOnly: true,),
        '/itinerary_screen': (_) => const ItineraryScreen(),  

        '/confirm_screen': (_) => const ConfirmScreen(),

        '/room_occupancy': (_) => const RoomOccupancyScreen(),
        '/room_chart': (_) => const RoomChartScreen(),

        '/reports_screen': (_) => const ReportsScreen(),
        '/money_chart': (_) => const MoneyChartScreen(),
        '/money_report': (_) => const MoneyReportScreen(),
      },
    );
  }
}
