# Session Manager Quick Reference

## Overview

The `BlueprintSessionManager` handles saving and loading Blueprint canvas sessions. Sessions are stored as JSON files on native platforms (Windows, macOS, Linux, Android, iOS).

## Quick Start

```dart
import 'package:dark_canvas_core/services/blueprint_session_manager.dart';

// Create instance
final sessionManager = BlueprintSessionManager();

// Create a new session
await sessionManager.saveSession('My Project', {
  'nodes': [],
  'shapes': [],
  'viewport': {'scale': 1.0, 'translation': {'dx': 0.0, 'dy': 0.0}},
});

// Load a session
final sessionData = await sessionManager.loadSession('My Project');
final canvasData = sessionData['data'] as Map<String, dynamic>;

// List all sessions
final sessions = await sessionManager.listSessions();
for (final session in sessions) {
  print('${session.name} - ${session.lastModified}');
}

// Delete a session
await sessionManager.deleteSession('My Project');
```

## Session Data Structure

### Session File Format
```json
{
  "name": "My Project",
  "createdAt": "2025-01-15T10:30:00.000Z",
  "lastModifiedAt": "2025-01-15T14:45:00.000Z",
  "data": {
    "nodes": [...],
    "shapes": [...],
    "viewport": {...}
  }
}
```

### Canvas Data (Your Custom Format)
```dart
final canvasData = {
  'nodes': [
    {
      'id': 'node_1',
      'position': {'dx': 100.0, 'dy': 200.0},
      'size': {'width': 150.0, 'height': 100.0},
      // ... other node properties
    }
  ],
  'shapes': [
    {
      'id': 'shape_1',
      'type': 'rectangle',
      'position': {'dx': 300.0, 'dy': 400.0},
      // ... other shape properties
    }
  ],
  'viewport': {
    'scale': 1.5,
    'translation': {'dx': -100.0, 'dy': -50.0}
  }
};
```

## Storage Locations

The session manager tries these directories in order:

1. **Application Documents** (Recommended)
   - Windows: `C:\Users\<username>\Documents\sessions\`
   - macOS: `~/Library/Application Support/<app>/sessions/`
   - Linux: `~/.local/share/<app>/sessions/`

2. **Temporary Directory** (Fallback)
   - Windows: `%TEMP%\sessions\`
   - macOS: `/tmp/sessions/`
   - Linux: `/tmp/sessions/`

3. **Current Directory** (Last Resort)
   - `<app_directory>/sessions/`

## Error Handling

All methods throw exceptions on failure. Always wrap in try-catch:

```dart
try {
  await sessionManager.saveSession(sessionName, canvasData);
  print('Session saved successfully');
} catch (e) {
  print('Failed to save session: $e');
  // Show error to user
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Error'),
      content: Text('Failed to save session: $e'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('OK'),
        ),
      ],
    ),
  );
}
```

## Common Operations

### Create New Session
```dart
Future<void> createNewSession(String name) async {
  try {
    // Start with empty data
    await sessionManager.saveSession(name, {
      'nodes': [],
      'shapes': [],
      'viewport': {'scale': 1.0, 'translation': {'dx': 0.0, 'dy': 0.0}},
    });
    print('Created session: $name');
  } catch (e) {
    print('Failed to create session: $e');
    rethrow;
  }
}
```

### Auto-Save Current Session
```dart
Future<void> autoSaveCurrentSession(
  String sessionName,
  Map<String, dynamic> currentCanvasData,
) async {
  try {
    await sessionManager.saveSession(sessionName, currentCanvasData);
    print('Auto-saved: $sessionName');
  } catch (e) {
    print('Auto-save failed: $e');
    // Don't rethrow - auto-save failures shouldn't crash the app
  }
}
```

### Rename Session
```dart
Future<void> renameSession(String oldName, String newName) async {
  try {
    // Load old session
    final oldSession = await sessionManager.loadSession(oldName);
    final canvasData = oldSession['data'] as Map<String, dynamic>;
    
    // Save with new name
    await sessionManager.saveSession(newName, canvasData);
    
    // Delete old session
    await sessionManager.deleteSession(oldName);
    
    print('Renamed: $oldName -> $newName');
  } catch (e) {
    print('Failed to rename session: $e');
    rethrow;
  }
}
```

### Duplicate Session
```dart
Future<void> duplicateSession(String originalName, String copyName) async {
  try {
    // Load original session
    final original = await sessionManager.loadSession(originalName);
    final canvasData = original['data'] as Map<String, dynamic>;
    
    // Save as new session
    await sessionManager.saveSession(copyName, canvasData);
    
    print('Duplicated: $originalName -> $copyName');
  } catch (e) {
    print('Failed to duplicate session: $e');
    rethrow;
  }
}
```

### Export Session (as JSON string)
```dart
Future<String> exportSession(String name) async {
  try {
    final sessionData = await sessionManager.loadSession(name);
    return jsonEncode(sessionData);
  } catch (e) {
    print('Failed to export session: $e');
    rethrow;
  }
}
```

### Import Session (from JSON string)
```dart
Future<void> importSession(String name, String jsonString) async {
  try {
    final sessionData = jsonDecode(jsonString) as Map<String, dynamic>;
    final canvasData = sessionData['data'] as Map<String, dynamic>? ?? sessionData;
    
    await sessionManager.saveSession(name, canvasData);
    print('Imported session: $name');
  } catch (e) {
    print('Failed to import session: $e');
    rethrow;
  }
}
```

## Session Naming

### Valid Characters
- Letters (a-z, A-Z)
- Numbers (0-9)
- Spaces
- Underscores

### Invalid Characters (Auto-Sanitized)
These characters are replaced with underscores:
- `< > : " / \ | ? *`

