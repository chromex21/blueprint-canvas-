import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/session_info.dart';

// Conditional import for web storage
import 'storage_web.dart' if (dart.library.io) 'storage_stub.dart';

/// BlueprintSessionManager: Robust, cross-platform session management
/// 
/// Handles saving and loading JSON-based sessions for Blueprint Canvas.
/// Supports mobile, desktop, and web platforms without platform-specific errors.
/// 
/// Key features:
/// - Uses path_provider for mobile/desktop (no direct environment variable access)
/// - Falls back to relative path ./sessions if path_provider fails
/// - Uses localStorage on web platform
/// - All operations are async and safe
/// - Comprehensive error handling
class BlueprintSessionManager {
  static const String _sessionsDirectory = 'sessions';
  static const String _sessionFileExtension = '.json';
  static const String _sessionKeyPrefix = 'blueprint_session_';
  
  Directory? _sessionsDir;
  bool _initialized = false;

  /// Get a safe, writable directory for storing session files
  /// 
  /// Tries multiple methods in order:
  /// 1. path_provider application documents directory (primary)
  /// 2. path_provider temporary directory (fallback)
  /// 3. Relative path ./sessions (absolute fallback)
  /// 
  /// On web: Returns null (use localStorage instead)
  /// 
  /// All methods wrapped in try/catch for safe error handling.
  /// Does NOT access environment variables directly.
  Future<Directory?> getSafeSessionDirectory() async {
    if (_sessionsDir != null && _initialized) {
      return _sessionsDir;
    }

    // Web platform: Use localStorage (return null to indicate web)
    if (kIsWeb) {
      debugPrint('ℹ Web platform: Using localStorage for session storage');
      _initialized = true;
      return null;
    }

    Directory? sessionDir;
    String? lastError;

    // Method 1: Try application documents directory (primary method)
    // Works on: Windows, macOS, Linux, Android, iOS
    // Does NOT access environment variables - uses path_provider only
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      sessionDir = Directory(path.join(appDocDir.path, _sessionsDirectory));
      
      // Verify we can create the directory
      if (!await sessionDir.exists()) {
        await sessionDir.create(recursive: true);
      }
      
      // Test write access by creating a test file
      final testFile = File(path.join(sessionDir.path, '.test'));
      try {
        await testFile.writeAsString('test');
        await testFile.delete();
      } catch (writeError) {
        throw Exception('Directory exists but is not writable: $writeError');
      }
      
      debugPrint('✓ Method 1 (application documents): Using ${sessionDir.path}');
      _sessionsDir = sessionDir;
      _initialized = true;
      return _sessionsDir;
    } catch (e) {
      lastError = e.toString();
      debugPrint('✗ Method 1 (application documents): Failed - $e');
      sessionDir = null;
    }

    // Method 2: Try temporary directory (fallback)
    // Works on: All platforms (should always be available)
    try {
      final tempDir = await getTemporaryDirectory();
      sessionDir = Directory(path.join(tempDir.path, _sessionsDirectory));
      
      // Verify we can create the directory
      if (!await sessionDir.exists()) {
        await sessionDir.create(recursive: true);
      }
      
      // Test write access
      final testFile = File(path.join(sessionDir.path, '.test'));
      try {
        await testFile.writeAsString('test');
        await testFile.delete();
      } catch (writeError) {
        throw Exception('Directory exists but is not writable: $writeError');
      }
      
      debugPrint('✓ Method 2 (temporary directory): Using ${sessionDir.path}');
      _sessionsDir = sessionDir;
      _initialized = true;
      return _sessionsDir;
    } catch (e) {
      lastError = e.toString();
      debugPrint('✗ Method 2 (temporary directory): Failed - $e');
      sessionDir = null;
    }

    // Method 3: Relative path fallback (absolute last resort)
    // Works on: Desktop platforms with file system access
    try {
      // Use current directory with sessions subdirectory
      final currentDir = Directory.current;
      sessionDir = Directory(path.join(currentDir.path, _sessionsDirectory));
      
      // Verify we can create the directory
      if (!await sessionDir.exists()) {
        await sessionDir.create(recursive: true);
      }
      
      // Test write access
      final testFile = File(path.join(sessionDir.path, '.test'));
      try {
        await testFile.writeAsString('test');
        await testFile.delete();
      } catch (writeError) {
        throw Exception('Directory exists but is not writable: $writeError');
      }
      
      debugPrint('✓ Method 3 (current directory): Using ${sessionDir.path}');
      _sessionsDir = sessionDir;
      _initialized = true;
      return _sessionsDir;
    } catch (e) {
      lastError = e.toString();
      debugPrint('✗ Method 3 (current directory): Failed - $e');
      sessionDir = null;
    }

