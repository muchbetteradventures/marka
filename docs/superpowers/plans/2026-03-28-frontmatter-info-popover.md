# Frontmatter Info Popover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a toolbar ⓘ button that opens a popover displaying YAML frontmatter fields with smart rendering (date formatting, tag pills).

**Architecture:** Extend `FrontmatterParser` to expose parsed key-value pairs alongside the body; add a `frontmatterFields` computed property to `MarkdownDocument`; create a `FrontmatterInfoView` SwiftUI view for rendering; wire a toolbar button and popover into `ContentView` using SwiftUI's `.toolbar` modifier.

**Tech Stack:** Swift 6, SwiftUI (macOS 14+), `@Observable`, `ISO8601DateFormatter`, XCTest

---

## File Map

| File | Change |
|------|--------|
| `Sources/Marka/FrontmatterParser.swift` | Add `FrontmatterResult` struct and `parse(_:)` method; simplify `body(from:)` to delegate |
| `Sources/Marka/MarkdownDocument.swift` | Add `frontmatterFields` computed property |
| `Sources/Marka/FrontmatterInfoView.swift` | **New** — SwiftUI view rendering key-value fields with smart type detection |
| `Sources/Marka/ContentView.swift` | Add `.toolbar` item with popover |
| `Tests/MarkaTests/FrontmatterParserTests.swift` | **New** — unit tests for `parse()` |

---

### Task 1: Extend FrontmatterParser

**Files:**
- Modify: `Sources/Marka/FrontmatterParser.swift`
- Create: `Tests/MarkaTests/FrontmatterParserTests.swift`

- [ ] **Step 1: Write failing tests**

Create `Tests/MarkaTests/FrontmatterParserTests.swift`:

```swift
import XCTest
@testable import Marka

final class FrontmatterParserTests: XCTestCase {

    func testParseReturnsEmptyFieldsForPlainMarkdown() {
        let result = FrontmatterParser.parse("# Hello\n\nBody text.")
        XCTAssertEqual(result.fields.count, 0)
        XCTAssertEqual(result.body, "# Hello\n\nBody text.")
    }

    func testParseExtractsFields() {
        let md = "---\ntitle: My Note\ndate: 2024-01-15\n---\nBody here."
        let result = FrontmatterParser.parse(md)
        XCTAssertEqual(result.fields.count, 2)
        XCTAssertEqual(result.fields[0].key, "title")
        XCTAssertEqual(result.fields[0].value, "My Note")
        XCTAssertEqual(result.fields[1].key, "date")
        XCTAssertEqual(result.fields[1].value, "2024-01-15")
    }

    func testParsePreservesFieldOrder() {
        let md = "---\nz: last\na: first\nm: middle\n---\n"
        let result = FrontmatterParser.parse(md)
        XCTAssertEqual(result.fields.map(\.key), ["z", "a", "m"])
    }

    func testParseHandlesValueWithColon() {
        let md = "---\ndate: 2013-04-04T15:22:06+00:00\nurl: https://example.com/path\n---\n"
        let result = FrontmatterParser.parse(md)
        XCTAssertEqual(result.fields[0].value, "2013-04-04T15:22:06+00:00")
        XCTAssertEqual(result.fields[1].value, "https://example.com/path")
    }

    func testParseReturnsBothBodyAndFields() {
        let md = "---\ntitle: Hello\n---\n# Heading\n\nParagraph."
        let result = FrontmatterParser.parse(md)
        XCTAssertEqual(result.fields.count, 1)
        XCTAssertTrue(result.body.contains("# Heading"))
    }

    func testParseReturnsNoFieldsWhenFrontmatterUnclosed() {
        let md = "---\ntitle: Hello\nNo closing delimiter"
        let result = FrontmatterParser.parse(md)
        XCTAssertEqual(result.fields.count, 0)
        XCTAssertEqual(result.body, md)
    }

    func testParseAcceptsTripleDotClose() {
        let md = "---\ntitle: Test\n...\nBody."
        let result = FrontmatterParser.parse(md)
        XCTAssertEqual(result.fields.count, 1)
        XCTAssertEqual(result.fields[0].value, "Test")
        XCTAssertTrue(result.body.contains("Body."))
    }

    func testBodyFromDelegatesCorrectly() {
        let md = "---\ntitle: Test\n---\nBody."
        XCTAssertEqual(FrontmatterParser.body(from: md), "Body.")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/andybennett/Work/marka
xcodebuild test -project Marka.xcodeproj -scheme MarkaTests -destination 'platform=macOS' 2>&1 | grep -E "error:|FrontmatterParser|TEST"
```

