# Plan: Next Features

Prioritised backlog. Work top to bottom.

---

## Priority Order

| # | Feature | Effort | Value |
|---|---------|--------|-------|
| ~~1~~ | ~~Dynamic dark mode switching~~ | 1 | 3 | v0.6.1 |
| ~~2~~ | ~~Header navigation (`,`/`.` keys)~~ | 2 | 4 | v0.6.1 |
| ~~3~~ | ~~Recent files menu~~ | 2 | 3 | v0.7.0 |
| ~~4~~ | ~~Drag and drop file opening~~ | 1 | 3 | v0.7.0 |
| 5 | Export as PDF | 2 | 3 | |
| 6 | Print support | 2 | 2 | |
| ~~7~~ | ~~Image support~~ | 3 | 4 | v0.7.0 |
| 8 | LaTeX/math rendering | 1 | 2 | |
| 9 | Mermaid diagram rendering | 4 | 2 | |
| 10 | Multiple tabs in single window | 4 | 2 | |

---

## Detail

### 1. Dynamic Dark Mode Switching

**What:** Theme doesn't update when system appearance changes mid-session.

**Implementation:**
- Add `effectiveAppearance` observation on the NSScrollView or coordinator
- On change, rebuild theme via `MarkdownGitHubTheme.theme(dark:)`, re-render content, update background colours

---

### 2. Header Navigation (`,`/`.` keys)

**What:** Jump between headings with single keypresses.

**UX:**
- `,` jump to previous heading (any level)
- `.` jump to next heading
- `<` (Shift+,) previous h1/h2 only
- `>` (Shift+.) next h1/h2 only

**Implementation:**
- Parse heading positions from the attributed string (search for heading font attributes or bold + large size)
- Use `textLayout.rects(for:)` to get y-position of each heading
- Build heading index, track current position via scroll offset
- Add to `KeyboardScrollHandler.swift`, update `HelpOverlay.swift`

---

### 3. Recent Files Menu

**What:** File > Open Recent submenu with recently opened documents.

**Implementation:**
- Store recent file paths in UserDefaults (max 10-15)
- Add submenu to File menu in `MenuBarBuilder.swift`
- On selection, open via `AppDelegate.openDocument()`
- Clear Recent menu item

---

### 4. Drag and Drop File Opening

**What:** Drop a .md file onto the Marka window or dock icon to open it.

**Implementation:**
- Register for file drag types on the main view or window
- Implement `application(_:open:)` for dock icon drops
- Route through existing `openDocument` flow

---

### 5. Export as PDF

**What:** Save the rendered document as a PDF file.

**Implementation:**
- Menu item: File > Export as PDF (Cmd+Shift+E)
- Use NSView's `dataWithPDF(inside:)` or create a print operation targeting PDF
- NSSavePanel for output path

---

### 6. Print Support

**What:** Standard Cmd+P print.

**Implementation:**
- Menu item: File > Print (Cmd+P)
- NSPrintOperation on the MarkdownTextView
- May need pagination handling for long documents

---

### 7. Image Support

**What:** Render images referenced in markdown (relative paths, URLs, TextBundle embedded).

**Implementation:**
- Investigate MarkdownView's image handling (it may already support this)
- Pass baseURL context so relative paths resolve
- TextBundle images are in the assets/ directory alongside text.md
- May need to patch MarkdownView fork for image loading

---

### 8. LaTeX/Math Rendering

**What:** Render LaTeX math expressions in markdown.

**Implementation:**
- SwiftMath is already a dependency via MarkdownView
- Test whether `$inline$` and `$$block$$` math already renders
- If not, check what MarkdownView needs to enable it

---

### 9. Mermaid Diagram Rendering

**What:** Render Mermaid diagrams in fenced code blocks.

**Implementation:**
- Would need mermaid.js or a native rendering library
- Could run headless or use a subprocess to render to SVG/PNG
- Alternative: shell out to `mmdc` (Mermaid CLI) if installed

---

### 10. Multiple Tabs in Single Window

**What:** Open multiple documents as tabs in one window instead of separate windows.

**Implementation:**
- NSTabViewController or NSWindow native tab support
- Significant refactor of window management in AppDelegate
- Would change the windowInfos model

---

## Other Stuff to Consider

Lower priority or more speculative. May promote to the main list later.

| Feature | Effort | Value | Notes |
|---------|--------|-------|-------|
| Wide table breaks scrolling | 2 | 2 | TableView internal NSScrollView exists but horizontal scrolling disabled. 28+ column tables corrupt parent layout. Enable horizontal scroll on TableView. |
| Find in code blocks | 2 | 2 | Search embedded LTXLabel subviews in find bar |
| File associations | 2 | 3 | Register as .md handler, double-click to open |
| Scroll to latest change | 4 | 3 | Diff detection, `e` key to jump. Hard mapping problem. |
| Custom CSS/theme support | 3 | 2 | User config file for colours/fonts |
| Table of Contents sidebar | 3 | 4 | Heading list with click-to-jump |
| Word count / reading time | 1 | 1 | Status bar display |
| URL handler (marka://open) | 2 | 1 | CLI already covers this |
