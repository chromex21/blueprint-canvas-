# Testing Guide — Blueprint Canvas (alignment subsystem)

Run unit tests

```powershell
flutter test test\alignment_utils_test.dart
```

Run all tests

```powershell
flutter test
```

What to test next

- Widget/integration tests for `SimpleCanvas` snapping:
  - Create a minimal `ViewportController` test double and small `ShapeManager`/`MediaManager` fixtures.
  - Pump `SimpleCanvas` into a widget test and simulate `tester.startGesture`/`tester.pumpGesture` to emulate drag events.
  - Assert that positions of shapes/media are adjusted as expected and that overlay lines/labels are painted (or that overlay state is updated).

- Painter-level checks:
  - Use golden tests or layout assertions to verify label avoidance behavior under many overlaps.

Notes

- The pure utility `computeAlignmentForRect` is already unit-tested and is the recommended target for additional deterministic tests before adding expensive widget tests.
