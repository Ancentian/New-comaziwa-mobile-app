// lib/config.dart

class AppConfig {
  static const bool isLocal = true;

  static String get baseUrl {
    if (isLocal) {
      // return "http://192.168.0.159:8000"; // for physical device
      return "http://192.168.100.19:8000";
    } else {
      return "https://kathande.embucomaziwa.co.ke";
    }
  }

  static String getBaseUrl([bool online = true]) {
    // Optional: use `online` parameter if you want different behavior
    if (!online) {
      return "http://192.168.0.159:8000"; // maybe offline testing URL
    }
    return baseUrl;
  }
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

