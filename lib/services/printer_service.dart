// import 'package:bluetooth_print_plus/bluetooth_print_plus.dart';
// import 'package:bluetooth_print_plus/bluetooth_print_model.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class PrinterService {
//   static final BluetoothPrintPlus _bluetoothPrint = BluetoothPrintPlus.instance;

//   /// 🔍 Get list of paired Bluetooth devices
//   static Future<List<BluetoothDevice>> getPairedDevices() async {
//     List<BluetoothDevice> devices = await _bluetoothPrint.getBondedBluetooths() ?? [];
//     return devices;
//   }

//   /// 🔌 Connect to selected printer
//   static Future<bool> connect(String mac) async {
//     final result = await _bluetoothPrint.connect(mac);
//     if (result == true) {
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString('printer_mac', mac);
//     }
//     return result == true;
//   }

//   /// 🔁 Auto-connect to saved printer
//   static Future<bool> autoConnect() async {
//     final prefs = await SharedPreferences.getInstance();
//     final mac = prefs.getString('printer_mac');
//     if (mac != null) {
//       final result = await _bluetoothPrint.connect(mac);
//       return result == true;
//     }
//     return false;
//   }

//   /// 🖨 Print text
//   static Future<void> printReceipt(String text) async {
//     final isConnected = await _bluetoothPrint.isConnected ?? false;

//     if (isConnected) {
//       await _bluetoothPrint.printText(
//         text,
//         queueSleepTime: 500,
//         bold: true,
//         align: 'left', // you can use 'center' or 'right'
//       );
//     } else {
//       final connected = await autoConnect();
//       if (connected) {
//         await _bluetoothPrint.printText(
//           text,
//           queueSleepTime: 500,
//           bold: true,
//           align: 'left',
//         );
//       } else {
//         print("❌ Printer not connected");
//       }
//     }
//   }

//   /// 🔌 Disconnect printer
//   static Future<void> disconnect() async {
//     await _bluetoothPrint.disconnect();
//   }
// }