Expected: compile error — `FrontmatterParser.parse` not found, `FrontmatterResult` not found.

- [ ] **Step 3: Implement FrontmatterResult and parse()**

Replace the full contents of `Sources/Marka/FrontmatterParser.swift`:

```swift
import Foundation

struct FrontmatterResult {
    let body: String
    let fields: [(key: String, value: String)]
}

enum FrontmatterParser {
    /// Parse frontmatter and body from a markdown string.
    /// Returns empty fields and the original string as body when no valid
    /// frontmatter block (opening `---`, closing `---` or `...`) is found.
    static func parse(_ content: String) -> FrontmatterResult {
        let lines = content.components(separatedBy: "\n")
        guard lines.first == "---" || lines.first == "---\r" else {
            return FrontmatterResult(body: content, fields: [])
        }

        var endLine: Int? = nil
        for i in 1..<lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .init(charactersIn: "\r"))
            if trimmed == "---" || trimmed == "..." {
                endLine = i
                break
            }
        }

        guard let end = endLine else {
            return FrontmatterResult(body: content, fields: [])
        }

        var fields: [(key: String, value: String)] = []
        for i in 1..<end {
            let line = lines[i].trimmingCharacters(in: .init(charactersIn: "\r"))
            if let colonIdx = line.firstIndex(of: ":") {
                let key = String(line[..<colonIdx]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                if !key.isEmpty {
                    fields.append((key: key, value: value))
                }
            }
        }

        let body = lines[(end + 1)...].joined(separator: "\n")
        return FrontmatterResult(body: body, fields: fields)
    }

    /// Returns the markdown body with YAML frontmatter stripped.
    /// If no valid frontmatter block is found the original string is returned unchanged.
    static func body(from content: String) -> String {
        parse(content).body
    }
}
```

- [ ] **Step 4: Run tests**

```bash
xcodebuild test -project Marka.xcodeproj -scheme MarkaTests -destination 'platform=macOS' 2>&1 | grep -E "TEST SUCCEEDED|TEST FAILED|error:"
```

Expected: `TEST SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git add Sources/Marka/FrontmatterParser.swift Tests/MarkaTests/FrontmatterParserTests.swift
git commit -m "feat: extend FrontmatterParser with parse() returning structured fields"
```

---

### Task 2: Add frontmatterFields to MarkdownDocument

**Files:**
- Modify: `Sources/Marka/MarkdownDocument.swift`

- [ ] **Step 1: Add computed property**

Replace `Sources/Marka/MarkdownDocument.swift`:

```swift
import Foundation

@MainActor
@Observable
final class MarkdownDocument {
    var markdown: String = ""
    var title: String = "Marka"
    var baseURL: URL?

    var frontmatterFields: [(key: String, value: String)] {
        FrontmatterParser.parse(markdown).fields
    }
}
```

Accessing `self.markdown` inside the computed property registers it as an `@Observable` dependency. SwiftUI views that read `frontmatterFields` will automatically re-render when `markdown` changes.

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project Marka.xcodeproj -scheme Marka -configuration Debug build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add Sources/Marka/MarkdownDocument.swift
git commit -m "feat: add frontmatterFields computed property to MarkdownDocument"
```

---

### Task 3: Create FrontmatterInfoView

**Files:**
- Create: `Sources/Marka/FrontmatterInfoView.swift`

After creating this file, run `xcodegen generate` — the Xcode project uses directory-based source scanning but must be regenerated to pick up new files.

- [ ] **Step 1: Create FrontmatterInfoView.swift**

Create `Sources/Marka/FrontmatterInfoView.swift`:

```swift
import SwiftUI

struct FrontmatterInfoView: View {
    let fields: [(key: String, value: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Document Info")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            ForEach(Array(fields.enumerated()), id: \.offset) { _, field in
                FieldRow(key: field.key, value: field.value)
            }
        }
        .padding(14)
        .frame(minWidth: 260, maxWidth: 320)
    }
}

// MARK: - FieldRow

