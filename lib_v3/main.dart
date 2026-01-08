import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/login_page.dart';
import 'screens/dashboard_page.dart';
import 'screens/milk_collection_page.dart';
import 'screens/milk_list_page.dart';
import 'screens/farmers_list_page.dart';
import 'screens/profile_page.dart';

import 'models/farmer.dart';
import 'models/milk_collection.dart';
import 'services/sync_service.dart';
import 'services/farmer_service.dart';
import 'services/auto_print_service.dart';
import 'config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Register adapters
  Hive.registerAdapter(FarmerAdapter());
  Hive.registerAdapter(MilkCollectionAdapter());

  // Open boxes only if not already open
  if (!Hive.isBoxOpen('farmers')) {
    await Hive.openBox<Farmer>('farmers');
  }
  if (!Hive.isBoxOpen('milk_collections')) {
    await Hive.openBox<MilkCollection>('milk_collections');
  }

  // Initialize auto-print service
  await AutoPrintService.initialize();
  
  // If auto-print is enabled in config, activate it
  if (AppConfig.enableAutoPrint) {
    // Auto-print will be used when saving milk collections
  }

  // Start background listeners
  SyncService().startSyncListener();
  FarmerService().startAutoSync();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Milk App',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D773E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0D773E),
          secondary: Color(0xFF2ECC71),
        ),
      ),
      home: const LoginPage(),
      routes: {
        '/dashboard': (context) => DashboardPage(name: ''),
        '/profile': (context) => ProfilePage(
              name: '',
              email: '',
              phone: '',
              role: '',
            ),
        '/milkCollection': (context) => const MilkCollectionPage(),
        '/milkList': (context) => const MilkListPage(),
        '/farmersList': (context) => const FarmersListPage(),
        '/login': (context) => const LoginPage(),
      },
    );
  }
}
