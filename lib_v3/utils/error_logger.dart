import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';

/// Error logger that writes network errors to a local file for debugging and support.
class ErrorLogger {
  static const String logFileName = 'error_logs.txt';
  static File? _logFile;

  /// Initialize the logger and get the log file
  static Future<File> _getLogFile() async {
    if (_logFile != null) return _logFile!;

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$logFileName');

    _logFile = file;
    return file;
  }

  /// Log a network error with full details
  static Future<void> logNetworkError({
    required String endpoint,
    required int statusCode,
    required String? contentType,
    required String rawBody,
    required String errorMessage,
    Map<String, String>? headers,
  }) async {
    try {
      final file = await _getLogFile();
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      final logEntry = '''
================================================================================
ERROR LOG - $timestamp
================================================================================
Endpoint: $endpoint
Status Code: $statusCode
Content-Type: ${contentType ?? 'NOT SET'}
Error Message: $errorMessage

REQUEST HEADERS:
${_formatHeaders(headers)}

RAW RESPONSE BODY:
$rawBody

================================================================================

''';

      await file.writeAsString(logEntry, mode: FileMode.append);
      print('✅ Error logged to: ${file.path}');
    } catch (e) {
      print('❌ Failed to write error log: $e');
    }
  }

  /// Log a general error (not network-specific)
  static Future<void> logError({
    required String message,
    String? stackTrace,
  }) async {
    try {
      final file = await _getLogFile();
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      final logEntry = '''
================================================================================
ERROR LOG - $timestamp
================================================================================
Message: $message
${stackTrace != null ? 'Stack Trace:\n$stackTrace' : ''}

================================================================================

''';

      await file.writeAsString(logEntry, mode: FileMode.append);
      print('✅ Error logged to: ${file.path}');
    } catch (e) {
      print('❌ Failed to write error log: $e');
    }
  }

  /// Read all logs from file
  static Future<String> readLogs() async {
    try {
      final file = await _getLogFile();
      if (await file.exists()) {
        return await file.readAsString();
      } else {
        return 'No logs found yet.';
      }
    } catch (e) {
      return 'Error reading logs: $e';
    }
  }

  /// Clear all logs
  static Future<void> clearLogs() async {
    try {
      final file = await _getLogFile();
      if (await file.exists()) {
        await file.delete();
        _logFile = null;
        print('✅ Logs cleared');
      }
    } catch (e) {
      print('❌ Failed to clear logs: $e');
    }
  }

  /// Get log file path (for sharing/debugging)
  static Future<String> getLogFilePath() async {
    final file = await _getLogFile();
    return file.path;
  }

  /// Format headers for readable display
  static String _formatHeaders(Map<String, String>? headers) {
    if (headers == null || headers.isEmpty) {
      return '  (No headers provided)';
    }
    return headers.entries
        .map((e) => '  ${e.key}: ${e.value}')
        .join('\n');
  }
}
