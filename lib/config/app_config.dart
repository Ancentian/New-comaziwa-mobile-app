// lib/config.dart

class AppConfig {
  static const bool isLocal = false;
  static const bool enableAutoPrint =
      false; // Set to true to enable auto-print on app start

  // Primary and fallback URLs in case of DNS issues
  static const String primaryUrl = "https://kathande.embucomaziwa.co.ke";
  static const String fallbackUrl =
      "https://102.130.125.51"; // IP address fallback

  static String get baseUrl {
    if (isLocal) {
      // return "http://192.168.0.159:8000"; // for physical device
      return "http://192.168.100.46:8000";
    } else {
      return primaryUrl;
    }
  }

  static String getBaseUrl([bool online = true]) {
    // Optional: use `online` parameter if you want different behavior
    if (!online) {
      return "http://192.168.0.159:8000"; // maybe offline testing URL
    }
    return baseUrl;
  }

  // Alternative URL if primary fails
  static String get alternativeUrl => fallbackUrl;
}



// class AppConfig {
//   static const bool isLocal = true; // change to false in production

//   static String get baseUrl {
//     if (isLocal) {
//       // Replace with your computer’s LAN IP
//       return "http://192.168.100.5:8000";
//     } else {
//       return "https://your-domain.com";
//     }
//   }
// }

