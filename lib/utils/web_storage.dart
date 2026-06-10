// ignore: deprecated_member_use
// import 'dart:html' as html; // DartPad web localStorage + CSV

// ------------------ simple web key/value store ------------------
class WebStore {
  static void save(String key, Object value) {
    try {
      // html.window.localStorage[key] = jsonEncode(value);
    } catch (_) {}
  }

  static dynamic load(String key) {
    try {
      // final raw = html.window.localStorage[key];
      // return raw == null ? null : jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
}
