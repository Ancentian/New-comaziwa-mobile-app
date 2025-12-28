import 'package:shared_preferences/shared_preferences.dart';

class AutoPrintService {
  static const String _autoPrintEnabledKey = 'auto_print_enabled';
  static const String _defaultPrinterAddressKey = 'default_printer_address';

  static bool _isAutoPrintEnabled = false;
  static String? _defaultPrinterAddress;

  /// Initialize auto-print service by loading settings from shared preferences
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isAutoPrintEnabled = prefs.getBool(_autoPrintEnabledKey) ?? false;
    _defaultPrinterAddress = prefs.getString(_defaultPrinterAddressKey);
  }

  /// Check if auto-print is enabled
  static bool isAutoPrintEnabled() {
    return _isAutoPrintEnabled;
  }

  /// Enable auto-print
  static Future<void> enableAutoPrint(String printerAddress) async {
    final prefs = await SharedPreferences.getInstance();
    _isAutoPrintEnabled = true;
    _defaultPrinterAddress = printerAddress;
    
    await prefs.setBool(_autoPrintEnabledKey, true);
    await prefs.setString(_defaultPrinterAddressKey, printerAddress);
  }

  /// Disable auto-print
  static Future<void> disableAutoPrint() async {
    final prefs = await SharedPreferences.getInstance();
    _isAutoPrintEnabled = false;
    _defaultPrinterAddress = null;
    
    await prefs.setBool(_autoPrintEnabledKey, false);
    await prefs.remove(_defaultPrinterAddressKey);
  }

  /// Get default printer address
  static String? getDefaultPrinterAddress() {
    return _defaultPrinterAddress;
  }

  /// Set default printer address
  static Future<void> setDefaultPrinterAddress(String printerAddress) async {
    final prefs = await SharedPreferences.getInstance();
    _defaultPrinterAddress = printerAddress;
    await prefs.setString(_defaultPrinterAddressKey, printerAddress);
  }
}
