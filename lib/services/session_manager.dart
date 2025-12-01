import 'dart:io';
import 'dart:convert';

// Suppress doc-comment HTML warnings that stem from showing generic types
// such as `Map<String, dynamic>` in comments.
// ignore_for_file: unintended_html_in_doc_comment
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/session.dart';

/// SessionManager: Robust, cross-platform session management for Blueprint Canvas
///
/// Handles creating, saving, and loading project sessions as JSON files.
/// Provides multiple fallback methods for directory resolution across platforms.
class FileSessionManager {
  static const String _sessionsDirectory = 'blueprint_sessions';
  static const String _sessionFileExtension = '.json';

  Directory? _sessionsDir;
  bool _initialized = false;

  /// Get the directory where sessions are stored
  /// Tries multiple fallback methods in order until one succeeds
  Future<Directory> getSessionDirectory() async {
    if (_sessionsDir != null && _initialized) {
      return _sessionsDir!;
    }

    Directory? appDocDir;
    String? lastError;

    // Method 1: Try path_provider application documents directory (preferred)
    // Works on: Windows, macOS, Linux, Android, iOS
    // Skip on: Web (not supported)
    if (!kIsWeb) {
      try {
        appDocDir = await getApplicationDocumentsDirectory();
        debugPrint(
          '✓ Method 1 (path_provider): Using application documents directory: ${appDocDir.path}',
        );
      } catch (e) {
        lastError = e.toString();
        debugPrint('✗ Method 1 (path_provider): Failed - $e');
      }
    } else {
      debugPrint('⚠ Method 1 (path_provider): Skipped on web platform');
    }

    // Method 2: Try environment variables (Windows: USERPROFILE\Documents)
    // Works on: Windows, macOS, Linux (with HOME)
    if (appDocDir == null) {
      try {
        final userProfile = _getEnvironmentVariable('USERPROFILE');
        if (userProfile != null && userProfile.isNotEmpty) {
          // Windows: USERPROFILE\Documents
          final documentsPath = path.join(userProfile, 'Documents');
          final testDir = Directory(documentsPath);
          if (await testDir.exists() || await _canCreateDirectory(testDir)) {
            appDocDir = testDir;
            debugPrint(
              '✓ Method 2 (USERPROFILE): Using Windows Documents directory: ${appDocDir.path}',
            );
          }
        } else {
          // Unix-like: HOME directory
          final home = _getEnvironmentVariable('HOME');
          if (home != null && home.isNotEmpty) {
            final testDir = Directory(home);
            if (await testDir.exists() || await _canCreateDirectory(testDir)) {
              appDocDir = testDir;
              debugPrint(
                '✓ Method 2 (HOME): Using home directory: ${appDocDir.path}',
              );
            }
          }
        }
      } catch (e) {
        lastError = e.toString();
        debugPrint('✗ Method 2 (environment variables): Failed - $e');
      }
    }

    // Method 3: Try constructing from executable path
    // Works on: Windows, macOS, Linux (if executable is in user directory)
    if (appDocDir == null && !kIsWeb) {
      try {
        final execPath = Platform.resolvedExecutable;
        if (execPath.contains(r'\Users\') ||
            execPath.contains('/Users/') ||
            execPath.contains('/home/')) {
          final separator = execPath.contains('\\') ? '\\' : '/';
          String? username;

          // Extract username from path
          if (execPath.contains('${separator}Users$separator')) {
            final usersIndex = execPath.indexOf('${separator}Users$separator');
            final afterUsers = execPath.substring(usersIndex + 7);
            username = afterUsers.split(separator)[0];
          } else if (execPath.contains('${separator}home$separator')) {
            final homeIndex = execPath.indexOf('${separator}home$separator');
            final afterHome = execPath.substring(homeIndex + 6);
            username = afterHome.split(separator)[0];
          }

          if (username != null) {
            // Try Windows path first
            final windowsPath = path.join('C:', 'Users', username, 'Documents');
            final testDir = Directory(windowsPath);
            if (await testDir.exists() || await _canCreateDirectory(testDir)) {
              appDocDir = testDir;
              debugPrint(
                '✓ Method 3 (executable path - Windows): Using: ${appDocDir.path}',
              );
            } else {
              // Try Unix path
              final unixPath = path.join('/home', username);
              final testDir2 = Directory(unixPath);
              if (await testDir2.exists() ||
                  await _canCreateDirectory(testDir2)) {
                appDocDir = testDir2;
                debugPrint(
                  '✓ Method 3 (executable path - Unix): Using: ${appDocDir.path}',
                );
              }
            }
          }
        }
      } catch (e) {
        lastError = e.toString();
        debugPrint('✗ Method 3 (executable path): Failed - $e');
      }
    }

    // Method 4: Try system temporary directory
    // Works on: All platforms (should always be available)
    if (appDocDir == null && !kIsWeb) {
      try {
        appDocDir = await getTemporaryDirectory();
        debugPrint(
          '✓ Method 4 (temp directory): Using temporary directory: ${appDocDir.path}',
        );
      } catch (e) {
        lastError = e.toString();
        debugPrint('✗ Method 4 (temp directory): Failed - $e');
      }
    }

    // Method 5: Relative directory fallback (absolute last resort)
    // Works on: All platforms if file system access is available
    if (appDocDir == null) {
      try {
        appDocDir = Directory(path.absolute('blueprint_sessions_data'));
        // Try to create it to verify we have write access
        await appDocDir.create(recursive: true);
        debugPrint(
          '✓ Method 5 (relative directory): Using relative directory: ${appDocDir.path}',
        );
      } catch (e) {
        lastError = e.toString();
        debugPrint('✗ Method 5 (relative directory): Failed - $e');
      }
    }

    // If all methods failed, throw an error
    if (appDocDir == null) {
      throw Exception(
        'Unable to determine session storage directory. All fallback methods failed.\n'
        'Last error: $lastError\n'
        'Please ensure you have file system access permissions.',
      );
    }

    // Create the sessions subdirectory
    final sessionsPath = path.join(appDocDir.path, _sessionsDirectory);
    _sessionsDir = Directory(sessionsPath);

    // Ensure sessions directory exists
    if (!await _sessionsDir!.exists()) {
      debugPrint('Creating sessions directory: $sessionsPath');
      try {
        await _sessionsDir!.create(recursive: true);
        debugPrint('✓ Sessions directory created successfully');
      } catch (e) {
        debugPrint('✗ Failed to create sessions directory: $e');
        throw Exception(
          'Failed to create sessions directory at $sessionsPath: $e',
        );
      }
    }

    _initialized = true;
    debugPrint(
      'SessionManager initialized. Sessions directory: ${_sessionsDir!.path}',
    );
    return _sessionsDir!;
  }

  /// Safely get environment variable (handles unsupported operations)
  String? _getEnvironmentVariable(String name) {
    try {
      if (kIsWeb) {
        // Web doesn't support environment variables
        return null;
      }
      return Platform.environment[name];
    } catch (e) {
      debugPrint('Error accessing environment variable $name: $e');
      return null;
    }
  }

  /// Check if we can create a directory (even if it doesn't exist)
  Future<bool> _canCreateDirectory(Directory dir) async {
    try {
      await dir.create(recursive: true);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Create a new session with the given name
  /// Returns the session file path
  Future<String> createSession(String name) async {
    try {
      final sessionDir = await getSessionDirectory();

      // Sanitize session name (remove invalid characters)
      final sanitizedName = _sanitizeSessionName(name);
      final sessionFileName = '$sanitizedName$_sessionFileExtension';
      final sessionPath = path.join(sessionDir.path, sessionFileName);
      final sessionFile = File(sessionPath);

      // Check if session already exists
      if (await sessionFile.exists()) {
        throw Exception('Session "$name" already exists');
      }

      // Create empty session data
      final sessionData = <String, dynamic>{
        'name': name,
        'createdAt': DateTime.now().toIso8601String(),
        'lastModifiedAt': DateTime.now().toIso8601String(),
        'data': <String, dynamic>{}, // Canvas state data goes here
      };

      // Write session file
      await sessionFile.writeAsString(
        jsonEncode(sessionData),
        mode: FileMode.writeOnly,
        flush: true,
      );

      debugPrint('✓ Session created: $sessionPath');
      return sessionPath;
    } catch (e) {
      debugPrint('✗ Failed to create session "$name": $e');
      rethrow;
    }
  }

  /// Load session data by name
  /// Returns the session data as a Map of String to dynamic
  Future<Map<String, dynamic>> loadSession(String name) async {
    try {
      final sessionDir = await getSessionDirectory();

      // Sanitize session name
      final sanitizedName = _sanitizeSessionName(name);
      final sessionFileName = '$sanitizedName$_sessionFileExtension';
      final sessionPath = path.join(sessionDir.path, sessionFileName);
      final sessionFile = File(sessionPath);

      // Check if session exists
      if (!await sessionFile.exists()) {
        throw Exception('Session "$name" not found');
      }

      // Read and parse session file
      final content = await sessionFile.readAsString();
      final sessionData = jsonDecode(content) as Map<String, dynamic>;

      debugPrint('✓ Session loaded: $sessionPath');
      return sessionData;
    } catch (e) {
      debugPrint('✗ Failed to load session "$name": $e');
      rethrow;
    }
  }

  /// Save session data by name
  /// Updates the session file with new data
  ///
  /// Parameters:
  /// - name: Session name
  /// - data: Canvas state data (Map with keys like 'shapes', 'viewport', etc.)
  Future<void> saveSession(String name, Map<String, dynamic> data) async {
    try {
      final sessionDir = await getSessionDirectory();

      // Sanitize session name
      final sanitizedName = _sanitizeSessionName(name);
      final sessionFileName = '$sanitizedName$_sessionFileExtension';
      final sessionPath = path.join(sessionDir.path, sessionFileName);
      final sessionFile = File(sessionPath);

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
          final existingData =
              jsonDecode(existingContent) as Map<String, dynamic>;
          sessionData['createdAt'] = existingData['createdAt'];
        } catch (e) {
          debugPrint('Warning: Could not read existing session metadata: $e');
          sessionData['createdAt'] = DateTime.now().toIso8601String();
        }
      } else {
        sessionData['createdAt'] = DateTime.now().toIso8601String();
      }

      // Write session file
      await sessionFile.writeAsString(
        jsonEncode(sessionData),
        mode: FileMode.writeOnly,
        flush: true,
      );

      debugPrint('✓ Session saved: $sessionPath');
    } catch (e) {
      debugPrint('✗ Failed to save session "$name": $e');
      rethrow;
    }
  }

  /// List all existing session names
  /// Returns a list of session names (without extension), sorted by last modified (newest first)
  Future<List<String>> listSessions() async {
    try {
      final sessionDir = await getSessionDirectory();

      if (!await sessionDir.exists()) {
        return [];
      }

      // List all files in sessions directory
      final files = await sessionDir.list().toList();

      // Filter for JSON files and extract session names with metadata
      final sessionsWithDates = <MapEntry<String, DateTime>>[];
      for (final file in files) {
        if (file is File) {
          final fileName = path.basename(file.path);
          if (fileName.endsWith(_sessionFileExtension)) {
            // Remove extension to get session name
            final sessionName = fileName.substring(
              0,
              fileName.length - _sessionFileExtension.length,
            );
            final unsanitizedName = _unsanitizeSessionName(sessionName);

            // Try to load session metadata to get last modified date
            try {
              final sessionData = await loadSession(unsanitizedName);
              final lastModified = DateTime.parse(
                sessionData['lastModifiedAt'] as String,
              );
              sessionsWithDates.add(MapEntry(unsanitizedName, lastModified));
            } catch (e) {
              // If we can't load the session, use file modification time as fallback
              try {
                final stat = await file.stat();
                sessionsWithDates.add(MapEntry(unsanitizedName, stat.modified));
              } catch (e2) {
                // If that also fails, use current time
                sessionsWithDates.add(
                  MapEntry(unsanitizedName, DateTime.now()),
                );
              }
            }
          }
        }
      }

      // Sort by last modified date (newest first)
      sessionsWithDates.sort((a, b) => b.value.compareTo(a.value));

      // Extract just the session names
      final sessionNames = sessionsWithDates.map((e) => e.key).toList();

      debugPrint('✓ Found ${sessionNames.length} sessions');
      return sessionNames;
    } catch (e) {
      debugPrint('✗ Failed to list sessions: $e');
      return [];
    }
  }

  /// Delete a session by name
  Future<void> deleteSession(String name) async {
    try {
      final sessionDir = await getSessionDirectory();

      // Sanitize session name
      final sanitizedName = _sanitizeSessionName(name);
      final sessionFileName = '$sanitizedName$_sessionFileExtension';
      final sessionPath = path.join(sessionDir.path, sessionFileName);
      final sessionFile = File(sessionPath);

      // Check if session exists
      if (!await sessionFile.exists()) {
        throw Exception('Session "$name" not found');
      }

      // Delete session file
      await sessionFile.delete();
      debugPrint('✓ Session deleted: $sessionPath');
    } catch (e) {
      debugPrint('✗ Failed to delete session "$name": $e');
      rethrow;
    }
  }

  /// Rename a session
  Future<void> renameSession(String oldName, String newName) async {
    try {
      final sessionDir = await getSessionDirectory();

      // Sanitize names
      final oldSanitized = _sanitizeSessionName(oldName);
      final newSanitized = _sanitizeSessionName(newName);
      final oldFileName = '$oldSanitized$_sessionFileExtension';
      final newFileName = '$newSanitized$_sessionFileExtension';
      final oldPath = path.join(sessionDir.path, oldFileName);
      final newPath = path.join(sessionDir.path, newFileName);

      // Check if old session exists
      final oldFile = File(oldPath);
      if (!await oldFile.exists()) {
        throw Exception('Session "$oldName" not found');
      }

      // Check if new session already exists
      final newFile = File(newPath);
      if (await newFile.exists()) {
        throw Exception('Session "$newName" already exists');
      }

      // Load old session data
      final sessionData = await loadSession(oldName);

      // Update name in data
      sessionData['name'] = newName;

      // Save with new name
      await saveSession(newName, sessionData['data'] as Map<String, dynamic>);

      // Delete old file
      await oldFile.delete();

      debugPrint('✓ Session renamed: "$oldName" -> "$newName"');
    } catch (e) {
      debugPrint('✗ Failed to rename session "$oldName" to "$newName": $e');
      rethrow;
    }
  }

  /// Sanitize session name for use as filename
  /// Removes invalid characters and replaces with underscores
  String _sanitizeSessionName(String name) {
    // Remove invalid characters for filenames
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
}

/// Compatibility adapter: UI-friendly `SessionManager` expected by screens.
///
/// This adapter wraps the lower-level `FileSessionManager` (file-based
/// persistence) and exposes a `ChangeNotifier`-backed API used by the
/// UI (methods such as `initialize()`, `createSession()` returning a
/// `Session`, `loadSessionData(Session)` returning `CanvasSessionData`,
/// and `sessions` getter). This keeps the file-based implementation
/// unchanged while restoring the higher-level contract used across the
/// codebase.
class SessionManager extends ChangeNotifier {
  final FileSessionManager _impl = FileSessionManager();
  final List<Session> _sessions = [];
  // This flag is set during initialization; keep it for callers that may
  // check initialization state in the future. Suppress analyzer warning.
  // ignore: unused_field
  bool _initialized = false;

  List<Session> get sessions => List.unmodifiable(_sessions);

  /// Initialize underlying storage and load session list
  Future<void> initialize() async {
    await _impl.getSessionDirectory();
    await _reloadSessions();
    _initialized = true;
  }

  /// Create a new session (UI-friendly). Returns a `Session` object.
  Future<Session> createSession() async {
    final name = Session.generateDefaultName();
    final createdAt = DateTime.now();
    // Use underlying impl to create file; it returns the file path
    final filePath = await _impl.createSession(name);

    final session = Session(
      id: Session.generateId(),
      name: name,
      createdAt: createdAt,
      lastModifiedAt: createdAt,
      jsonPath: filePath,
      thumbnailPath: null,
    );

    await _reloadSessions();
    notifyListeners();
    return session;
  }

  /// Load canvas session data for given `Session`.
  Future<CanvasSessionData> loadSessionData(Session session) async {
    final map = await _impl.loadSession(session.name);
    final data = map['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return CanvasSessionData.fromJson(data);
  }

  /// Save canvas session data for given `Session`.
  Future<void> saveSessionData(Session session, CanvasSessionData data) async {
    await _impl.saveSession(session.name, data.toJson());
    await _reloadSessions();
    notifyListeners();
  }

  /// Delete a session (by Session object)
  Future<void> deleteSession(Session session) async {
    await _impl.deleteSession(session.name);
    await _reloadSessions();
    notifyListeners();
  }

  Future<void> _reloadSessions() async {
    _sessions.clear();
    try {
      final names = await _impl.listSessions();
      for (final name in names) {
        try {
          final map = await _impl.loadSession(name);
          final created =
              DateTime.tryParse(map['createdAt'] as String? ?? '') ??
              DateTime.now();
          final modified =
              DateTime.tryParse(map['lastModifiedAt'] as String? ?? '') ??
              created;
          final session = Session(
            id: Session.generateId(),
            name: name,
            createdAt: created,
            lastModifiedAt: modified,
            jsonPath: '',
          );
          _sessions.add(session);
        } catch (_) {
          // ignore single session parse errors
        }
      }
    } catch (_) {
      // ignore list errors for now
    }
  }
}
