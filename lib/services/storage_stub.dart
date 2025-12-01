// Storage stub for non-web platforms
// This file is used when running on native platforms (not web)

/// WebStorage: Stub implementation for non-web platforms
/// 
/// This is a placeholder that should never be called on native platforms
class WebStorage {
  /// Save data to localStorage (stub)
  static Future<void> save(String key, String value) async {
    throw UnimplementedError('WebStorage is only available on web platform');
  }

  /// Load data from localStorage (stub)
  static Future<String?> load(String key) async {
    throw UnimplementedError('WebStorage is only available on web platform');
  }

  /// Delete data from localStorage (stub)
  static Future<void> delete(String key) async {
    throw UnimplementedError('WebStorage is only available on web platform');
  }

  /// List all keys with a prefix (stub)
  static Future<List<String>> listKeys(String prefix) async {
    throw UnimplementedError('WebStorage is only available on web platform');
  }

  /// Check if localStorage is available (stub)
  static bool isAvailable() {
    return false;
  }
}