### Examples
```dart
'My Project'        -> 'My_Project.json'
'Test/Session'      -> 'Test_Session.json'
'Project:2025'      -> 'Project_2025.json'
'   spaces   '      -> 'spaces.json'
```

## Best Practices

### 1. Always Use Try-Catch
```dart
try {
  await sessionManager.saveSession(name, data);
} catch (e) {
  // Handle error
}
```

### 2. Validate Session Names
```dart
bool isValidSessionName(String name) {
  return name.trim().isNotEmpty && name.length <= 255;
}
```

### 3. Show Loading Indicators
```dart
setState(() => _isLoading = true);
try {
  await sessionManager.loadSession(name);
} finally {
  setState(() => _isLoading = false);
}
```

### 4. Implement Auto-Save
```dart
Timer? _autoSaveTimer;

void startAutoSave() {
  _autoSaveTimer = Timer.periodic(
    Duration(minutes: 5),
    (_) => autoSaveCurrentSession(currentSessionName, currentCanvasData),
  );
}

void stopAutoSave() {
  _autoSaveTimer?.cancel();
}
```

### 5. Confirm Destructive Actions
```dart
final confirmed = await showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Delete Session?'),
    content: Text('This action cannot be undone.'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, true),
        child: Text('Delete', style: TextStyle(color: Colors.red)),
      ),
    ],
  ),
);

if (confirmed == true) {
  await sessionManager.deleteSession(name);
}
```

## Debugging

### Enable Debug Logging
The session manager automatically logs to the debug console. Look for:

```
✓ Session saved: My Project (1234 bytes)
✗ Failed to save session: Permission denied
ℹ Web platform: Using localStorage
```

### Check Directory
```dart
final dir = await sessionManager.getSafeSessionDirectory();
print('Sessions stored in: ${dir?.path}');
```

### Manually Inspect Files
Session files are JSON and can be opened in any text editor:
- Windows: `%USERPROFILE%\Documents\sessions\*.json`
- macOS: `~/Library/Application Support/<app>/sessions/*.json`
- Linux: `~/.local/share/<app>/sessions/*.json`

## Troubleshooting

### "Unable to determine session storage directory"
Run the diagnostic script:
```bash
dart test/session_diagnostics.dart
```

### "Session not found"
- Check the session name (case-sensitive)
- Verify the session exists: `await sessionManager.listSessions()`

### "Permission denied"
- Check file permissions on the sessions directory
- Try running the app with elevated permissions
- The session manager will automatically try alternative directories

