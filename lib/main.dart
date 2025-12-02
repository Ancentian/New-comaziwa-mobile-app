import 'package:flutter/material.dart';
import 'screens/login_page.dart';
import 'screens/dashboard_page.dart';
import 'screens/milk_collection_page.dart';
import 'screens/milk_list_page.dart';
// import 'screens/bluetooth_device_list_page.dart';
import 'screens/farmers_list_page.dart';
import 'screens/profile_page.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/farmer.dart';
import 'models/milk_collection.dart';
import 'models/record.dart';
import 'services/sync_service.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  Hive.registerAdapter(FarmerAdapter());
  Hive.registerAdapter(MilkCollectionAdapter());

  await Hive.openBox<Farmer>('farmers');
  await Hive.openBox<MilkCollection>('milk_collections');

  runApp(const MyApp());
}


// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Hive.initFlutter();

//   Hive.registerAdapter(MilkCollectionAdapter());
//   await Hive.openBox<MilkCollection>('milk_collections');

//   runApp(const MyApp());
// }





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
        '/dashboard': (context) => DashboardPage(name: ''), // name set dynamically
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
