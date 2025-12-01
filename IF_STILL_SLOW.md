# 🔍 IF STILL SLOW - DEEP DIAGNOSTICS

If dragging is **still laggy** after the hover fix, here's how to find the real culprit:

---

## 🎯 STEP 1: Verify the Fix Was Applied

Check that the code was actually changed:

**File**: `lib/widgets/interactive_canvas.dart`  
**Line 87-96 should look like**:

```dart
MouseRegion(
  onHover: (event) {
    // PERFORMANCE FIX: Don't trigger setState on every mouse move!
    _currentPointer = event.localPosition;
    
    // Only repaint if actively showing temporary connection line
    if (_connectionStart != null && _connectionSourceId != null) {
      setState(() {}); // Minimal targeted repaint
    }
  },
```

**NOT like this** (old version):
```dart
MouseRegion(
  onHover: (event) {
    setState(() {
      _currentPointer = event.localPosition;
    });
  },
```

---

## 🎯 STEP 2: Add Performance Logging

Add this to see what's really slow:

### In `_InteractiveCanvasState` class:

```dart
void _handleSelectPanUpdate(Offset position, Offset delta) {
  final frameStart = DateTime.now();
  
  if (_draggedNodeId != null) {
    // Drag node(s) with boundary constraints
    final snappedDelta = widget.snapToGrid ? _snapToGrid(delta) : delta;
    
    if (widget.nodeManager.selectedNodeIds.contains(_draggedNodeId)) {
      // Move all selected nodes with constraints
      _moveSelectedNodesConstrained(snappedDelta);
    } else {
      // Move single node with constraints
      _moveSingleNodeConstrained(_draggedNodeId!, snappedDelta);
    }
  } else if (_selectBoxStart != null) {
    // Update selection box
    setState(() {
      _selectBoxEnd = position;
    });
  }
  
  // DIAGNOSTIC: Print frame time
  final frameTime = DateTime.now().difference(frameStart).inMilliseconds;
  if (frameTime > 16) {
    print('🐌 SLOW FRAME: ${frameTime}ms (target: <16ms for 60fps)');
  }
}
```

**Run the app and drag a node. Watch the console.**

### Results Interpretation:

- **0-16ms**: ✅ Perfect, 60fps
- **17-33ms**: ⚠️ Acceptable, 30fps
- **34-50ms**: ❌ Laggy, 20fps
- **50+ms**: 🔴 Very laggy, <20fps

---

## 🎯 STEP 3: Isolate the Bottleneck

Add detailed timing to find the culprit:

```dart
void _handleSelectPanUpdate(Offset position, Offset delta) {
  final t0 = DateTime.now();
  
  if (_draggedNodeId != null) {
    final t1 = DateTime.now();
    final snappedDelta = widget.snapToGrid ? _snapToGrid(delta) : delta;
    final t2 = DateTime.now();
    
    if (widget.nodeManager.selectedNodeIds.contains(_draggedNodeId)) {
      _moveSelectedNodesConstrained(snappedDelta);
    } else {
      _moveSingleNodeConstrained(_draggedNodeId!, snappedDelta);
    }
    final t3 = DateTime.now();
    
    // Print detailed timings
    print('Snap: ${t2.difference(t1).inMicroseconds}µs');
    print('Move: ${t3.difference(t2).inMicroseconds}µs');
    print('Total: ${t3.difference(t0).inMilliseconds}ms');
  }
}
```

**What to look for**:
- If "Move" is slow → Problem in NodeManager
- If "Total" is slow but sub-steps fast → Problem in setState/rebuild
- If consistent 16ms+ → Problem in paint method

---

## 🎯 STEP 4: Check NodeManager

**File**: `lib/managers/node_manager.dart`

Look for `moveNode` or `moveSelectedNodes`:

### Potential Issue: Too Many notifyListeners

```dart
void moveNode(String id, Offset delta) {
  final node = getNode(id);
  if (node != null) {
    _nodes[id] = node.copyWith(
      position: node.position + delta,
    );
    notifyListeners();  // ⚠️ THIS TRIGGERS FULL REBUILD
  }
}
```

**Problem**: If called 60 times per second during drag, causes 60 full rebuilds.

