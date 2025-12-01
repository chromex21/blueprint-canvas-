# Session Manager Fix - Verification Checklist

Use this checklist to verify that the session manager is working correctly.

## Pre-Flight Checks

- [ ] All files have been modified/created successfully
- [ ] No compilation errors in the IDE
- [ ] Flutter dependencies are up to date (`flutter pub get`)

## Step 1: Run Diagnostic Tool

```bash
dart test/session_diagnostics.dart
```

### Expected Results
- [ ] Platform is detected correctly (not web for desktop)
- [ ] At least ONE of the three methods succeeds with "✓"
- [ ] No "✗" marks indicating complete failure
- [ ] You can see the exact path where sessions will be stored

### Example Good Output
```
1. Testing Application Documents Directory:
   Path: C:\Users\YourName\Documents
   Exists: true
   Session dir path: C:\Users\YourName\Documents\sessions
   ✓ Created session directory
   ✓ Write access confirmed
```

### Example Bad Output (Needs Fixing)
```
1. Testing Application Documents Directory:
   ✗ Failed to get application documents directory: [error]
2. Testing Temporary Directory:
   ✗ Failed to get temporary directory: [error]
3. Testing Current Directory:
   ✗ Failed to use current directory: [error]
```

## Step 2: Run Unit Tests

```bash
flutter test test/session_manager_test.dart
```

### Expected Results
- [ ] All tests pass (5/5 tests)
- [ ] "should initialize directory" passes
- [ ] "should save and load session" passes
- [ ] "should list empty sessions" passes
- [ ] "should handle invalid session name" passes
- [ ] "should handle missing session" passes

### Example Good Output
```
00:00 +0: BlueprintSessionManager should initialize directory
Session directory: C:\Users\...\Documents\sessions
00:01 +1: BlueprintSessionManager should save and load session
✓ Session saved successfully
✓ Session loaded successfully
00:02 +5: All tests passed!
```

## Step 3: Test in Application

### 3A: Launch the App
```bash
flutter run -d windows  # or -d chrome for web, -d macos, etc.
```

- [ ] App launches without errors
- [ ] No compilation errors in console
- [ ] UI loads correctly

### 3B: Create a New Session

1. Navigate to the session manager screen
2. Click "New Session" button
3. Enter session name: "Test Session 1"
4. Click OK/Create

### Check Debug Console
- [ ] See: "Attempting to save session: Test Session 1"
- [ ] See: "✓ Method 1 (application documents): Using [path]"
- [ ] See: "Session directory: [path]"
- [ ] See: "Writing session file: [path]/Test_Session_1.json"
- [ ] See: "Session data size: [number] characters"
- [ ] See: "✓ Session saved: Test Session 1 ([size] bytes)"

### Check UI
- [ ] Success message appears (snackbar/dialog)
- [ ] Session appears in session list
- [ ] Session shows correct name "Test Session 1"
- [ ] Session shows current date/time

### 3C: Verify File Creation

