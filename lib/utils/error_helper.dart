/// Helper class for converting technical errors into user-friendly messages
class ErrorHelper {
  /// Convert exception to user-friendly message
  static String getUserFriendlyMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Network connectivity errors
    if (errorString.contains('socketexception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('network is unreachable') ||
        errorString.contains('no address associated with hostname')) {
      return 'No internet connection. Working offline.';
    }

    // Connection timeout
    if (errorString.contains('timeout') ||
        errorString.contains('connection timed out')) {
      return 'Connection timeout. Please check your internet.';
    }

    // Connection refused / server down
    if (errorString.contains('connection refused') ||
        errorString.contains('connection reset')) {
      return 'Cannot reach server. Please try again later.';
    }

    // Certificate/SSL errors
    if (errorString.contains('certificate') ||
        errorString.contains('ssl') ||
        errorString.contains('handshake')) {
      return 'Secure connection failed. Check your connection.';
    }

    // Format errors
    if (errorString.contains('formatexception') ||
        errorString.contains('unexpected character')) {
      return 'Invalid data received from server.';
    }

    // General fallback
    return 'Unable to connect. Working offline.';
  }

  /// Get log message (for debugging, not shown to user)
  static String getLogMessage(dynamic error) {
    final errorString = error.toString();

    // Extract first line only for cleaner logs
    if (errorString.contains('\n')) {
      return errorString.split('\n').first;
    }

    // Limit length for very long errors
    if (errorString.length > 150) {
      return '${errorString.substring(0, 147)}...';
    }

    return errorString;
  }
}
