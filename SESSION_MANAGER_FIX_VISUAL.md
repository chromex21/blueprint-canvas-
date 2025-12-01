# Session Manager Fix - Visual Overview

## Problem Flow (BEFORE)

```
User Creates Session
       ↓
getSafeSessionDirectory()
       ↓
Try Method 1 (Application Documents)
  ✗ FAILS silently
       ↓
Try Method 2 (Temporary Directory)
  ✗ FAILS silently
       ↓
Try Method 3 (Current Directory)
  ✗ FAILS silently
       ↓
Return NULL ❌
       ↓
saveSession() gets NULL
       ↓
❌ Generic Error: "Unable to determine session storage directory"
       ↓
User sees unhelpful error message
❌ NO CLUE what went wrong
```

## Solution Flow (AFTER)

```
User Creates Session
       ↓
getSafeSessionDirectory()
       ↓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
METHOD 1: Application Documents Directory
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1. Get directory path
       ↓
  2. Create directory (if needed)
       ↓
  3. Test write access with .test file
       ↓
  4. Delete .test file
       ↓
  ✓ SUCCESS → Use this directory
       ↓
     SKIP to saveSession()
  
  OR
  
  ✗ FAILS → Log detailed error
       ↓
     Try Method 2
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
METHOD 2: Temporary Directory
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1. Get directory path
       ↓
  2. Create directory (if needed)
       ↓
  3. Test write access with .test file
       ↓
  4. Delete .test file
       ↓
  ✓ SUCCESS → Use this directory
       ↓
     SKIP to saveSession()
  
  OR
  
  ✗ FAILS → Log detailed error
       ↓
     Try Method 3
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
METHOD 3: Current Directory
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1. Get directory path
       ↓
  2. Create directory (if needed)
       ↓
  3. Test write access with .test file
       ↓
  4. Delete .test file
       ↓
  ✓ SUCCESS → Use this directory
       ↓
     SKIP to saveSession()
  
  OR
  
  ✗ FAILS → Log detailed error
       ↓
     ALL METHODS FAILED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

If all 3 methods fail:
  ↓
❌ Throw Exception with details:
   "Failed to create session directory.
    Last error: [specific error from Method 3]"
       ↓
User sees detailed error message
✓ KNOWS exactly what went wrong

If any method succeeds:
  ↓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
saveSession()
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1. Validate session name ≠ empty
       ↓
  2. Sanitize session name for filename
       ↓
  3. Create session file path
       ↓
  4. Prepare session data (with metadata)
       ↓
  5. Write JSON to file
       ↓
  6. Verify file exists
       ↓
  7. Check file size
       ↓
  ✓ SUCCESS → Log success with file size
       ↓
  ✓ Session saved successfully!
```

## Error Logging Comparison

### BEFORE (Minimal Logging)
```
✗ Method 1 (application documents): Failed
✗ Method 2 (temporary directory): Failed
✗ Method 3 (relative path): Failed
✗ All directory methods failed. Last error: <vague error>
```

### AFTER (Detailed Logging)
```
Attempting to save session: My Project
✓ Method 1 (application documents): Using C:\Users\...\Documents\sessions
Session directory: C:\Users\...\Documents\sessions
Writing session file: C:\Users\...\Documents\sessions\My_Project.json
Session data size: 245 characters
✓ Session saved: My Project (245 bytes)
```

## Directory Selection Logic

```
┌─────────────────────────────────────────────┐
│  Platform Check                             │
├─────────────────────────────────────────────┤
│  Is Web?                                    │
│    YES → Use localStorage (return null)     │
│    NO  → Continue to directory selection    │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│  METHOD 1: Application Documents            │
├─────────────────────────────────────────────┤
│  • path_provider.getApplicationDocuments()  │
│  • Most reliable for app data               │
│  • Persists across app restarts             │
│  • Platform-specific location:              │
│    - Windows: C:\Users\...\Documents        │
│    - macOS: ~/Library/Application Support   │
│    - Linux: ~/.local/share                  │
│  • Test: Create/write/delete .test file     │
└─────────────────────────────────────────────┘
         ✓ SUCCESS → DONE
         ✗ FAIL → Try Method 2
                    ↓
┌─────────────────────────────────────────────┐
│  METHOD 2: Temporary Directory              │
├─────────────────────────────────────────────┤
│  • path_provider.getTemporaryDirectory()    │
│  • More permissive access                   │
│  • May be cleaned by system                 │
│  • Platform-specific location:              │
│    - Windows: %TEMP%                        │
│    - macOS: /tmp                            │
│    - Linux: /tmp                            │
│  • Test: Create/write/delete .test file     │
└─────────────────────────────────────────────┘
         ✓ SUCCESS → DONE
         ✗ FAIL → Try Method 3
                    ↓
┌─────────────────────────────────────────────┐
│  METHOD 3: Current Directory                │
├─────────────────────────────────────────────┤
│  • Directory.current + /sessions            │
│  • Last resort for desktop apps             │
│  • Relative to app executable               │
│  • May not work on mobile                   │
│  • Test: Create/write/delete .test file     │
└─────────────────────────────────────────────┘
         ✓ SUCCESS → DONE
         ✗ FAIL → Throw Exception
```

