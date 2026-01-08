// import 'package:flutter/material.dart';
// import 'package:blue_thermal_printer/blue_thermal_printer.dart';
// import 'bluetooth_print_page.dart'; // Import your print page

// class BluetoothDeviceListPage extends StatefulWidget {
//   const BluetoothDeviceListPage({super.key});

//   @override
//   State<BluetoothDeviceListPage> createState() => _BluetoothDeviceListPageState();
// }

// class _BluetoothDeviceListPageState extends State<BluetoothDeviceListPage> {
//   BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
//   List<BluetoothDevice> devices = [];
//   BluetoothDevice? selectedDevice;
//   bool isConnected = false;

//   @override
//   void initState() {
//     super.initState();
//     fetchDevices();
//   }

//   Future<void> fetchDevices() async {
//     List<BluetoothDevice> pairedDevices = await bluetooth.getBondedDevices();
//     setState(() {
//       devices = pairedDevices;
//     });
//   }

//   void connectToDevice(BluetoothDevice device) async {
//     bool? connected = await bluetooth.connect(device);
//     setState(() {
//       selectedDevice = device;
//       isConnected = connected ?? false;
//     });
//     if (isConnected) {
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (_) => BluetoothPrintPage(selectedDevice: device),
//         ),
//       );
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Failed to connect to device")),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Select Bluetooth Printer")),
//       body: ListView.builder(
//         itemCount: devices.length,
//         itemBuilder: (context, index) {
//           final device = devices[index];
//           return ListTile(
//             title: Text(device.name ?? "Unknown"),
//             subtitle: Text(device.address ?? ""),
//             trailing: const Icon(Icons.print),
//             onTap: () => connectToDevice(device),
//           );
//         },
//       ),
//     );
//   }
// }
