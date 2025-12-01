
# Blueprint Canvas — Complete Vision Document

> **If you are reading this file, your task is to:**
>
> 1. **Check what the app already has**.
> 2. **Check what is new in this document**.
> 3. **Leave roadmap TODO breadcrumbs** wherever needed.
> 4. **Always update this file with the current state of the app after every audit.**

This file is the **single source of truth** for the long‑term vision of **Blueprint Canvas**.
It must always stay stable, readable, and structured.

---

## #️⃣ 1. Core Identity

Blueprint Canvas is a **visual reasoning engine** designed for:

- Solving complex problems
- Planning
- Designing systems
- Red‑string investigations
- Creative mapping
- Story & worldbuilding
- Technical process visualization
- Collaborative thinking

It is built around the principle of:

> **One giant canvas. Everything visible at once. No tabs. No subpages.**

The app revolves around clarity, precision, and modular expansion.

---

## #️⃣ 2. Current Active Core Features (Already Implemented)

These features **already exist in the app** in some functional state.

### ✔ Canvas System

- Infinite surface
- Shapes
- Images
- Basic annotations
- Quick tool bar
- Undo/redo
- Snapping (basic)
  - **Current (Nov 30, 2025):** Basic grid snapping existed; now the canvas includes an
    advanced alignment overlay and snapping improvements implemented during the
    recent polish cycle. Implemented features include:
    - Visual alignment lines (vertical/horizontal) and measurement labels.
    - Single-shape edge/center/midpoint snapping.
    - Group/selection bounding-box snapping (snaps the whole selection as a unit).
    - Zoom-aware snap sensitivity and scale-aware label sizing.
    - Rounded label backgrounds with subtle shadow and a basic collision-avoidance
      strategy to reduce label overlap.

    **Note:** A pure utility `computeAlignmentForRect` was added to centralize
    snapping logic and enable deterministic unit tests. Unit tests were added
    and expanded (see `test/alignment_utils_test.dart`).

    **Developer API:** `computeAlignmentForRect` is a pure function that takes
    a `Rect` representing the moving object, a `List<Rect>` of other objects,
    and a `snapSensitivity` in *world units*. It returns an
    `AlignmentResult` containing `snapDx`/`snapDy` (recommended world-space
    offset), alignment guide coordinates (`verticalLines` / `horizontalLines`),
    and label positions/texts for overlay painting. Callers should convert
    screen-pixel sensitivity to world units by dividing by the viewport
    `scale` before passing it in. See `lib/utils/alignment_utils.dart` and
    tests in `test/alignment_utils_test.dart` and
    `test/group_snapping_more_test.dart` for examples and edge cases.

  - **TODO Breadcrumbs / Completed:**
    - Document the new alignment utility and its public API in code and the user guide. (recommended)
    - Add unit tests for `computeAlignmentForRect` — completed (basic + edge cases).
    - Improve label placement heuristics — completed (multi-candidate placement with fallback shifting).
    - Implement rulers, rotation snapping, equal-spacing indicators and size-matching highlights. (pending)
- Grid toggle

> **TODO Breadcrumb:**
>
> - Document current grid snapping (basic only) in code and user guide.
> - Add missing alignment cues, rulers, and measurement overlays in roadmap.

### ✔ Import/Export (Basic)

- JSON export
- PNG export (placeholder)

### ✔ Session Manager

- Canvas sessions
- Stable (**now stable after recent refactor and cleanup, Nov 30, 2025**)
- Minimalistic controls
- Return to Session Manager with "End Session"

### ✔ Start Staff Tools (Baseline Alignment)

- Basic snapping
- Basic grid alignment

### ✔ AI Tools

- Inside canvas
- Accessible through quick bar

> **TODO Breadcrumb:**
>
> - Add version numbers here for each subsystem once version tracking begins.

---

## #️⃣ 3. Future Vision Overview (Complete Feature Ecosystem)

This section lists **everything Blueprint Canvas WILL become**, including the newly added 7‑Layer Framework.

Each subsection includes **TODO breadcrumbs** to guide dev audits.

---