**Fix**: Batch updates or debounce:

```dart
void moveNode(String id, Offset delta, {bool notifyNow = true}) {
  final node = getNode(id);
  if (node != null) {
    _nodes[id] = node.copyWith(
      position: node.position + delta,
    );
    if (notifyNow) {
      notifyListeners();  // Only notify if requested
    }
  }
}
```

---

## 🎯 STEP 5: Test in Release Mode

Debug mode is **5-10x slower** than release mode:

```bash
flutter run --release
```

**If smooth in release but laggy in debug**:
- That's normal! Debug mode has tons of overhead
- Use release mode for performance testing
- Use profile mode for profiling: `flutter run --profile`

---

## 🎯 STEP 6: Check for Rogue AnimatedBuilder

**File**: Your canvas layout file

If you have this:

```dart
AnimatedBuilder(
  animation: Listenable.merge([widget.themeManager, widget.nodeManager]),
  builder: (context, _) {
    // ENTIRE CANVAS REBUILDS on any change
  },
)
```

**Problem**: Every node move triggers full rebuild of everything.

**Fix**: Split into smaller AnimatedBuilders:

```dart
// BAD: One big AnimatedBuilder
AnimatedBuilder(
  animation: Listenable.merge([themeManager, nodeManager]),
  builder: (context, _) {
    return Stack([
      GridLayer(),
      NodesLayer(),
      UILayer(),
    ]);
  },
)

// GOOD: Separate AnimatedBuilders
Stack([
  AnimatedBuilder(
    animation: themeManager,
    builder: (context, _) => GridLayer(),
  ),
  AnimatedBuilder(
    animation: nodeManager,
    builder: (context, _) => NodesLayer(),
  ),
  UILayer(), // No animation needed
])
```

---

## 🎯 STEP 7: Profile with DevTools

If still slow, use Flutter DevTools:

```bash
flutter run --profile
# Open Chrome DevTools (URL printed in console)
# Go to Performance tab
# Record while dragging
# Look for expensive operations
```

**What to look for**:
- Long paint operations (>16ms)
- Many layout operations
- Expensive build operations
- GC (garbage collection) pauses

---

## 🎯 STEP 8: Nuclear Option - Minimal Test

Create a minimal test to isolate the issue:

**File**: `lib/test_minimal_canvas.dart`

```dart
import 'package:flutter/material.dart';

class MinimalCanvasTest extends StatefulWidget {
  @override
  State<MinimalCanvasTest> createState() => _MinimalCanvasTestState();
}

class _MinimalCanvasTestState extends State<MinimalCanvasTest> {
  Offset position = Offset(100, 100);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            position += details.delta;
          });
          print('Frame: ${DateTime.now()}');
        },
        child: CustomPaint(
          painter: _MinimalPainter(position),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _MinimalPainter extends CustomPainter {
  final Offset position;
  _MinimalPainter(this.position);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.blue;
    canvas.drawCircle(position, 50, paint);
  }

  @override
  bool shouldRepaint(_MinimalPainter old) => old.position != position;
}
```

**Run this minimal test**:
- If smooth → Problem is in your main canvas architecture
- If still laggy → Problem is system/hardware/debug mode

---

## 📊 COMMON CULPRITS RANKED

If still slow after the hover fix, here's the likely cause order:

1. **Debug Mode** (95% of cases)
   - Solution: Test in release mode

2. **NodeManager notifyListeners** (3% of cases)
   - Solution: Batch updates, debounce notifications

3. **Too Many AnimatedBuilders** (1% of cases)
   - Solution: Split into smaller, targeted builders

4. **Heavy Paint Operations** (<1% of cases)
   - Solution: Cache expensive drawings

5. **System Issues** (<0.1% of cases)
   - Solution: Check other apps, drivers, etc.

---

## 🚨 REPORT BACK

After testing, please report:

1. ✅ Fix was applied (verified by checking code)
2. ✅ Tested in release mode: `flutter run --release`
3. ✅ Frame time measurements (with logging added)
4. ✅ Minimal test result (smooth or still laggy?)

This will help us pinpoint the exact issue if it's still slow!
