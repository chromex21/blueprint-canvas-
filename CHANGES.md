# Changes — Alignment & Snapping (Nov 30, 2025)

Summary of the recent polish work performed on the Blueprint Canvas alignment subsystem.

- Added an alignment overlay painter that draws crisp vertical/horizontal alignment
  lines and measurement labels in screen-space.
- Implemented snapping for:
  - Single-shape moves (edges, centers, midpoints)
  - Media moves
  - Group/selection bounding-box moves (snaps whole selection as a unit)
- Snap sensitivity is specified in screen pixels on the `SimpleCanvas` widget and
  converted into world units using the viewport scale.
- Added `lib/utils/alignment_utils.dart` exposing `computeAlignmentForRect` and
  `AlignmentResult` for deterministic, unit-testable snapping computation.
- Improved label layout in `AlignmentOverlayPainter` — labels are centered on
  anchors by default and multiple candidate placements (above, below, left,
  right, diagonals) are tried to avoid overlaps; falls back to controlled
  downward shifting when necessary.
- Added and expanded unit tests in `test/alignment_utils_test.dart` — tests
  cover no-snap, nearest-snap selection, multiple candidate snaps, sensitivity
  behavior, sign preservation, fractional rounding, and multi-overlap cases.


Notes

- Widget/integration tests were sketched as next work; this cycle added
  deterministic unit tests and the infrastructure to make widget tests easier
  to add next (utility function, clear overlay state, scale-aware conversions).

Files changed (high level)

- `lib/widgets/simple_canvas.dart`  — overlay painter, snapping wiring, label layout
- `lib/utils/alignment_utils.dart`  — new pure snapping utility
- `test/alignment_utils_test.dart`  — new + expanded unit tests
- `blueprint_canvas_complete_vision (1).md` — updated vision doc and TODOs
