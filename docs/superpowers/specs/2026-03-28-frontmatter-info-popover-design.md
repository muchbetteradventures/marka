# Frontmatter Info Popover

**Date:** 2026-03-28
**Status:** Approved

## Overview

Add an info button to the marka window toolbar that opens a popover displaying the document's YAML frontmatter rendered in a human-readable format. The button is only visible when the document has frontmatter.

## Toolbar Button

- Uses `NSToolbar` with a single item containing the system SF Symbol `info.circle`
- Placed on the right side of the title bar area
- Visible only when the current document has frontmatter; hidden otherwise
- Toggling the button opens/closes the popover

## Popover

- `NSPopover` anchored to the toolbar button
- Behaviour: `.transient` — dismisses automatically on click-away
- Contains a SwiftUI `FrontmatterInfoView`
- Width: ~280pt; height adjusts to content

## Field Rendering

All frontmatter fields are shown. Rendering is smart based on detected value type:

| Type | Detection | Rendering |
|------|-----------|-----------|
| Datetime | ISO 8601 pattern (e.g. `2013-04-04T15:22:06+00:00`) | Formatted as "4 Apr 2013, 15:22 UTC" |
| Date | `YYYY-MM-DD` pattern | Formatted as "4 Apr 2013" |
| Array | YAML flow (`["a","b"]`) or block (`- a\n- b`) syntax | Tag pills with muted blue background |
| Everything else | — | Plain text; long values truncate with ellipsis |

Keys are displayed as small uppercase muted labels. Fields are shown in the order they appear in the frontmatter.

## Architecture

### 1. `FrontmatterParser` (extend existing)

Currently returns only the body string. Extended to also return an ordered list of key-value pairs:

```swift
struct FrontmatterResult {
    let body: String
    let fields: [(key: String, value: String)]  // ordered, raw string values
}
```

The existing `body(from:)` static method is kept for callers that only need the body. A new `parse(_:)` method returns the full `FrontmatterResult`.

### 2. `FrontmatterInfoView` (new SwiftUI view)

Renders the `[(key, value)]` array. For each field:
- Renders key as a small uppercase label
- Inspects the raw value string and applies smart rendering (date formatting, tag pills)
- Self-contained; no dependency on `MarkdownDocument` directly

### 3. Toolbar wiring (in `AppDelegate` and `MarkdownDocument`)

- `MarkdownDocument` gets a computed property `frontmatterFields: [(key: String, value: String)]` derived from its `markdown` content via `FrontmatterParser.parse()`
- `AppDelegate.openDocument` adds an `NSToolbar` to the window and registers the info button item
- The toolbar item's visibility is bound to whether `frontmatterFields` is non-empty
- The popover is created lazily on first use and reused per window

## Behaviour Edge Cases

- **No frontmatter:** Button is hidden. No popover is created.
- **Frontmatter with no parseable fields:** Button hidden (empty fields list = treated as no frontmatter).
- **Live reload:** When the file changes on disk and `document.markdown` updates, `frontmatterFields` recomputes automatically via `@Observable`. The toolbar button visibility and popover content update accordingly.
- **Multiple windows:** Each window manages its own toolbar and popover independently.

## What Is Not In Scope

- Editing frontmatter fields from the popover
- Filtering or hiding specific fields
- Supporting YAML types beyond strings, arrays, and dates (nested objects, booleans, numbers all render as plain text)
