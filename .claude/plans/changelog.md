# Marka Changelog

## v0.7.1 (2026-03-10)
- **Table and code block layout fix**: use CTRunDelegate for proper height reservation in text flow, fixing text bleeding through tables
- **Scroll passthrough**: tables and code blocks no longer capture scroll events, page scrolls smoothly over them

## v0.7.0 (2026-03-10)
- **Image rendering**: inline images from local files and relative paths via LTXAttachment
- **File > Open** (Cmd+O) with TextBundle/TextPack support
- **File > Open Recent**: submenu with last 10 opened files, persisted in UserDefaults
- **Drag and drop**: drop .md/.textbundle/.textpack onto dock icon to open
- **CFBundleDocumentTypes** registered for markdown and TextBundle file associations
- App stays alive after last window closes; dock icon click shows open dialog
- Patched MarkdownView fork: image case renders via LTXAttachment with content-width scaling
- PreprocessedContent gains `loadedImages` and `contentWidth` properties
- ImageLoader resolves image paths against document baseURL

## v0.6.1 (2026-03-10)
- **Heading navigation**: `,`/`.` jump between all headings, `<`/`>` jump h1/h2 only
- **Dynamic dark mode switching**: theme updates when system appearance changes mid-session
- **Help overlay fix**: rewritten as NSPanel to work with SwiftUI NSHostingView
- HeadingIndex parses markdown source for ATX headings, finds positions via textLayout

## v0.6.0 (2026-03-10)
- **Unified native rendering**: replaced WKWebView with MarkdownView in the main app
- Both app and QuickLook extension now use the same MarkdownView renderer
- Deleted ~3700 lines of HTML/CSS/JS (no more WKWebView, marked.js, highlight.js)
- Native find-in-page via LTXLabel text search and selection
- Zoom via theme font scaling (replaces CSS zoom)
- Narrow layout via view width constraint (replaces CSS max-width)
- Copy as rich text directly from NSAttributedString (replaces HTML extraction)
- Keyboard navigation via NSEvent local monitor (replaces JS keydown handler)
- Native help overlay (replaces JS/CSS modal)
- Shared GitHub theme extracted to `MarkdownGitHubTheme.swift`
- Patched Litext fork: exposed `textLayout` and `selectionRange` setter as public

## v0.5.0 (2026-03-09)
- **MarkdownView library** for QuickLook extension (replaces custom QLMarkdownRenderer)
- Syntax highlighting in QuickLook via Highlightr
- Proper heading level differentiation (h1-h6) via patched MarkdownView fork
- GitHub-matched theme with correct colours, fonts, spacing, tables
- Forked MarkdownView and Litext to muchbetteradventures org
- Fixed framework signing (libswiftCompatibilitySpan.dylib) for notarization
- Responsive resize via `viewDidLayout()` and `boundingSize(for:)`
- Padding via NSScrollView contentInsets, scrollbar via negative scrollerInsets

## v0.4.0 (2026-03-09)
- Improved native QuickLook renderer
- Better font sizes matching GitHub CSS (h1-h6 scaling)
- Code block background colours and inline code styling
- Blockquote left border bars
- Paragraph spacing and line height adjustments
- Dark/light background colours matching GitHub theme

## v0.3.0 (2026-03-09)
- **Converted to .app bundle** with XcodeGen-based Xcode project
- **QuickLook extension** (MarkdownPreview.appex) embedded in PlugIns/
- Supports .md, .markdown, .textbundle, .textpack in QuickLook
- NSTextView + NSAttributedString rendering for QL (WKWebView incompatible with sandbox)
- Custom Swift regex-based markdown renderer (QLMarkdownRenderer)
- QLTextPackReader: minimal ZIP parser for textpack support in sandbox
- File-open dialog when launched from Finder without arguments
- CLI preserved via symlink to Marka.app/Contents/MacOS/Marka
- Inside-out codesigning for notarization
- Automated build-release.sh with versioning, signing, notarization, GitHub release, Homebrew tap

## v0.2.0 (2026-03-06)
- **Copy as Rich Text** (Cmd+Shift+C): extracts HTML from WKWebView, converts to NSAttributedString
- **Preview Clipboard** (Cmd+Shift+V): reads clipboard, writes temp file, opens new window
- **Narrow Layout** (Cmd+Shift+N): toggleable max-width 980px, persists via UserDefaults
- Automated build-release.sh with GitHub push, `gh release create`, and Homebrew tap update

## v0.1.1
- Fix: code blocks with unsupported languages rendering as invisible text

## v0.1.0
- **Keep on Top** (Cmd+Shift+T): per-window floating toggle
- **Keyboard navigation**: j/k scroll, J/K half-page, g/G top/bottom, u/d half-page, ? help
- **Find in page** (Cmd+F): custom JS find bar with match highlighting and counter

## v0.0.x (initial releases)
- GitHub-Flavoured Markdown rendering via WKWebView + marked.js + highlight.js
- Live reload on file changes via DispatchSource
- Dark mode support (CSS prefers-color-scheme)
- Stdin support for piping
- Terminal detach via posix_spawn
- IPC server for singleton behaviour
