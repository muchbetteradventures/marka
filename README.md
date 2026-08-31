# Marka

A lightweight Markdown viewer for macOS, launched from the terminal. Includes a QuickLook extension for previewing Markdown files in Finder.

## Features

- GitHub-Flavoured Markdown rendering (tables, task lists, strikethrough, code blocks)
- Syntax highlighting for code blocks
- Live reload on file changes
- Dark mode support (follows system appearance)
- Stdin support for piping
- QuickLook extension for .md, .textbundle, and .textpack files
- Find in page, zoom, narrow layout, copy as rich text
- Keep window on top
- Open in Tabs mode (View menu) — new files open as tabs instead of separate windows
- Smart window focus — opening an already-open file focuses the existing window

## Install

```bash
brew tap muchbetteradventures/tap
brew install marka
```

## Usage

```bash
# View a file (with live reload)
marka README.md

# Pipe from stdin
cat notes.md | marka
echo "# Hello" | marka
```

QuickLook: press Space on any .md file in Finder to preview it.

## Build

Requires macOS 14+ and Swift 6.0.

```bash
swift build -c release
# Binary at .build/release/marka
```

## Architecture

The main app uses a WKWebView with GitHub-flavoured CSS and highlight.js for syntax highlighting. The QuickLook extension uses native rendering via [MarkdownView](https://github.com/Lakr233/MarkdownView) (since WKWebView is not available in QL extensions).

## Acknowledgements

- [MarkdownView](https://github.com/Lakr233/MarkdownView) by Lakr233, native markdown rendering for the QuickLook extension
- [Litext](https://github.com/Lakr233/Litext) by Lakr233, rich text rendering library
- [Highlightr](https://github.com/raspu/Highlightr) by raspu, syntax highlighting via highlight.js
- [swift-cmark](https://github.com/swiftlang/swift-cmark) (cmark-gfm), GFM-compliant markdown parsing
- [apple/swift-markdown](https://github.com/apple/swift-markdown), Swift markdown parsing
- [SwiftMath](https://github.com/mgriebling/SwiftMath) by mgriebling, LaTeX math rendering

## License

MIT © 2026 Gentiane Solutions Ltd (t/a Much Better Adventures). See [LICENSE](LICENSE) for details.
