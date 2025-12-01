import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Session Manager Diagnostics
/// 
/// Run this to diagnose session storage issues
void main() async {
  print('=== Blueprint Session Manager Diagnostics ===\n');

  // Platform check
  print('Platform:');
  if (kIsWeb) {
    print('  Web platform detected');
    print('  Note: Web uses localStorage instead of file system');
    return;
  } else {
    print('  Native platform (desktop/mobile)');
  }

  // Test Method 1: Application Documents Directory
  print('\n1. Testing Application Documents Directory:');
  try {
    final appDocDir = await getApplicationDocumentsDirectory();
    print('   Path: ${appDocDir.path}');
    print('   Exists: ${await appDocDir.exists()}');
    
    final sessionDir = Directory(path.join(appDocDir.path, 'sessions'));
    print('   Session dir path: ${sessionDir.path}');
    
    try {
      if (!await sessionDir.exists()) {
        await sessionDir.create(recursive: true);
        print('   ✓ Created session directory');
      } else {
        print('   ✓ Session directory already exists');
      }
      
      // Test write access
      final testFile = File(path.join(sessionDir.path, '.test'));
      await testFile.writeAsString('test');
      await testFile.delete();
      print('   ✓ Write access confirmed');
    } catch (e) {
      print('   ✗ Failed to create/write to session directory: $e');
    }
  } catch (e) {
    print('   ✗ Failed to get application documents directory: $e');
  }

  // Test Method 2: Temporary Directory
  print('\n2. Testing Temporary Directory:');
  try {
    final tempDir = await getTemporaryDirectory();
    print('   Path: ${tempDir.path}');
    print('   Exists: ${await tempDir.exists()}');
    
    final sessionDir = Directory(path.join(tempDir.path, 'sessions'));
    print('   Session dir path: ${sessionDir.path}');
    
    try {
      if (!await sessionDir.exists()) {
        await sessionDir.create(recursive: true);
        print('   ✓ Created session directory');
      } else {
        print('   ✓ Session directory already exists');
      }
      
      // Test write access
      final testFile = File(path.join(sessionDir.path, '.test'));
      await testFile.writeAsString('test');
      await testFile.delete();
      print('   ✓ Write access confirmed');
    } catch (e) {
      print('   ✗ Failed to create/write to session directory: $e');
    }
  } catch (e) {
    print('   ✗ Failed to get temporary directory: $e');
  }

  // Test Method 3: Current Directory
  print('\n3. Testing Current Directory:');
  try {
    final currentDir = Directory.current;
    print('   Path: ${currentDir.path}');
    print('   Exists: ${await currentDir.exists()}');
    
    final sessionDir = Directory(path.join(currentDir.path, 'sessions'));
    print('   Session dir path: ${sessionDir.path}');
    
    try {
      if (!await sessionDir.exists()) {
        await sessionDir.create(recursive: true);
        print('   ✓ Created session directory');
      } else {
        print('   ✓ Session directory already exists');
      }
      
      // Test write access
      final testFile = File(path.join(sessionDir.path, '.test'));
      await testFile.writeAsString('test');
      await testFile.delete();
      print('   ✓ Write access confirmed');
    } catch (e) {
      print('   ✗ Failed to create/write to session directory: $e');
    }
  } catch (e) {
    print('   ✗ Failed to use current directory: $e');
  }

  // Environment check
  print('\n4. Environment Information:');
  try {
    print('   Current directory: ${Directory.current.path}');
    print('   Platform: ${Platform.operatingSystem}');
    print('   Platform version: ${Platform.operatingSystemVersion}');
  } catch (e) {
    print('   ✗ Failed to get environment info: $e');
  }

  print('\n=== Diagnostics Complete ===');
}
