// import 'package:flutter/material.dart';
// import 'package:blue_thermal_printer/blue_thermal_printer.dart';

// class BluetoothPrintPage extends StatelessWidget {
//   final BluetoothDevice selectedDevice;

//   const BluetoothPrintPage({super.key, required this.selectedDevice});

//   @override
//   Widget build(BuildContext context) {
//     BlueThermalPrinter printer = BlueThermalPrinter.instance;

//     return Scaffold(
//       appBar: AppBar(title: const Text("Print Milk Report")),
//       body: Center(
//         child: ElevatedButton(
//           onPressed: () async {
//             bool? connected = await printer.connect(selectedDevice);
//             if (connected ?? false) {
//               printer.printNewLine();
//               printer.printCustom("Milk Collection Report", 3, 1);
//               printer.printNewLine();
//               printer.printLeftRight("Date", "Quantity", 1);
//               printer.printNewLine();
//               printer.printLeftRight("2025-11-13", "183.51 L", 1);
//               printer.printNewLine();
//               printer.paperCut();
//             }
//           },
//           child: const Text("Print Report"),
//         ),
//       ),
//     );
//   }
// }
