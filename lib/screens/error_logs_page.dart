import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../utils/error_logger.dart';

class ErrorLogsPage extends StatefulWidget {
  const ErrorLogsPage({super.key});

  @override
  State<ErrorLogsPage> createState() => _ErrorLogsPageState();
}

class _ErrorLogsPageState extends State<ErrorLogsPage> {
  late Future<String> _logsFuture;

  @override
  void initState() {
    super.initState();
    _logsFuture = ErrorLogger.readLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error Logs'),
        backgroundColor: const Color(0xFF0D773E),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _logsFuture = ErrorLogger.readLogs();
              });
              Fluttertoast.showToast(msg: 'Logs refreshed');
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear Logs?'),
                  content: const Text('This will permanently delete all error logs.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await ErrorLogger.clearLogs();
                        Navigator.pop(ctx);
                        setState(() {
                          _logsFuture = ErrorLogger.readLogs();
                        });
                        Fluttertoast.showToast(msg: 'Logs cleared');
                      },
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _logsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Error loading logs: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final logsContent = snapshot.data ?? 'No logs found.';

          return Column(
            children: [
              // Log viewer
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    logsContent,
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 11,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),

              // Action buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Copy to clipboard button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.content_copy),
                        label: const Text('Copy Logs to Clipboard'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                        ),
                        onPressed: () async {
                          await _copyToClipboard(logsContent);
                          Fluttertoast.showToast(
                            msg: 'Logs copied to clipboard! Paste into support email.',
                            backgroundColor: Colors.green,
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Log file path info
                    FutureBuilder<String>(
                      future: ErrorLogger.getLogFilePath(),
                      builder: (ctx, pathSnapshot) {
                        if (pathSnapshot.hasData) {
                          return Text(
                            'Log file: ${pathSnapshot.data}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Copy text to clipboard
  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