Navigate to the session directory (from diagnostic output):
- Windows: `C:\Users\YourName\Documents\sessions\`
- macOS: `~/Library/Application Support/[app]/sessions/`
- Linux: `~/.local/share/[app]/sessions/`

- [ ] Directory exists
- [ ] File `Test_Session_1.json` exists
- [ ] File contains valid JSON
- [ ] File size > 0 bytes

### Example File Content
```json
{
  "name": "Test Session 1",
  "createdAt": "2025-01-15T10:30:00.000Z",
  "lastModifiedAt": "2025-01-15T10:30:00.000Z",
  "data": {
    "nodes": [],
    "shapes": [],
    "viewport": {...}
  }
}
```

### 3D: Load the Session

1. Close and reopen the app (or restart)
2. Navigate to session manager
3. Select "Test Session 1"
4. Click "Load" button

### Check Debug Console
- [ ] See: "✓ Session loaded: Test Session 1"
- [ ] No errors in console
- [ ] Canvas opens with session data

### Check UI
- [ ] Session loads without errors
- [ ] Canvas displays correctly
- [ ] Session name shown in title/header

### 3E: Save Changes to Session

1. Make some changes in the canvas (add shapes, move things)
2. Click "Save" button

### Check Debug Console
- [ ] See: "Attempting to save session: Test Session 1"
- [ ] See: "✓ Session saved: Test Session 1 ([size] bytes)"
- [ ] New file size is different from original (if you added data)

### 3F: List All Sessions

1. Navigate back to session manager
2. Check session list

- [ ] "Test Session 1" appears in list
- [ ] Last modified time is recent
- [ ] Can select the session

### 3G: Delete Session

1. Select "Test Session 1"
2. Click "Delete" button
3. Confirm deletion

### Check Debug Console
- [ ] See: "✓ Session deleted: Test Session 1"

### Check UI
- [ ] Success message appears
- [ ] Session removed from list
- [ ] No errors shown

### Check File System
- [ ] File `Test_Session_1.json` no longer exists

## Step 4: Error Handling Tests

### 4A: Test Empty Session Name

1. Click "New Session"
2. Leave name field empty
3. Click OK

- [ ] Error message appears
- [ ] Session is NOT created
- [ ] Clear error message (not technical exception)

### 4B: Test Load Non-Existent Session

In debug console or programmatically:
```dart
await sessionManager.loadSession('nonexistent_session');
```

- [ ] Exception is thrown
- [ ] Error message is clear: "Session 'nonexistent_session' not found"

### 4C: Test Delete Non-Existent Session

In debug console or programmatically:
```dart
await sessionManager.deleteSession('nonexistent_session');
```

- [ ] Exception is thrown
- [ ] Error message is clear

## Step 5: Multi-Session Test

1. Create 3 sessions:
   - "Project Alpha"
   - "Project Beta"
   - "Project Gamma"

- [ ] All 3 sessions created successfully
- [ ] All 3 appear in session list
- [ ] All 3 have correct names
- [ ] Sessions are sorted by last modified (newest first)

2. Load "Project Beta"
   - [ ] Loads correctly
   - [ ] Canvas shows correct session

3. Switch to "Project Gamma"
   - [ ] Loads correctly
   - [ ] Canvas updates with new session

4. Delete "Project Alpha"
   - [ ] Deletes successfully
   - [ ] Only 2 sessions remain

## Step 6: Persistence Test

1. Create a session named "Persistence Test"
2. Add some data to the canvas
3. Save the session
4. **Close the app completely**
5. Reopen the app
6. Load "Persistence Test"

- [ ] Session still exists in list
- [ ] Session loads successfully
- [ ] Canvas data is preserved
- [ ] No data loss

## Step 7: Performance Test

Create 10 sessions with varying amounts of data:

1. Create session "Small" with 5 shapes
2. Create session "Medium" with 50 shapes
3. Create session "Large" with 200 shapes

For each session:
- [ ] Save completes in < 1 second
- [ ] Load completes in < 2 seconds
- [ ] No lag or freezing
- [ ] UI remains responsive

## Step 8: Platform-Specific Tests

### Windows
- [ ] Sessions save to Documents folder
- [ ] No permission errors
- [ ] File paths use backslashes correctly

### macOS
- [ ] Sessions save to Application Support
- [ ] No sandboxing issues
- [ ] Paths are valid

### Linux
- [ ] Sessions save to ~/.local/share
- [ ] XDG directories work
- [ ] No permission issues

### Web (if implemented)
- [ ] localStorage is used
- [ ] Sessions persist in browser
- [ ] No file system errors

## Common Issues and Solutions

### Issue: "Failed to create session directory"
**Check:**
- [ ] Run diagnostic tool to see which methods fail
- [ ] Check file system permissions
- [ ] Try running app with elevated permissions
- [ ] Check if antivirus is blocking file creation

### Issue: Sessions don't persist
**Check:**
- [ ] Using temporary directory? (May be cleared by system)
- [ ] Check diagnostic output for directory path
- [ ] Verify files exist in directory
- [ ] Check if app has write permissions

### Issue: Cannot load existing sessions
**Check:**
- [ ] Session file exists in directory
- [ ] File contains valid JSON
- [ ] File is not corrupted
- [ ] File permissions allow reading

### Issue: Performance problems with many sessions
**Check:**
- [ ] How many sessions exist? (>100 may be slow)
- [ ] Session file sizes (>1MB may be slow)
- [ ] Consider implementing pagination

## Final Verification

After completing all steps above:

- [ ] All diagnostic checks passed
- [ ] All unit tests passed
- [ ] Can create sessions in app
- [ ] Can load sessions in app
- [ ] Can save changes to sessions
- [ ] Can delete sessions
- [ ] Sessions persist between app restarts
- [ ] Error handling works correctly
- [ ] Debug logs are clear and helpful
- [ ] No crashes or unexpected behavior

## Sign-Off

Date Tested: _______________

Platform Tested: [ ] Windows [ ] macOS [ ] Linux [ ] Web [ ] Mobile

Result: [ ] PASS - All tests successful
        [ ] FAIL - Issues found (describe below)

Issues Found:
_________________________________________________
_________________________________________________
_________________________________________________

Notes:
_________________________________________________
_________________________________________________
_________________________________________________

Tester Name: _______________

---

## If All Tests Pass

✅ **Session Manager is working correctly!**

The session manager is now ready for production use. Users can:
- Create and name sessions
- Save canvas data to sessions
- Load existing sessions
- Delete unwanted sessions
- Work with multiple sessions
- Trust that data persists between app restarts

## If Tests Fail

❌ **Issues found - follow these steps:**

1. Review the debug console output
2. Run the diagnostic tool again
3. Check the specific error messages
4. Refer to SESSION_MANAGER_FIX_COMPLETE.md for details
5. Check platform-specific requirements
6. Verify all files were modified correctly

For help, review:
- `SESSION_MANAGER_FIX_COMPLETE.md` - Technical details
- `SESSION_MANAGER_QUICK_REFERENCE.md` - API usage
- `SESSION_MANAGER_FIX_VISUAL.md` - Visual explanation