### Sessions disappear after restart
- You may be using the temporary directory (Method 2)
- The system may be clearing temp files
- Check which directory is being used in the logs

## Platform Notes

### Windows
- Default: `C:\Users\<username>\Documents\sessions\`
- Requires no special permissions

### macOS
- Default: `~/Library/Application Support/<app>/sessions/`
- Sandboxed apps may need entitlements

### Linux
- Default: `~/.local/share/<app>/sessions/`
- Requires no special permissions

### Web
- Uses `localStorage` (browser storage)
- Not yet implemented - marked as TODO
- Sessions don't persist across different devices

### Mobile (Android/iOS)
- Uses app-specific document directory
- Automatically managed by the OS
- Cleared when app is uninstalled

## Performance Tips

1. **Don't Load Unnecessary Data**
   ```dart
   // ✓ Good: Only load when needed
   if (userWantsToOpen) {
     final data = await sessionManager.loadSession(name);
   }
   
   // ✗ Bad: Loading all sessions eagerly
   final allData = await Future.wait(
     sessions.map((s) => sessionManager.loadSession(s.name)),
   );
   ```

2. **Cache Session List**
   ```dart
   List<SessionInfo>? _cachedSessions;
   
   Future<List<SessionInfo>> getSessions({bool forceRefresh = false}) async {
     if (_cachedSessions == null || forceRefresh) {
       _cachedSessions = await sessionManager.listSessions();
     }
     return _cachedSessions!;
   }
   ```

3. **Debounce Auto-Save**
   ```dart
   Timer? _saveDebounce;
   
   void debouncedAutoSave() {
     _saveDebounce?.cancel();
     _saveDebounce = Timer(Duration(seconds: 2), () {
       autoSaveCurrentSession(currentSessionName, currentCanvasData);
     });
   }
   ```

## API Reference

### Methods

#### `saveSession(String name, Map<String, dynamic> data)`
- Saves canvas data to a session file
- Throws: Exception if save fails

#### `loadSession(String name)`
- Returns: `Map<String, dynamic>` with session metadata and data
- Throws: Exception if session not found or corrupted

#### `listSessions()`
- Returns: `List<SessionInfo>` sorted by last modified (newest first)
- Returns: Empty list if no sessions exist

#### `deleteSession(String name)`
- Deletes a session file
- Throws: Exception if session not found or delete fails

#### `getSafeSessionDirectory()`
- Returns: `Directory?` where sessions are stored
- Returns: `null` on web platform
- Throws: Exception if no writable directory found

### Models

#### `SessionInfo`
```dart
class SessionInfo {
  final String name;
  final DateTime lastModified;
}
```

## Example: Complete Integration

```dart
class CanvasScreen extends StatefulWidget {
  final String sessionName;
  
  @override
  _CanvasScreenState createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  final _sessionManager = BlueprintSessionManager();
  Timer? _autoSaveTimer;
  
  @override
  void initState() {
    super.initState();
    _loadSession();
    _startAutoSave();
  }
  
  @override
  void dispose() {
    _stopAutoSave();
    super.dispose();
  }
  
  Future<void> _loadSession() async {
    try {
      final sessionData = await _sessionManager.loadSession(widget.sessionName);
      final canvasData = sessionData['data'] as Map<String, dynamic>;
      // Load canvas data into your canvas widgets
      setState(() {
        // Update UI with loaded data
      });
    } catch (e) {
      // Show error dialog
    }
  }
  
  Future<void> _saveSession() async {
    try {
      final canvasData = {
        'nodes': [...],  // Extract from your canvas
        'shapes': [...],
        'viewport': {...},
      };
      await _sessionManager.saveSession(widget.sessionName, canvasData);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Session saved')),
      );
    } catch (e) {
      // Show error dialog
    }
  }
  
  void _startAutoSave() {
    _autoSaveTimer = Timer.periodic(
      Duration(minutes: 5),
      (_) => _saveSession(),
    );
  }
  
  void _stopAutoSave() {
    _autoSaveTimer?.cancel();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sessionName),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveSession,
          ),
        ],
      ),
      body: YourCanvasWidget(),
    );
  }
}
```