    // If all methods failed, throw error with detailed information
    final errorMsg = 'Failed to create session directory. Last error: $lastError';
    debugPrint('✗ $errorMsg');
    throw Exception(errorMsg);
  }

  /// Save session data to JSON file
  /// 
  /// Parameters:
  /// - name: Session name (will be sanitized for filename)
  /// - data: Canvas state data (Map<String, dynamic>)
  /// 
  /// On web: Uses localStorage instead of file system
  /// Handles errors gracefully with informative logs
  Future<void> saveSession(String name, Map<String, dynamic> data) async {
    if (name.isEmpty) {
      throw Exception('Session name cannot be empty');
    }

    try {
      // Web platform: Use localStorage
      if (kIsWeb) {
        await _saveSessionToLocalStorage(name, data);
        return;
      }

      // Mobile/Desktop: Use file system
      debugPrint('Attempting to save session: $name');
      final sessionDir = await getSafeSessionDirectory();
      if (sessionDir == null) {
        throw Exception('Unable to determine session storage directory');
      }
      debugPrint('Session directory: ${sessionDir.path}');

      final sanitizedName = _sanitizeSessionName(name);
      final sessionFileName = '$sanitizedName$_sessionFileExtension';
      final sessionPath = path.join(sessionDir.path, sessionFileName);
      final sessionFile = File(sessionPath); // File is safe on mobile/desktop

      // Prepare session data with metadata
      final sessionData = <String, dynamic>{
        'name': name,
        'lastModifiedAt': DateTime.now().toIso8601String(),
        'data': data, // Canvas state data
      };

      // If file exists, preserve createdAt
      if (await sessionFile.exists()) {
        try {
          final existingContent = await sessionFile.readAsString();
          final existingData = jsonDecode(existingContent) as Map<String, dynamic>;
          sessionData['createdAt'] = existingData['createdAt'] ?? DateTime.now().toIso8601String();
        } catch (e) {
          debugPrint('Warning: Could not read existing session metadata: $e');
          sessionData['createdAt'] = DateTime.now().toIso8601String();
        }
      } else {
        sessionData['createdAt'] = DateTime.now().toIso8601String();
      }

      // Write session file
      final jsonString = jsonEncode(sessionData);
      debugPrint('Writing session file: $sessionPath');
      debugPrint('Session data size: ${jsonString.length} characters');
      
      await sessionFile.writeAsString(
        jsonString,
        mode: FileMode.writeOnly,
        flush: true,
      );

      // Verify the file was written
      if (!await sessionFile.exists()) {
        throw Exception('Session file was not created');
      }

      final writtenSize = await sessionFile.length();
      debugPrint('✓ Session saved: $name ($writtenSize bytes)');
    } catch (e, stackTrace) {
      debugPrint('✗ Failed to save session "$name": $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Failed to save session "$name": $e');
    }
  }

  /// Load session data from JSON file
  /// 
  /// Parameters:
  /// - name: Session name
  /// 
  /// Returns: Session data as Map<String, dynamic>
  /// 
  /// On web: Uses localStorage instead of file system
  /// Handles missing/corrupted sessions gracefully
  Future<Map<String, dynamic>> loadSession(String name) async {
    try {
      // Web platform: Use localStorage
      if (kIsWeb) {
        return await _loadSessionFromLocalStorage(name);
      }

      // Mobile/Desktop: Use file system
      final sessionDir = await getSafeSessionDirectory();
      if (sessionDir == null) {
        throw Exception('Unable to determine session storage directory');
      }

      final sanitizedName = _sanitizeSessionName(name);
      final sessionFileName = '$sanitizedName$_sessionFileExtension';
      final sessionPath = path.join(sessionDir.path, sessionFileName);
      final sessionFile = File(sessionPath); // File is safe on mobile/desktop

      // Check if session exists
      if (!await sessionFile.exists()) {
        throw Exception('Session "$name" not found');
      }

      // Read and parse session file
      final content = await sessionFile.readAsString();
      final sessionData = jsonDecode(content) as Map<String, dynamic>;

      // Validate session data
      if (sessionData.isEmpty) {
        throw Exception('Session "$name" is empty or corrupted');
      }

      debugPrint('✓ Session loaded: $name');
      return sessionData;
    } catch (e, stackTrace) {
      debugPrint('✗ Failed to load session "$name": $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// List all available sessions
  /// 
  /// Returns: List of SessionInfo objects, sorted by last modified (newest first)
  /// 
  /// On web: Uses localStorage instead of file system
  /// Only loads session metadata, not full session data (performance optimization)
  Future<List<SessionInfo>> listSessions() async {
    try {
      // Web platform: Use localStorage
      if (kIsWeb) {
        return await _listSessionsFromLocalStorage();
      }

      // Mobile/Desktop: Use file system
      final sessionDir = await getSafeSessionDirectory();
      if (sessionDir == null || !await sessionDir.exists()) {
        return [];
      }

      // List all files in sessions directory
      final files = await sessionDir.list().toList();

      // Filter for JSON files and extract session info
      final sessions = <SessionInfo>[];
      for (final file in files) {
        if (file is File) {
          final fileName = path.basename(file.path);
          if (fileName.endsWith(_sessionFileExtension)) {
            try {
              // Read session file to get metadata (only metadata, not full data)
              final content = await file.readAsString();
              final sessionData = jsonDecode(content) as Map<String, dynamic>;
              
              final sessionName = sessionData['name'] as String? ?? 
                                  _unsanitizeSessionName(fileName.substring(0, fileName.length - _sessionFileExtension.length));
              final lastModifiedStr = sessionData['lastModifiedAt'] as String?;
              
              if (lastModifiedStr != null) {
                final lastModified = DateTime.parse(lastModifiedStr);
                sessions.add(SessionInfo(
                  name: sessionName,
                  lastModified: lastModified,
                ));
              }
            } catch (e) {
              // Skip corrupted files - handle gracefully
              debugPrint('Warning: Skipping corrupted session file $fileName: $e');
            }
          }
        }
      }

      // Sort by last modified (newest first)
      sessions.sort((a, b) => b.lastModified.compareTo(a.lastModified));

      debugPrint('✓ Found ${sessions.length} sessions');
      return sessions;
    } catch (e, stackTrace) {
      debugPrint('✗ Failed to list sessions: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Delete a session
  /// 
  /// Parameters:
  /// - name: Session name
  /// 
  /// On web: Uses localStorage instead of file system
  Future<void> deleteSession(String name) async {
    try {
      // Web platform: Use localStorage
      if (kIsWeb) {
        await _deleteSessionFromLocalStorage(name);
        return;
      }

      // Mobile/Desktop: Use file system
      final sessionDir = await getSafeSessionDirectory();
      if (sessionDir == null) {
        throw Exception('Unable to determine session storage directory');
      }

      final sanitizedName = _sanitizeSessionName(name);
      final sessionFileName = '$sanitizedName$_sessionFileExtension';
      final sessionPath = path.join(sessionDir.path, sessionFileName);
      final sessionFile = File(sessionPath); // File is safe on mobile/desktop

      // Check if session exists
      if (!await sessionFile.exists()) {
        throw Exception('Session "$name" not found');
      }

      // Delete session file
      await sessionFile.delete();
      debugPrint('✓ Session deleted: $name');
    } catch (e, stackTrace) {
      debugPrint('✗ Failed to delete session "$name": $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Sanitize session name for use as filename
  /// Removes invalid characters and replaces with underscores
  String _sanitizeSessionName(String name) {
    if (name.isEmpty) return 'unnamed_session';
    
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_{2,}'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  /// Unsanitize session name (reverse of sanitize)
  /// Replaces underscores with spaces (approximate)
  String _unsanitizeSessionName(String name) {
    return name.replaceAll('_', ' ');
  }

  // ============================================================================
  // WEB PLATFORM: LOCALSTORAGE IMPLEMENTATION
  // ============================================================================

  /// Save session to localStorage (web only)
  Future<void> _saveSessionToLocalStorage(String name, Map<String, dynamic> data) async {
    if (!kIsWeb) return;

    try {
      final sessionKey = '$_sessionKeyPrefix${_sanitizeSessionName(name)}';
      
      // Prepare session data with metadata
      final sessionData = <String, dynamic>{
        'name': name,
        'lastModifiedAt': DateTime.now().toIso8601String(),
        'data': data,
      };

      // Try to preserve createdAt if session exists
      try {
        final existing = await _loadSessionFromLocalStorage(name);
        sessionData['createdAt'] = existing['createdAt'] ?? DateTime.now().toIso8601String();
      } catch (e) {
        sessionData['createdAt'] = DateTime.now().toIso8601String();
      }

      // Save to localStorage
      final jsonString = jsonEncode(sessionData);
      
      // Use dart:html conditional import via WebStorage
      await _webStorageSave(sessionKey, jsonString);
      
      debugPrint('✓ Web: Session saved to localStorage: $name (${jsonString.length} bytes)');
    } catch (e) {
      debugPrint('✗ Failed to save session to localStorage: $e');
      throw Exception('Failed to save session to localStorage: $e');
    }
  }

  /// Load session from localStorage (web only)
  Future<Map<String, dynamic>> _loadSessionFromLocalStorage(String name) async {
    if (!kIsWeb) {
      throw Exception('localStorage only available on web');
    }

    try {
      final sessionKey = '$_sessionKeyPrefix${_sanitizeSessionName(name)}';
      
      debugPrint('ℹ Web: Loading session from localStorage: $name');
      
      // Load from localStorage
      final jsonString = await _webStorageLoad(sessionKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        throw Exception('Session "$name" not found');
      }
      
      final sessionData = jsonDecode(jsonString) as Map<String, dynamic>;
      
      if (sessionData.isEmpty) {
        throw Exception('Session "$name" is empty or corrupted');
      }
      
      debugPrint('✓ Web: Session loaded from localStorage: $name');
      return sessionData;
    } catch (e) {
      debugPrint('✗ Failed to load session from localStorage: $e');
      throw Exception('Failed to load session from localStorage: $e');
    }
  }

  /// List sessions from localStorage (web only)
  Future<List<SessionInfo>> _listSessionsFromLocalStorage() async {
    if (!kIsWeb) {
      return [];
    }

    try {
      debugPrint('ℹ Web: Listing sessions from localStorage');
      
      // Get all keys with session prefix
      final keys = await _webStorageListKeys(_sessionKeyPrefix);
      
      final sessions = <SessionInfo>[];
      for (final key in keys) {
        try {
          final jsonString = await _webStorageLoad(key);
          if (jsonString == null || jsonString.isEmpty) continue;
          
          final data = jsonDecode(jsonString) as Map<String, dynamic>;
          final name = data['name'] as String?;
          final lastModifiedStr = data['lastModifiedAt'] as String?;
          
          if (name != null && lastModifiedStr != null) {
            sessions.add(SessionInfo(
              name: name,
              lastModified: DateTime.parse(lastModifiedStr),
            ));
          }
        } catch (e) {
          // Skip corrupted entries
          debugPrint('Warning: Skipping corrupted session in localStorage: $e');
        }
      }
      
      // Sort by last modified (newest first)
      sessions.sort((a, b) => b.lastModified.compareTo(a.lastModified));
      
      debugPrint('✓ Web: Found ${sessions.length} sessions in localStorage');
      return sessions;
    } catch (e) {
      debugPrint('✗ Failed to list sessions from localStorage: $e');
      return [];
    }
  }

  /// Delete session from localStorage (web only)
  Future<void> _deleteSessionFromLocalStorage(String name) async {
    if (!kIsWeb) return;

    try {
      final sessionKey = '$_sessionKeyPrefix${_sanitizeSessionName(name)}';
      
      debugPrint('ℹ Web: Deleting session from localStorage: $name');
      
      // Check if session exists
      final exists = await _webStorageLoad(sessionKey);
      if (exists == null) {
        throw Exception('Session "$name" not found');
      }
      
      // Delete from localStorage
      await _webStorageDelete(sessionKey);
      
      debugPrint('✓ Web: Session deleted from localStorage: $name');
    } catch (e) {
      debugPrint('✗ Failed to delete session from localStorage: $e');
      throw Exception('Failed to delete session from localStorage: $e');
    }
  }

  // ============================================================================
  // WEB STORAGE HELPERS (Conditional Import)
  // ============================================================================

  /// Save to web storage (uses conditional import)
  Future<void> _webStorageSave(String key, String value) async {
    if (!kIsWeb) {
      throw Exception('Web storage only available on web platform');
    }
    await WebStorage.save(key, value);
  }

  /// Load from web storage (uses conditional import)
  Future<String?> _webStorageLoad(String key) async {
    if (!kIsWeb) {
      throw Exception('Web storage only available on web platform');
    }
    return await WebStorage.load(key);
  }

  /// Delete from web storage (uses conditional import)
  Future<void> _webStorageDelete(String key) async {
    if (!kIsWeb) {
      throw Exception('Web storage only available on web platform');
    }
    await WebStorage.delete(key);
  }

  /// List keys from web storage (uses conditional import)
  Future<List<String>> _webStorageListKeys(String prefix) async {
    if (!kIsWeb) {
      throw Exception('Web storage only available on web platform');
    }
    return await WebStorage.listKeys(prefix);
  }
}