### 3.1 Precision Grid & Alignment Suite

### 3.1 Precision Grid & Alignment Suite — Goal

Make Blueprint Canvas capable of **professional‑grade precision layout**.

### 3.1 Precision Grid & Alignment Suite — Components

- Rulers on top + left edges
- Hover measurement display
- Shape snapping to:
  - Edges
  - Midpoints
  - Center lines
  - Grid increments
- Smart alignment lines (like Figma/Miro)
- Equal spacing indicators
- Size matching highlights
- Rotation snapping
- Object distance readouts

### 3.1 Precision Grid & Alignment Suite — TODO Breadcrumbs

- Check what grid snapping exists now → document it here. (**Basic snapping only as of Nov 30, 2025**)
- Add missing alignment cues.
- Implement rulers after canvas performance audit.
- Add hover measurement ghost when resizing. (completed — Nov 30, 2025)
  - Implementation: transient resize measurement label appears near active handle; deterministic tests added (`test/resize_measurement_overlay_test.dart`).

---

### 3.3 Stickers & Custom Image Packs


### 3.3 Stickers & Custom Image Packs — Goal


Replace old emoji/arm image panels with a new **Stickers & PNG** system.


### 3.3 Stickers & Custom Image Packs — Components


- Drag‑and‑drop PNGs
- Custom sticker packs
- Library browser (inside gallery)
- Small preview grid
- Option for AI‑generated stickers


### 3.3 Stickers & Custom Image Packs — TODO Breadcrumbs


- Remove outdated arm emoji panel. (**Old emoji/arm panel may still exist; check and remove.**)
- Integrate stickers into import tool only.
- Add caching for heavy PNG sets.


---

### 3.4 7‑Layer Universal Red‑String Framework (Core Identity Upgrade)



> This feature is now considered **one of the foundation pillars** of Blueprint Canvas.


### 🟥 Layer 0 – Canvas Rule

Single surface. Everything visible.


### 🟧 Layer 1 – Core Focus

- Center of canvas
- Large card
- Title + image


### 🟨 Layer 2 – Master Timeline

- Horizontal middle line
- Color‑coded events


### 🟩 Layer 3 – Entities

- Entity cards (title + icon + 3 bullets + status)


### 🟦 Layer 4 – Evidence

- Screenshots
- Data cards
- Raw documents


### 🟪 Layer 5 – Contexts

- Zones / faded background areas


### 🟥 Layer 6 – Relationship Threads

- Influence arrows
- Neutral lines
- Motive threads


### 🟫 Layer 7 – Hypotheses & Next Actions

Right‑column vertical lane.


### 3.4 7‑Layer Framework — TODO Breadcrumbs

- Create template loader in gallery.
- Add special card types.
- Add thread color presets.
- Add layer‑toggle panel.


---

### 3.5 Grouping + Node Resizing (Phase 5–6)


### 3.5 Grouping & Node Resizing — Goal

Allow users to cluster, reorder, and control large structures.


### 3.5 Grouping & Node Resizing — Components

- Group boxes
- Auto‑resize groups
- Collapse/expand
- Group labels
- Nested grouping


### 3.5 Grouping & Node Resizing — TODO Breadcrumbs

- Confirm if group container logic exists (partial?). (**No group container logic found as of Nov 30, 2025.**)
- Build grouping version 1.
- Add resizing handles.


---

### 3.6 Gallery (Hub + Repository)


The **Gallery** becomes the central home for all sessions.
Not for stickers. Not for images.  
Only:

- Saved sessions
- Exported/imported sessions (BP file)
- Templates (like 7‑Layer board)


### 3.6 Gallery — Components

- Grid view
- Open, duplicate, delete session
- Import session (.json + .bp)
- Export session
- Preview thumbnails


### 3.6 Gallery — TODO Breadcrumbs

- Remove stickers/images import option here.
- Confirm full preview pipeline.
- Validate export workflow.


---

### 3.7 Presentation Mode


### 3.7 Presentation Mode — Goal

Allow users to present a finished blueprint **cleanly and professionally**.


