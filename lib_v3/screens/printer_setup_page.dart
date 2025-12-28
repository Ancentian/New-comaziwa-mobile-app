// import 'package:flutter/material.dart';
// import 'package:bluetooth_print_plus/bluetooth_print_plus.dart';
// import 'package:bluetooth_print_plus/bluetooth_print_model.dart';

// class BluetoothPrinterPage extends StatefulWidget {
//   const BluetoothPrinterPage({super.key});

//   @override
//   State<BluetoothPrinterPage> createState() => _BluetoothPrinterPageState();
// }

// class _BluetoothPrinterPageState extends State<BluetoothPrinterPage> {
//   final BluetoothPrint bluetoothPrint = BluetoothPrint.instance;

//   List<BluetoothDevice> _devices = [];
//   BluetoothDevice? _selectedDevice;
//   bool _connected = false;

//   @override
//   void initState() {
//     super.initState();
//     _initBluetooth();
//   }

//   void _initBluetooth() async {
//     bool isConnected = await bluetoothPrint.isConnected ?? false;
//     setState(() => _connected = isConnected);

//     // Start scanning
//     bluetoothPrint.startScan(timeout: const Duration(seconds: 4));

//     bluetoothPrint.scanResults.listen((devices) {
//       setState(() {
//         _devices = devices;
//       });
//     });

//     bluetoothPrint.state.listen((state) {
//       setState(() {
//         _connected = state == BluetoothPrint.CONNECTED;
//       });
//     });
//   }

//   void _connectAndPrint() async {
//     if (_selectedDevice == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please select a printer')),
//       );
//       return;
//     }

//     bool connected = await bluetoothPrint.connect(_selectedDevice!);
//     if (connected) {
//       // Print text
//       List<LineText> list = [
//         LineText(
//           type: LineText.TYPE_TEXT,
//           content: 'Hello Printer!',
//           align: LineText.ALIGN_CENTER,
//           linefeed: 1,
//         ),
//       ];

//       await bluetoothPrint.printReceipt(list);
//       ScaffoldMessenger.of(context)
//           .showSnackBar(const SnackBar(content: Text('Printed successfully!')));
//     } else {
//       ScaffoldMessenger.of(context)
//           .showSnackBar(const SnackBar(content: Text('Connection failed')));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Bluetooth Printer')),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             DropdownButton<BluetoothDevice>(
//               value: _selectedDevice,
//               hint: const Text("Select Bluetooth Printer"),
//               items: _devices
//                   .map((d) => DropdownMenuItem<BluetoothDevice>(
//                         value: d,
//                         child: Text(d.name ?? d.address),
//                       ))
//                   .toList(),
//               onChanged: (value) {
//                 setState(() {
//                   _selectedDevice = value;
//                 });
//               },
//             ),
//             const SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: _connectAndPrint,
//               child: Text(_connected ? 'Print' : 'Connect & Print'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