private struct FieldRow: View {
    let key: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(key.uppercased())
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .tracking(0.3)
            renderedValue
        }
    }

    @ViewBuilder
    private var renderedValue: some View {
        switch classify(value) {
        case .datetime(let date, let hasTime):
            Text(format(date, hasTime: hasTime))
                .font(.system(size: 12))
        case .array(let items):
            tagsView(items)
        case .text(let str):
            Text(str)
                .font(.system(size: 12))
                .lineLimit(3)
        }
    }

    private func tagsView(_ items: [String]) -> some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.system(size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Value classification

private enum FieldValue {
    case datetime(Date, hasTime: Bool)
    case array([String])
    case text(String)
}

private func classify(_ raw: String) -> FieldValue {
    // ISO 8601 with time: 2013-04-04T15:22:06+00:00 or 2013-04-04T15:22:06Z
    let isoFull = ISO8601DateFormatter()
    isoFull.formatOptions = [.withInternetDateTime]
    if let date = isoFull.date(from: raw) {
        return .datetime(date, hasTime: true)
    }

    // Date only: 2024-01-15
    let dateFmt = DateFormatter()
    dateFmt.dateFormat = "yyyy-MM-dd"
    dateFmt.locale = Locale(identifier: "en_US_POSIX")
    if let date = dateFmt.date(from: raw) {
        return .datetime(date, hasTime: false)
    }

    // YAML flow array: ["a", "b"] or ["single"]
    if let items = parseFlowArray(raw) {
        return .array(items)
    }

    return .text(raw)
}

private func parseFlowArray(_ raw: String) -> [String]? {
    let trimmed = raw.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("["), trimmed.hasSuffix("]") else { return nil }
    let inner = String(trimmed.dropFirst().dropLast())
    guard !inner.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
    let items = inner
        .components(separatedBy: ",")
        .map {
            $0.trimmingCharacters(in: .whitespaces)
              .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }
        .filter { !$0.isEmpty }
    return items.isEmpty ? nil : items
}

private func format(_ date: Date, hasTime: Bool) -> String {
    let fmt = DateFormatter()
    if hasTime {
        fmt.dateFormat = "d MMM yyyy, HH:mm z"
        fmt.timeZone = TimeZone(abbreviation: "UTC")
    } else {
        fmt.dateFormat = "d MMM yyyy"
    }
    return fmt.string(from: date)
}
```

- [ ] **Step 2: Regenerate Xcode project**

```bash
cd /Users/andybennett/Work/marka && xcodegen generate 2>&1
```

Expected: `Created project at .../Marka.xcodeproj`

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -project Marka.xcodeproj -scheme Marka -configuration Debug build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add Sources/Marka/FrontmatterInfoView.swift Marka.xcodeproj
git commit -m "feat: add FrontmatterInfoView with smart field rendering"
```

---

### Task 4: Wire toolbar button and popover in ContentView

**Files:**
- Modify: `Sources/Marka/ContentView.swift`

SwiftUI's `.toolbar` modifier on an `NSHostingView`-backed view automatically creates an `NSToolbar` on the containing `NSWindow`. No AppKit toolbar code needed.

- [ ] **Step 1: Update ContentView**

Replace `Sources/Marka/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    let document: MarkdownDocument
    @State private var showingInfo = false

    var body: some View {
        let _ = document.markdown
        MarkdownNativeView(document: document)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                if !document.frontmatterFields.isEmpty {
                    ToolbarItem(placement: .automatic) {
                        Button {
                            showingInfo.toggle()
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .popover(isPresented: $showingInfo) {
                            FrontmatterInfoView(fields: document.frontmatterFields)
                        }
                        .help("Show document info")
                    }
                }
            }
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -project Marka.xcodeproj -scheme Marka -configuration Debug build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Manual test — document with frontmatter**

```bash
APP=$(find ~/Library/Developer/Xcode/DerivedData -name "Marka.app" -path "*/Debug/Marka.app" 2>/dev/null | head -1)
"$APP/Contents/MacOS/Marka" "/Users/andybennett/Public/TextBundles/2013-04-04-15-22-06-gslsupertheatre6-steve.textbundle" &
```

Verify:
- ⓘ button appears in the toolbar (right side of title bar)
- Clicking it opens a popover titled "Document Info"
- `date` field shows "4 Apr 2013, 15:22 UTC" (not the raw ISO 8601 string)
- `tags` field shows a blue pill labelled "GSLSuperTheatre6"
- Clicking outside the popover dismisses it

- [ ] **Step 4: Manual test — document without frontmatter**

```bash
printf "# Hello\n\nNo frontmatter here." > /tmp/test-no-fm.md
APP=$(find ~/Library/Developer/Xcode/DerivedData -name "Marka.app" -path "*/Debug/Marka.app" 2>/dev/null | head -1)
"$APP/Contents/MacOS/Marka" /tmp/test-no-fm.md &
```

Verify: toolbar is absent or ⓘ button is not shown.

- [ ] **Step 5: Commit**

```bash
git add Sources/Marka/ContentView.swift
git commit -m "feat: wire frontmatter info toolbar button and popover in ContentView"
```
