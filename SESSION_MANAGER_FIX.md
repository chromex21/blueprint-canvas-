# Session Manager - MissingPluginException Fix

## Issue
The error `MissingPluginException(No implementation found for method getApplicationDocumentsDirectory on channel plugins.flutter.io/path_provider)` occurs because the `path_provider` plugin requires native platform code that must be registered when the app is built.

## Solution

### Immediate Fix (Fallback)
I've added a fallback that uses the current working directory if `path_provider` is not available. This allows the app to work immediately, but sessions will be stored in the app's current directory instead of the standard documents directory.

### Permanent Fix (Proper Plugin Registration)

**You must do a FULL REBUILD (not just hot reload):**

1. **Stop the app completely** (close the app, stop any running processes)

2. **Clean the build:**
   ```bash
   flutter clean
   ```

3. **Get dependencies:**
   ```bash
   flutter pub get
   ```

4. **Rebuild and run (Windows):**
   ```bash
   flutter run -d windows
   ```
   
   Or if you're using an IDE:
   - Stop the app completely
   - Close and restart your IDE
   - Run the app again (this will trigger a full rebuild)

### Why This Happens
- `path_provider` is a platform plugin that requires native code
- Hot reload/hot restart doesn't register new plugins
- The plugin registration happens during the build process
- After adding a new plugin, you MUST do a full rebuild

### Current Behavior (with Fallback)
- If `path_provider` is not available, sessions are stored in: `{current_directory}/blueprint_sessions/`
- This is a temporary fallback that allows the app to work
- Once you rebuild, it will use the proper documents directory: `{user_documents}/blueprint_sessions/`

### Verification
After rebuilding, check the debug console for:
```
Initializing SessionManager at: C:\Users\{username}\Documents\blueprint_sessions
```

If you see the current directory instead, the plugin still isn't registered - try a complete restart of your IDE and rebuild.

## Platform-Specific Notes

### Windows
- The plugin should work automatically after a full rebuild
- No additional configuration needed
- Sessions will be stored in: `%USERPROFILE%\Documents\blueprint_sessions\`

### Other Platforms
- Same process applies: full rebuild required
- Android/iOS: Plugin registration happens automatically
- Linux: May need to ensure proper permissions
- Web: `path_provider` doesn't work on web - would need different storage (localStorage)

## Testing
1. Create a new session - should work now with fallback
2. Rebuild the app completely
3. Create another session - should now use proper documents directory
4. Check that sessions persist between app restarts

