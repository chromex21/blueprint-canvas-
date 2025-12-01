// Web storage implementation using localStorage
// This file is only imported on web platforms
import 'dart:html' as html;

/// WebStorage: localStorage wrapper for web platform
/// 
/// Provides localStorage functionality for session storage on web
class WebStorage {
  /// Save data to localStorage
  static Future<void> save(String key, String value) async {
    try {
      html.window.localStorage[key] = value;
    } catch (e) {
      throw Exception('Failed to save to localStorage: $e');
    }
  }

  /// Load data from localStorage
  static Future<String?> load(String key) async {
    try {
      return html.window.localStorage[key];
    } catch (e) {
      throw Exception('Failed to load from localStorage: $e');
    }
  }

  /// Delete data from localStorage
  static Future<void> delete(String key) async {
    try {
      html.window.localStorage.remove(key);
    } catch (e) {
      throw Exception('Failed to delete from localStorage: $e');
    }
  }

  /// List all keys with a prefix
  static Future<List<String>> listKeys(String prefix) async {
    try {
      final keys = <String>[];
      for (var i = 0; i < html.window.localStorage.length; i++) {
        final key = html.window.localStorage.keys.elementAt(i);
        if (key.startsWith(prefix)) {
          keys.add(key);
        }
      }
      return keys;
    } catch (e) {
      throw Exception('Failed to list keys from localStorage: $e');
    }
  }

  /// Check if localStorage is available
  static bool isAvailable() {
    try {
      final testKey = '__storage_test__';
      html.window.localStorage[testKey] = 'test';
      html.window.localStorage.remove(testKey);
      return true;
    } catch (e) {
      return false;
    }
  }
}

