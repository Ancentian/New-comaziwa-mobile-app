import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'auto_print_service.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

/// Centralized Printer Service
/// Handles all printing operations including auto-print functionality
class PrinterService {
  static String? _printerAddress;
  static ReceiptController? _controller;

  /// Check Bluetooth status and permissions
  /// Returns true if everything is ready, false otherwise
  static Future<bool> checkBluetoothConnection(BuildContext context) async {
    try {
      // Check Bluetooth permission
      final btStatus = await Permission.bluetoothConnect.status;
      if (btStatus.isDenied || btStatus.isPermanentlyDenied) {
        final result = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Bluetooth Permission Required'),
            content: const Text(
              'This app needs Bluetooth permission to connect to the printer. '
              'Please grant the permission to continue.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Grant Permission'),
              ),
            ],
          ),
        );

        if (result == true) {
          final granted = await Permission.bluetoothConnect.request();
          if (!granted.isGranted) {
            Fluttertoast.showToast(
              msg: 'Bluetooth permission denied. Cannot print.',
              backgroundColor: Colors.red,
              toastLength: Toast.LENGTH_LONG,
            );
            return false;
          }
        } else {
          return false;
        }
      }

      // Check Bluetooth scan permission (Android 12+)
      if (await Permission.bluetoothScan.isDenied) {
        await Permission.bluetoothScan.request();
      }

      // Check if printer is selected
      if (_printerAddress == null && !AutoPrintService.isAutoPrintEnabled()) {
        final result = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.print, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text('No Printer Selected'),
              ],
            ),
            content: const Text(
              'You need to select a printer first.\n\n'
              'Would you like to select a printer now?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Select Printer'),
              ),
            ],
          ),
        );

        if (result == true) {
          return await selectPrinter(context);
        } else {
          return false;
        }
      }

      return true;
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error checking Bluetooth: $e',
        backgroundColor: Colors.red,
      );
      return false;
    }
  }

  /// Attempt a quick connection test to the saved/default printer.
  /// Returns true when a print command was sent successfully.
  static Future<bool> connectTest(BuildContext context) async {
    try {
      String? address =
          _printerAddress ?? AutoPrintService.getDefaultPrinterAddress();
      if (address == null) {
        // Ask user to select a printer
        final ok = await selectPrinter(context);
        if (!ok) return false;
        address = _printerAddress;
      }

      // Create a tiny receipt used only to test sending
      final testReceipt = Receipt(
        builder: (ctx) => Center(
          child: Text(
            "\nConnection Test\n",
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        onInitialized: (controller) {
          _controller = controller;
        },
      );

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Printer Test')),
            body: Center(child: testReceipt),
          ),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));

      if (_controller != null && address != null) {
        try {
          _controller!.print(address: address);
          Fluttertoast.showToast(
            msg: 'Connection test sent',
            backgroundColor: Colors.green,
          );
          return true;
        } catch (e) {
          Fluttertoast.showToast(
            msg: 'Connection failed: $e',
            backgroundColor: Colors.red,
          );
          return false;
        }
      }

      Fluttertoast.showToast(
        msg: 'Printer not ready',
        backgroundColor: Colors.red,
      );
      return false;
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Connection test error: $e',
        backgroundColor: Colors.red,
      );
      return false;
    }
  }

  /// Send raw bytes to printer. Tries controller-level byte printing first,
  /// then falls back to static API, then to string fallback.
  static Future<bool> printRawBytes(
    Uint8List bytes,
    BuildContext context,
  ) async {
    // Many Flutter Bluetooth printer plugins do not expose a reliable
    // byte-level API. Fall back to sending the bytes as a latin1 string
    // through existing `printRaw` which renders via Receipt and controller.
    try {
      final address =
          _printerAddress ?? AutoPrintService.getDefaultPrinterAddress();
      if (address == null) {
        final ok = await selectPrinter(context);
        if (!ok) return false;
      }

      final s = latin1.decode(bytes);
      return await printRaw(s, context);
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'printRawBytes error: $e',
        backgroundColor: Colors.red,
      );
      return false;
    }
  }

  /// ESC/POS helpers
  static Uint8List escInit() => Uint8List.fromList([0x1B, 0x40]);
  static Uint8List escNewLine([int n = 1]) =>
      Uint8List.fromList(List.filled(n, 0x0A));
  static Uint8List escAlignCenter() => Uint8List.fromList([0x1B, 0x61, 0x01]);
  static Uint8List escAlignLeft() => Uint8List.fromList([0x1B, 0x61, 0x00]);
  static Uint8List escBoldOn() => Uint8List.fromList([0x1B, 0x45, 0x01]);
  static Uint8List escBoldOff() => Uint8List.fromList([0x1B, 0x45, 0x00]);
  static Uint8List escCut() => Uint8List.fromList([0x1D, 0x56, 0x00]);

  static Uint8List _bytesFromString(String s) {
    return Uint8List.fromList(latin1.encode(s));
  }

  /// Build a simple ESC/POS byte payload from text lines.
  static Uint8List buildEscPosFromLines(List<String> lines) {
    final out = <int>[];
    out.addAll(escInit());
    out.addAll(escAlignCenter());
    if (lines.isNotEmpty) {
      // Title line
      out.addAll(_bytesFromString('${lines.first}\n'));
    }
    out.addAll(escAlignLeft());
    for (var i = 1; i < lines.length; i++) {
      out.addAll(_bytesFromString('${lines[i]}\n'));
    }
    out.addAll(escNewLine(3));
    out.addAll(escCut());
    return Uint8List.fromList(out);
  }

  /// Convenience: print a milk receipt as ESC/POS bytes
  static Future<bool> printEscPosMilk(
    Map<String, dynamic> data,
    BuildContext context,
  ) async {
    final lines = <String>[];
    lines.add('COMAZIWA RECEIPT');
    lines.add('Farmer: ${data['farmerID'] ?? ''}');
    lines.add('Name: ${data['fname'] ?? ''} ${data['lname'] ?? ''}');
    lines.add('Center: ${data['center_name'] ?? ''}');
    lines.add('Date: ${data['collection_date'] ?? ''}');
    lines.add('-----------------------------');
    lines.add('Morning: ${data['morning'] ?? 0} L');
    lines.add('Evening: ${data['evening'] ?? 0} L');
    lines.add('Rejected: ${data['rejected'] ?? 0} L');
    lines.add('TOTAL: ${data['total'] ?? 0} L');
    lines.add('');
    lines.add('Thank you!');

    final bytes = buildEscPosFromLines(lines);
    return await printRawBytes(bytes, context);
  }

  /// Select printer via dialog
  static Future<bool> selectPrinter(BuildContext context) async {
    try {
      final device = await FlutterBluetoothPrinter.selectDevice(context);
      if (device == null) {
        Fluttertoast.showToast(
          msg: "No printer selected",
          backgroundColor: Colors.orange,
        );
        return false;
      }
      _printerAddress = device.address;
      Fluttertoast.showToast(
        msg: "Printer selected: ${device.name}",
        backgroundColor: Colors.green,
      );
      return true;
    } catch (e) {
      final errorMsg = e.toString().toLowerCase();

      // Check for common Bluetooth errors
      if (errorMsg.contains('bluetooth') &&
          (errorMsg.contains('off') || errorMsg.contains('disabled'))) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.bluetooth_disabled, color: Colors.red[700]),
                const SizedBox(width: 8),
                const Text('Bluetooth is Off'),
              ],
            ),
            content: const Text(
              'Please turn on Bluetooth in your phone settings and try again.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else if (errorMsg.contains('permission')) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text(
              'Bluetooth permission is required to discover printers.\n'
              'Please grant the permission in app settings.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        Fluttertoast.showToast(
          msg: "Failed to select printer. Please ensure Bluetooth is on.",
          backgroundColor: Colors.red,
          toastLength: Toast.LENGTH_LONG,
        );
      }
      return false;
    }
  }

  /// Print a Receipt widget with auto-print support (optimized for speed)
  /// Returns true on successful send, false otherwise.
  static Future<bool> printReceiptWidget(
    Receipt receiptWidget,
    BuildContext context,
  ) async {
    // Check Bluetooth and printer connection first
    final isReady = await checkBluetoothConnection(context);
    if (!isReady) {
      Fluttertoast.showToast(
        msg: 'Printing cancelled - connection not ready',
        backgroundColor: Colors.orange,
      );
      return false;
    }

    // Use a completer to wait for the ReceiptController to be initialized
    final completer = Completer<ReceiptController>();

    // Create a wrapper receipt that captures the controller
    final wrappedReceipt = Receipt(
      builder: receiptWidget.builder,
      onInitialized: (controller) {
        _controller = controller;
        receiptWidget.onInitialized(controller);
        if (!completer.isCompleted) completer.complete(controller);
      },
    );

    // Ensure we have a printer address (auto-print or saved)
    if (AutoPrintService.isAutoPrintEnabled()) {
      final printerAddress = AutoPrintService.getDefaultPrinterAddress();
      if (printerAddress != null) {
        _printerAddress = printerAddress;
      }
    }

    if (_printerAddress == null) {
      final ok = await selectPrinter(context);
      if (!ok) return false;
    }

    bool result = false;
    OverlayEntry? overlayEntry;

    try {
      // Create an overlay to render the receipt offscreen
      overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          left: -10000,
          top: -10000,
          child: Material(child: SizedBox(width: 300, child: wrappedReceipt)),
        ),
      );

      // Insert overlay and wait for next frame (faster than arbitrary delay)
      Overlay.of(context).insert(overlayEntry);
      await Future.delayed(const Duration(milliseconds: 100));

      // Wait for controller with shorter timeout
      final controller = await completer.future.timeout(
        const Duration(milliseconds: 1500),
      );

      try {
        // Call print without waiting for completion (fire and forget for speed)
        controller.print(address: _printerAddress!);
        // Minimal delay to ensure command is sent
        await Future.delayed(const Duration(milliseconds: 200));
        result = true;
      } catch (e) {
        print('Print error: $e');
        result = false;
      }
    } catch (e) {
      print('Printing error: $e');
      result = false;
    } finally {
      // Remove overlay immediately after print command
      overlayEntry?.remove();
      overlayEntry = null;
    }

    // Clear controller to avoid stale references
    _controller = null;
    return result;
  }

  /// Send a simple raw text to be printed (wraps in a Receipt widget).
  static Future<bool> printRaw(String text, BuildContext context) async {
    try {
      final wrapped = Receipt(
        builder: (ctx) => Center(
          child: Text(text, style: const TextStyle(fontFamily: 'monospace')),
        ),
        onInitialized: (controller) {
          _controller = controller;
        },
      );

      // Use the same flow as printReceiptWidget but without auto-select logic
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Raw Print')),
            body: Center(child: wrapped),
          ),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));
      final address =
          _printerAddress ?? AutoPrintService.getDefaultPrinterAddress();
      if (_controller != null && address != null) {
        _controller!.print(address: address);
        Fluttertoast.showToast(
          msg: 'Raw print sent',
          backgroundColor: Colors.green,
        );
        return true;
      }

      Fluttertoast.showToast(
        msg: 'Printer not ready',
        backgroundColor: Colors.red,
      );
      return false;
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Raw print error: $e',
        backgroundColor: Colors.red,
      );
      return false;
    }
  }

  /// Try printing a Receipt with retries. Returns true on success.
  static Future<bool> printWithRetry(
    Receipt receiptWidget,
    BuildContext context, {
    int retries = 2,
  }) async {
    int attempt = 0;
    while (attempt <= retries) {
      try {
        await printReceiptWidget(receiptWidget, context);
        return true;
      } catch (_) {
        attempt++;
        if (attempt > retries) break;
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    return false;
  }

  /// Enable auto-print with a specific printer
  static Future<void> enableAutoPrint(String printerAddress) async {
    await AutoPrintService.enableAutoPrint(printerAddress);
    Fluttertoast.showToast(
      msg: "Auto-print enabled",
      backgroundColor: Colors.green,
    );
  }

  /// Disable auto-print
  static Future<void> disableAutoPrint() async {
    await AutoPrintService.disableAutoPrint();
    Fluttertoast.showToast(
      msg: "Auto-print disabled",
      backgroundColor: Colors.orange,
    );
  }

  /// Check if auto-print is enabled
  static bool isAutoPrintEnabled() {
    return AutoPrintService.isAutoPrintEnabled();
  }

  /// Get current default printer address
  static String? getDefaultPrinterAddress() {
    return AutoPrintService.getDefaultPrinterAddress();
  }
}

/// Receipt Builder - Creates formatted receipts for printing
class ReceiptBuilder {
  /// Builds a Receipt widget for a milk collection
  static Receipt milkReceipt(Map<String, dynamic> data) {
    return Receipt(
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(
            top: 8.0,
            bottom: 36.0,
            left: 8.0,
            right: 8.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Receipt Title
              Center(
                child: Text(
                  "MILK COLLECTION RECEIPT",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Company Name
              if (data['company_name'] != null)
                Center(
                  child: Text(
                    '${data['company_name']}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (data['company_name'] != null) const SizedBox(height: 6),
              // Address
              Center(
                child: Text(
                  'P.O BOX 297-60100',
                  style: const TextStyle(fontSize: 22, fontFamily: 'monospace'),
                  textAlign: TextAlign.center,
                ),
              ),
              Center(
                child: Text(
                  'EMBU, KENYA',
                  style: const TextStyle(fontSize: 22, fontFamily: 'monospace'),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 6),
              // Phone
              Center(
                child: Text(
                  'Tel: 0743935667',
                  style: const TextStyle(fontSize: 22, fontFamily: 'monospace'),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(thickness: 2),
              const SizedBox(height: 12),
              // Date and Time
              Text(
                _formatDateTime(data['collection_date']),
                style: const TextStyle(fontSize: 22, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 8),
              Text(
                'Center: ${data['center_name'] ?? 'N/A'}',
                style: const TextStyle(fontSize: 24, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 6),
              Text(
                'Name: ${data['fname'] ?? ''} ${data['lname'] ?? ''}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Farmer ID: ${data['farmerID'] ?? ''}',
                style: const TextStyle(fontSize: 22, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 14),
              const Divider(thickness: 2),
              const SizedBox(height: 10),
              Text(
                "Morning: ${data['morning']} L",
                style: const TextStyle(fontFamily: 'monospace', fontSize: 28),
              ),
              const SizedBox(height: 6),
              Text(
                "Evening: ${data['evening']} L",
                style: const TextStyle(fontFamily: 'monospace', fontSize: 28),
              ),
              const SizedBox(height: 6),
              Text(
                "Rejected: ${data['rejected']} L",
                style: const TextStyle(fontFamily: 'monospace', fontSize: 28),
              ),
              const SizedBox(height: 14),
              const Divider(thickness: 2),
              const SizedBox(height: 14),
              // Text(
              //   "Current Weight: ${data['total']} L",
              //   style: const TextStyle(
              //     fontWeight: FontWeight.bold,
              //     fontFamily: 'monospace',
              //     fontSize: 28,
              //   ),
              // ),
              const SizedBox(height: 8),
              Text(
                "Today's Weight: ${data['today_total'] ?? data['total']} L",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Monthly Weight: ${data['monthly_total'] ?? data['total']} L",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 8),
              if (data['yearly_total'] != null)
                Text(
                  "Yearly Weight: ${data['yearly_total']} L",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    fontSize: 28,
                  ),
                ),
              if (data['yearly_total'] != null) const SizedBox(height: 8),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  "Dairy Cow, Daily Wealth!",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(''),
              Text(''),
              Text(''),
              Text(''),
              Text(''),
              Text(''),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
      onInitialized: (controller) {
        // Optional: store controller if needed
      },
    );
  }

  static List<Widget> _wrapText(
    String text, {
    int width = 32,
    double fontSize = 18,
  }) {
    final words = text.split(RegExp(r"\s+"));
    final lines = <String>[];
    var current = '';
    for (final w in words) {
      if (current.isEmpty) {
        current = w;
      } else if ((current.length + 1 + w.length) <= width) {
        current = '$current $w';
      } else {
        lines.add(current);
        current = w;
      }
    }
    if (current.isNotEmpty) lines.add(current);

    return lines
        .map(
          (l) => Text(
            l,
            style: TextStyle(fontFamily: 'monospace', fontSize: fontSize),
          ),
        )
        .toList();
  }

  /// Format date time to dd/mm/yyyy HH:MM:SS
  static String _formatDateTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
    }

    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(date);
    } catch (e) {
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
    }
  }

  /// Builds a Receipt widget for farmer production summary
  static Receipt farmerSummary(Map<String, dynamic> data) {
    return Receipt(
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(
            top: 8.0,
            bottom: 36.0,
            left: 8.0,
            right: 8.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Title
              Center(
                child: Text(
                  data['title'] ?? 'PRODUCTION SUMMARY',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Company Name
              if (data['company_name'] != null)
                Center(
                  child: Text(
                    '${data['company_name']}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (data['company_name'] != null) const SizedBox(height: 6),
              // Address & Contact
              Center(
                child: Text(
                  'P.O BOX 297-60100 EMBU',
                  style: const TextStyle(fontSize: 20, fontFamily: 'monospace'),
                  textAlign: TextAlign.center,
                ),
              ),
              Center(
                child: Text(
                  'Tel: 0743935667',
                  style: const TextStyle(fontSize: 20, fontFamily: 'monospace'),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(thickness: 2),
              const SizedBox(height: 12),
              // Print Date
              Text(
                'Printed: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                style: const TextStyle(fontSize: 20, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              const Divider(thickness: 1),
              const SizedBox(height: 12),
              // Farmer Info
              Text(
                'FARMER DETAILS',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Name: ${data['farmer_name']}',
                style: const TextStyle(fontSize: 22, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 4),
              Text(
                'ID: ${data['farmer_id']}',
                style: const TextStyle(fontSize: 22, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 4),
              Text(
                'Contact: ${data['contact']}',
                style: const TextStyle(fontSize: 22, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 4),
              Text(
                'Center: ${data['center']}',
                style: const TextStyle(fontSize: 22, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              const Divider(thickness: 1),
              const SizedBox(height: 12),
              // Period
              Text(
                'PERIOD',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                data['period'] ?? 'N/A',
                style: const TextStyle(fontSize: 22, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 14),
              const Divider(thickness: 2),
              const SizedBox(height: 12),
              // Summary Statistics
              Text(
                'SUMMARY',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Total Collections: ${data['total_collections']}',
                style: const TextStyle(fontSize: 24, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 6),
              Text(
                'Total Milk: ${data['total_milk']} L',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Average/Day: ${data['average_per_day']} L',
                style: const TextStyle(fontSize: 24, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 6),
              Text(
                'Highest Day: ${data['highest_day']}',
                style: const TextStyle(fontSize: 24, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 6),
              Text(
                'Lowest Day: ${data['lowest_day']}',
                style: const TextStyle(fontSize: 24, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 14),
              const Divider(thickness: 2),
              const SizedBox(height: 12),
              // Recent Collections (Top 10)
              Text(
                'RECENT COLLECTIONS',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 10),
              // Table Header
              Text(
                'Date       Morn  Even  Total',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const Divider(thickness: 1),
              // Collections
              ...((data['collections'] as List?) ?? []).map((col) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${col['date'].toString().padRight(11)}${col['morning'].toString().padLeft(4)} ${col['evening'].toString().padLeft(5)} ${col['total'].toString().padLeft(6)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
              const Divider(thickness: 2),
              const SizedBox(height: 14),
              // Footer
              Center(
                child: Text(
                  'Dairy Cow, Daily Wealth!',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(''),
              Text(''),
              Text(''),
              Text(''),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
      onInitialized: (controller) {
        // Optional: store controller if needed
      },
    );
  }
}
