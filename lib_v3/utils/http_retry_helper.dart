import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:math';

/// HTTP retry helper with exponential backoff to handle transient failures
/// and WAF/rate-limiting blocks gracefully.
class HttpRetryHelper {
  /// Max retries on failure (default 3 attempts total: 1 initial + 2 retries)
  static const int maxRetries = 2;

  /// Initial backoff delay in milliseconds (will exponentially increase)
  static const int initialBackoffMs = 500;

  /// Maximum backoff delay in milliseconds (cap to avoid excessive wait)
  static const int maxBackoffMs = 5000;

  /// Standard headers for API requests (helps avoid WAF blocks)
  static Map<String, String> getStandardHeaders({
    bool isJson = false,
    String? authToken,
  }) {
    final headers = {
      'Accept': 'application/json',
      'User-Agent': 'comaziwa_app/1.0',
      'X-Requested-With': 'XMLHttpRequest',
    };

    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }

    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    return headers;
  }

  /// Perform a POST request with automatic retry and backoff.
  /// Returns the response or throws the last exception after all retries exhausted.
  static Future<http.Response> post({
    required Uri url,
    Map<String, String>? headers,
    dynamic body,
    bool isJson = false,
    String? authToken,
  }) async {
    headers ??= {};
    
    // Merge with standard headers
    final standardHeaders = getStandardHeaders(isJson: isJson, authToken: authToken);
    final mergedHeaders = {...standardHeaders, ...headers};

    int attempt = 0;
    http.Response? lastResponse;
    Exception? lastException;

    while (attempt <= maxRetries) {
      try {
        final response = await http.post(
          url,
          headers: mergedHeaders,
          body: body,
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw TimeoutException('Request timeout after 30s'),
        );

        lastResponse = response;

        // Success: return response
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }

        // Retry on server errors (5xx) or rate-limiting (429)
        if (response.statusCode == 429 || response.statusCode >= 500) {
          if (attempt < maxRetries) {
            attempt++;
            await _backoff(attempt);
            continue;
          }
        }

        // For other status codes, return the response (caller decides)
        return response;
      } on TimeoutException catch (e) {
        lastException = e;
        if (attempt < maxRetries) {
          attempt++;
          await _backoff(attempt);
          continue;
        }
        rethrow;
      } catch (e) {
        lastException = Exception('HTTP POST failed: $e');
        if (attempt < maxRetries) {
          attempt++;
          await _backoff(attempt);
          continue;
        }
        rethrow;
      }
    }

    // If we got a response on the last attempt, return it
    if (lastResponse != null) {
      return lastResponse;
    }

    // Otherwise throw the last exception
    throw lastException ?? Exception('Unknown HTTP error');
  }

  /// Perform a GET request with automatic retry and backoff.
  static Future<http.Response> get({
    required Uri url,
    Map<String, String>? headers,
    String? authToken,
  }) async {
    headers ??= {};

    // Merge with standard headers
    final standardHeaders = getStandardHeaders(isJson: false, authToken: authToken);
    final mergedHeaders = {...standardHeaders, ...headers};

    int attempt = 0;
    http.Response? lastResponse;
    Exception? lastException;

    while (attempt <= maxRetries) {
      try {
        final response = await http.get(
          url,
          headers: mergedHeaders,
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw TimeoutException('Request timeout after 30s'),
        );

        lastResponse = response;

        // Success: return response
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }

        // Retry on server errors (5xx) or rate-limiting (429)
        if (response.statusCode == 429 || response.statusCode >= 500) {
          if (attempt < maxRetries) {
            attempt++;
            await _backoff(attempt);
            continue;
          }
        }

        // For other status codes, return the response (caller decides)
        return response;
      } on TimeoutException catch (e) {
        lastException = e;
        if (attempt < maxRetries) {
          attempt++;
          await _backoff(attempt);
          continue;
        }
        rethrow;
      } catch (e) {
        lastException = Exception('HTTP GET failed: $e');
        if (attempt < maxRetries) {
          attempt++;
          await _backoff(attempt);
          continue;
        }
        rethrow;
      }
    }

    // If we got a response on the last attempt, return it
    if (lastResponse != null) {
      return lastResponse;
    }

    // Otherwise throw the last exception
    throw lastException ?? Exception('Unknown HTTP error');
  }

  /// Calculate exponential backoff with jitter to avoid thundering herd.
  /// Formula: min(initialBackoff * 2^attempt + random jitter, maxBackoff)
  static Future<void> _backoff(int attemptNumber) async {
    final baseDelay = initialBackoffMs * pow(2, attemptNumber - 1).toInt();
    final jitter = Random().nextInt(100); // 0-100ms jitter
    final delayMs = min(baseDelay + jitter, maxBackoffMs);

    print('🔄 Retry attempt $attemptNumber, waiting ${delayMs}ms...');
    await Future.delayed(Duration(milliseconds: delayMs));
  }
}
