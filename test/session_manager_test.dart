import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:dark_canvas_core/services/blueprint_session_manager.dart';

void main() {
  group('BlueprintSessionManager', () {
    late BlueprintSessionManager sessionManager;

    setUp(() {
      sessionManager = BlueprintSessionManager();
    });

    test('should initialize directory', () async {
      if (!kIsWeb) {
        final dir = await sessionManager.getSafeSessionDirectory();
        expect(dir, isNotNull);
        print('Session directory: ${dir?.path}');
      }
    });

    test('should save and load session', () async {
      if (kIsWeb) {
        print('Skipping file system test on web');
        return;
      }

      const sessionName = 'test_session';
      final testData = <String, dynamic>{
        'nodes': [],
        'shapes': [],
        'viewport': {'scale': 1.0, 'translation': {'dx': 0.0, 'dy': 0.0}},
      };

      // Save session
      try {
        await sessionManager.saveSession(sessionName, testData);
        print('✓ Session saved successfully');
      } catch (e) {
        print('✗ Failed to save session: $e');
        rethrow;
      }

      // Load session
      try {
        final loadedData = await sessionManager.loadSession(sessionName);
        expect(loadedData, isNotNull);
        expect(loadedData['data'], isNotNull);
        print('✓ Session loaded successfully');
      } catch (e) {
        print('✗ Failed to load session: $e');
        rethrow;
      }

      // List sessions
      try {
        final sessions = await sessionManager.listSessions();
        expect(sessions, isNotEmpty);
        expect(sessions.any((s) => s.name == sessionName), isTrue);
        print('✓ Session listed successfully (${sessions.length} sessions)');
      } catch (e) {
        print('✗ Failed to list sessions: $e');
        rethrow;
      }

      // Delete session
      try {
        await sessionManager.deleteSession(sessionName);
        print('✓ Session deleted successfully');
      } catch (e) {
        print('✗ Failed to delete session: $e');
        rethrow;
      }
    });

    test('should list empty sessions', () async {
      if (kIsWeb) {
        print('Skipping file system test on web');
        return;
      }

      try {
        final sessions = await sessionManager.listSessions();
        print('Found ${sessions.length} existing sessions');
        expect(sessions, isA<List>());
      } catch (e) {
        print('✗ Failed to list sessions: $e');
        rethrow;
      }
    });

    test('should handle invalid session name', () async {
      if (kIsWeb) {
        print('Skipping file system test on web');
        return;
      }

      expect(
        () => sessionManager.saveSession('', {}),
        throwsException,
      );
    });

    test('should handle missing session', () async {
      if (kIsWeb) {
        print('Skipping file system test on web');
        return;
      }

      expect(
        () => sessionManager.loadSession('nonexistent_session'),
        throwsException,
      );
    });
  });
}
