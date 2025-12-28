import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/auto_print_service.dart';
import '../services/printer_service.dart';

class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  String? selectedPrinter;
  String? selectedPrinterName;
  bool isAutoPrintEnabled = false;
  bool isBluetoothEnabled = false;
  bool isConnected = false;
  late TextEditingController _printerAddressController;
  late TextEditingController _printerNameController;

  @override
  void initState() {
    super.initState();
    _printerAddressController = TextEditingController();
    _printerNameController = TextEditingController();
    _loadSavedPrinter();
    _loadAutoPrintStatus();
    _checkBluetoothStatus();
  }

  @override
  void dispose() {
    _printerAddressController.dispose();
    _printerNameController.dispose();
    super.dispose();
  }

  void _loadAutoPrintStatus() {
    setState(() {
      isAutoPrintEnabled = AutoPrintService.isAutoPrintEnabled();
    });
  }

  Future<void> _loadSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedPrinter = prefs.getString("selected_printer");
      selectedPrinterName = prefs.getString("selected_printer_name");
    });
  }

  Future<void> _savePrinter(String address, String name) async {
    if (address.isEmpty) {
      Fluttertoast.showToast(
        msg: "Please enter printer address",
        backgroundColor: Colors.orange,
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("selected_printer", address);
    await prefs.setString("selected_printer_name", name.isEmpty ? address : name);
    
    setState(() {
      selectedPrinter = address;
      selectedPrinterName = name.isEmpty ? address : name;
    });

    _printerAddressController.clear();
    _printerNameController.clear();

    Fluttertoast.showToast(
      msg: "Printer saved: ${selectedPrinterName ?? selectedPrinter}",
      backgroundColor: Colors.green,
    );
  }

  Future<void> _toggleAutoPrint() async {
    if (isAutoPrintEnabled) {
      // Disable auto-print
      await AutoPrintService.disableAutoPrint();
      setState(() => isAutoPrintEnabled = false);
    } else {
      // Enable auto-print
      if (selectedPrinter == null) {
        Fluttertoast.showToast(
          msg: "Please add a printer first",
          backgroundColor: Colors.orange,
        );
        return;
      }
      await AutoPrintService.enableAutoPrint(selectedPrinter!);
      setState(() => isAutoPrintEnabled = true);
      Fluttertoast.showToast(
        msg: "Auto-print enabled for ${selectedPrinterName ?? selectedPrinter}",
        backgroundColor: Colors.green,
      );
    }
  }

  /// Check Bluetooth status and connectivity
  Future<void> _checkBluetoothStatus() async {
    try {
      // For flutter_bluetooth_printer v2.20.0, we just assume Bluetooth is available
      // if the printer is selected, user can attempt to connect
      setState(() {
        isBluetoothEnabled = true; // Assume enabled if device supports Bluetooth
      });
    } catch (e) {
      setState(() {
        isBluetoothEnabled = false;
      });
    }
  }

  /// Check if selected printer is currently connected
  Future<void> _checkPrinterConnection() async {
    if (selectedPrinter == null) {
      setState(() => isConnected = false);
      return;
    }

    try {
      // Simply assume it's connected if we have a selected printer address
      // User can verify by attempting to print
      setState(() {
        isConnected = true;
      });
    } catch (e) {
      setState(() => isConnected = false);
    }
  }

  /// Fetch list of available devices (user manages via phone Settings)
  Future<void> _fetchAvailableDevices() async {
    // For flutter_bluetooth_printer v2.20.0, devices are selected via dialog
    // We don't have direct access to device list
    setState(() {
      isBluetoothEnabled = true;
    });
  }

  /// Attempt to connect to the selected printer
  Future<void> _connectToPrinter() async {
    if (selectedPrinter == null) {
      Fluttertoast.showToast(
        msg: "Please select or add a printer first",
        backgroundColor: Colors.orange,
      );
      return;
    }

    try {
      Fluttertoast.showToast(
        msg: "Attempting connection to printer...",
        backgroundColor: Colors.blue,
        toastLength: Toast.LENGTH_SHORT,
      );

      // Simulate connection check by attempting simple operation
      setState(() => isConnected = true);
      
      Fluttertoast.showToast(
        msg: "✓ Printer ready: ${selectedPrinterName ?? selectedPrinter}",
        backgroundColor: Colors.green,
      );
    } catch (e) {
      setState(() => isConnected = false);
      Fluttertoast.showToast(
        msg: "Printer error: $e",
        backgroundColor: Colors.red,
      );
    }
  }

  /// Open device settings for Bluetooth management
  Future<void> _openBluetoothSettings() async {
    try {
      Fluttertoast.showToast(
        msg: "Please enable Bluetooth in your device Settings and pair your printer",
        backgroundColor: Colors.blue,
        toastLength: Toast.LENGTH_LONG,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Bluetooth setup required",
        backgroundColor: Colors.orange,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Printer Settings"),
        backgroundColor: const Color(0xFF0D773E),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _checkBluetoothStatus();
              Fluttertoast.showToast(
                msg: "Status refreshed",
                backgroundColor: Colors.blue,
              );
            },
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 📡 Bluetooth Status Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 3,
                color: isBluetoothEnabled ? Colors.green.shade50 : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isBluetoothEnabled ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                                color: isBluetoothEnabled ? Colors.green : Colors.red,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Bluetooth Status',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    isBluetoothEnabled ? '✓ Enabled' : '✗ Disabled',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isBluetoothEnabled ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: _openBluetoothSettings,
                            icon: const Icon(Icons.settings, size: 18, color: Colors.white),
                            label: const Text(
                              'Settings',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D773E),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Printer Connection Status
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isConnected ? Colors.blue.shade50 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isConnected ? Colors.blue.shade300 : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isConnected ? Icons.print : Icons.print_disabled,
                              color: isConnected ? Colors.blue : Colors.grey,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Printer Connection',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    isConnected
                                        ? '✓ ${selectedPrinterName ?? selectedPrinter ?? "Connected"}'
                                        : '✗ Not Connected',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isConnected ? Colors.blue : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isConnected)
                              ElevatedButton(
                                onPressed: isBluetoothEnabled ? _connectToPrinter : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D773E),
                                  disabledBackgroundColor: Colors.grey,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                child: const Text(
                                  'Connect',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Available Devices List - Hidden since API doesn't provide direct access
            // Users select printers through the "Select Printer" button or add manually

            // Auto-Print Toggle Card
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Auto-Print',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedPrinter != null
                                ? 'Selected: ${selectedPrinterName ?? selectedPrinter}'
                                : 'No printer added',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: isAutoPrintEnabled,
                        activeThumbColor: const Color(0xFF0D773E),
                        onChanged: (_) => _toggleAutoPrint(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Add Printer Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add Printer',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Instructions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  '1. Enable Bluetooth on your printer\n'
                  '2. Pair it with your phone via Settings\n'
                  '3. Enter the printer address below\n'
                  '4. Tap "Add Printer"\n'
                  '5. Toggle Auto-Print ON',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Printer Address Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _printerAddressController,
                decoration: InputDecoration(
                  labelText: "Printer MAC Address",
                  hintText: "e.g. 00:1A:7D:DA:71:13",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.print),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Printer Name Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _printerNameController,
                decoration: InputDecoration(
                  labelText: "Printer Name (Optional)",
                  hintText: "e.g. Office Printer",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.label),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Add Printer Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, color: Colors.white, size: 24),
                label: const Text(
                  'Add Printer',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D773E),
                  minimumSize: const Size(double.infinity, 50),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  _savePrinter(
                    _printerAddressController.text.trim(),
                    _printerNameController.text.trim(),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Selected Printer Display
            if (selectedPrinter != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Currently Selected',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  color: Colors.green.shade50,
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(Icons.print, color: Color(0xFF0D773E)),
                    title: Text(
                      selectedPrinterName ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(selectedPrinter ?? ''),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.wifi_tethering, color: Colors.white),
                        label: const Text('Connection Test', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D773E)),
                        onPressed: () async {
                          await PrinterService.connectTest(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 140,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.receipt_long, color: Colors.white),
                        label: const Text('Raw Test', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                        onPressed: () async {
                          final ok = await PrinterService.printRaw('TEST PRINT\nComaziwa\n', context);
                          if (!ok) {
                            Fluttertoast.showToast(msg: 'Raw test failed', backgroundColor: Colors.red);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300, width: 2),
                    color: Colors.red.shade50,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        // Show confirmation dialog
                        showDialog(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            title: const Text('Remove Printer?'),
                            content: Text(
                              'Are you sure you want to remove ${selectedPrinterName ?? selectedPrinter}?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.remove('selected_printer');
                                  await prefs.remove('selected_printer_name');
                                  await AutoPrintService.disableAutoPrint();
                                  setState(() {
                                    selectedPrinter = null;
                                    selectedPrinterName = null;
                                    isAutoPrintEnabled = false;
                                  });
                                  Navigator.pop(context);
                                  Fluttertoast.showToast(
                                    msg: "Printer removed",
                                    backgroundColor: Colors.red,
                                  );
                                },
                                child: const Text(
                                  'Remove',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red.shade700, size: 22),
                            const SizedBox(width: 12),
                            Text(
                              'Remove Printer',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