### 3.7 Presentation Mode — Components

- Entered **from the gallery**, NOT the canvas
- No quick tools bar
- No minimap
- No distractions
- Simple forward/back controls
- Optional auto‑focus mode


### 3.7 Presentation Mode — TODO Breadcrumbs

- Build separate UI layout.
- Add slideshow-like navigation.
- Add deep zoom gesture.


---

### 3.8 Blueprint Canvas File Type (.BP)


### 3.8 File Type (.BP) — Goal

Give Blueprint Canvas its own professional save format.


### 3.8 File Type (.BP) — Components

- Custom extension: **.bp**
- Custom file icon
- Double‑click to open Blueprint Canvas
- Encryption optional (future)
- JSON + metadata wrapper inside


### 3.8 File Type (.BP) — TODO Breadcrumbs

- Define internal BP schema.
- Register file association on desktop platforms.
- Add icon assets.


---


## #️⃣ 4. App Philosophy & Development Rules


These rules stay permanent.


### 1. **One canvas → one mind.**

### 2. Minimal UI, maximum clarity.

### 3. Everything modular.

### 4. No feature bloat.

### 5. Every feature must help users "see further."



> **TODO Breadcrumb:**
>
> - Make this section visible in the Developer About Panel.


---

### **Phase 2 — Polish (NOW)**

- [x] Improve grid alignment system — partial
  - **Progress (Nov 30, 2025):** Advanced alignment overlay and snapping were implemented
    (visual cues, selection snapping, scale-aware thresholds, and basic label collision-avoidance).
  - **Remaining:** refine label placement heuristics; add integration/widget tests; implement rulers and rotation snapping.
  - **Recent small fixes (Nov 30, 2025):**
    - Rulers now ignore pointer events to avoid blocking canvas interactions (implemented as a repaint-isolated `IgnorePointer` wrapper).
    - Shape selection panel: added an `auto-collapse` behavior while placing shapes to prevent the panel from covering the canvas (toggleable via settings).
    - Shape selection panel: converted to a docked square panel (256×256) with a small collapsed handle and a uniform grid of shape tiles. Icon sizing and tile constraints were standardized for consistent hit targets and layout.
      - **Note:** Sliding animation (panel sliding in/out from the left using `AnimatedPositioned`) is still pending and should be added in the parent layout. Make the open size configurable as a follow-up.
  - **Completed (Nov 30, 2025):** Measurement units toggle (px vs world) added, persisted via `ThemeManager.saveSettings()` and restored at startup via `ThemeManager.loadSettings()`. Transient resize measurement overlay and a deterministic widget test (`test/resize_measurement_overlay_test.dart`) were also added to validate resizing labels and formatting.

  - [ ] Add precision rulers
  - [ ] Fix snapping inconsistencies
  - [ ] Audit ruler label performance (cached text painters added)
  - [ ] Add left/slide-in positioning for docked shape panel (`AnimatedPositioned` in parent layout)
  - [ ] Expose docked panel size as a user-configurable setting (ThemeManager or constructor param)


### **Phase 3 — Save / Load System**

- [ ] Proper JSON export
- [ ] .BP file integration
- [ ] Robust import


### **Phase 4 — Session / Canvas Management**

- [ ] Full gallery implementation
- [ ] Template selection screen


### **Phase 5 / 6 — Grouping + Node Resize**

- [ ] Group containers
- [ ] Collapse/expand
- [ ] Resizable blocks


### **Phase 7 — 7-Layer Framework & Presentation Mode**

- [ ] Red‑string layer system
- [ ] Evidence layer support
- [ ] Timeline engine
- [ ] Presentation mode UI


---

## #️⃣ 6. Final Rule



> **Every time you complete an audit or implement a feature, YOU MUST update this document.**



**Last audit and update:** November 30, 2025 — All core features listed as implemented are present and stable. All TODO breadcrumbs reflect the current state and next steps. This file is the permanent memory of Blueprint Canvas.


It records:

- Architecture direction
- Missing pieces
- Finished modules
- Vision alignment


If this file stays healthy, the app will always stay consistent.