## Session Save Verification

### BEFORE (No Verification)
```
Create session file
     ↓
Write data to file
     ↓
❌ ASSUME success (no checks)
     ↓
Return (file may not exist!)
```

### AFTER (Complete Verification)
```
Validate session name
     ↓
Create session file
     ↓
Prepare JSON data
     ↓
Write data to file
     ↓
✓ CHECK: File exists?
     ↓
✓ CHECK: File size correct?
     ↓
✓ LOG: Success with details
     ↓
Return with confidence
```

## Data Flow

```
User Input
    ↓
┌─────────────────────┐
│  Session Name       │
│  "My Project"       │
└─────────────────────┘
    ↓
┌─────────────────────┐
│  Canvas Data        │
│  {                  │
│    nodes: [...],    │
│    shapes: [...],   │
│    viewport: {...}  │
│  }                  │
└─────────────────────┘
    ↓
┌─────────────────────┐
│  Sanitize Name      │
│  "My_Project"       │
└─────────────────────┘
    ↓
┌─────────────────────┐
│  Add Metadata       │
│  {                  │
│    name: "...",     │
│    createdAt: "...", │
│    lastModified: "...",│
│    data: {...}      │
│  }                  │
└─────────────────────┘
    ↓
┌─────────────────────┐
│  Convert to JSON    │
│  "{...}"            │
└─────────────────────┘
    ↓
┌─────────────────────┐
│  Write to File      │
│  My_Project.json    │
└─────────────────────┘
    ↓
┌─────────────────────┐
│  Verify Write       │
│  ✓ File exists      │
│  ✓ Size: 245 bytes  │
└─────────────────────┘
    ↓
✓ Success!
```

## Testing Strategy

```
┌─────────────────────────────────────────────┐
│  UNIT TESTS                                 │
│  test/session_manager_test.dart             │
├─────────────────────────────────────────────┤
│  ✓ Directory initialization                 │
│  ✓ Session save                             │
│  ✓ Session load                             │
│  ✓ Session list                             │
│  ✓ Session delete                           │
│  ✓ Error handling (empty name)              │
│  ✓ Error handling (missing session)         │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│  DIAGNOSTIC TOOL                            │
│  test/session_diagnostics.dart              │
├─────────────────────────────────────────────┤
│  ✓ Platform detection                       │
│  ✓ Test all 3 directory methods             │
│  ✓ Report permissions                       │
│  ✓ Show exact paths                         │
│  ✓ Identify which method works              │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│  MANUAL TESTING                             │
│  In the app                                 │
├─────────────────────────────────────────────┤
│  ✓ Create new session                       │
│  ✓ Save session data                        │
│  ✓ Load existing session                    │
│  ✓ List all sessions                        │
│  ✓ Delete session                           │
│  ✓ Check debug console logs                 │
└─────────────────────────────────────────────┘
```

## Key Improvements Summary

```
┌────────────────────┬────────────────────┬────────────────────┐
│  ASPECT            │  BEFORE            │  AFTER             │
├────────────────────┼────────────────────┼────────────────────┤
│  Error Handling    │  Silent failures   │  Explicit errors   │
│  Error Messages    │  Generic           │  Detailed          │
│  Directory Test    │  None              │  Write permission  │
│  File Verification │  None              │  Exists + size     │
│  Logging           │  Minimal           │  Comprehensive     │
│  Debugging         │  Difficult         │  Easy with tools   │
│  User Experience   │  Confusing errors  │  Clear messages    │
│  Reliability       │  Unpredictable     │  Robust            │
└────────────────────┴────────────────────┴────────────────────┘
```

## Success Indicators

```
✓ All unit tests pass
✓ Diagnostic tool runs successfully
✓ Sessions can be created in the app
✓ Sessions persist between app restarts
✓ Error messages are clear and actionable
✓ Debug logs show detailed information
✓ Users report successful session creation
```

## If Issues Persist

```
1. Run diagnostic tool
   dart test/session_diagnostics.dart
      ↓
2. Check which directory method fails
      ↓
3. Check debug console for specific errors
      ↓
4. Verify file system permissions
      ↓
5. Try running with elevated permissions
      ↓
6. Check platform-specific restrictions
```
