import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'screens/login_page.dart';
import 'screens/dashboard_page.dart';
import 'screens/milk_collection_page.dart';
import 'screens/milk_list_page.dart';
import 'screens/farmers_list_page.dart';
import 'screens/profile_page.dart';
import 'screens/daily_collection_summary_page.dart';
import 'utils/theme_provider.dart';

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

  // Check and migrate schema if needed
  await _checkAndMigrateSchema();

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

/// Check schema version and migrate data if structure changed
Future<void> _checkAndMigrateSchema() async {
  const currentSchemaVersion =
      3; // Incremented for createdById/createdByType fields in MilkCollection

  final prefs = await Hive.openBox('app_prefs');
  final savedVersion = prefs.get('schema_version', defaultValue: 1);

  if (savedVersion < currentSchemaVersion) {
    print('🔄 Migrating schema from v$savedVersion to v$currentSchemaVersion');

    // Clear old incompatible data
    if (Hive.isBoxOpen('farmers')) {
      final farmersBox = Hive.box<Farmer>('farmers');
      await farmersBox.clear();
      print('✅ Cleared old farmers data for migration');
    } else {
      try {
        final box = await Hive.openBox<Farmer>('farmers');
        await box.clear();
        await box.close();
        print('✅ Cleared old farmers data for migration');
      } catch (e) {
        print('⚠️ Could not clear farmers: $e');
      }
    }

    // Update schema version
    await prefs.put('schema_version', currentSchemaVersion);
    print('✅ Schema migrated successfully');
  }

  await prefs.close();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Comaziwa App',
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            home: const LoginPage(),
            routes: {
              '/dashboard': (context) => DashboardPage(name: ''),
              '/profile': (context) =>
                  ProfilePage(name: '', email: '', phone: '', role: ''),
              '/milkCollection': (context) => const MilkCollectionPage(),
              '/milkList': (context) => const MilkListPage(),
              '/farmersList': (context) => const FarmersListPage(),
              '/dailySummary': (context) => const DailyCollectionSummaryPage(),
              '/login': (context) => const LoginPage(),
            },
          );
        },
      ),
    );
  }
}
