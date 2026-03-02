# Markie

A lightweight Markdown viewer for macOS, launched from the terminal.

## Features

- GitHub-Flavoured Markdown rendering (tables, task lists, strikethrough, code blocks)
- Syntax highlighting for code blocks
- Live reload on file changes
- Dark mode support (follows system appearance)
- Stdin support for piping

## Usage

```bash
# View a file (with live reload)
markie README.md

# Pipe from stdin
cat notes.md | markie
echo "# Hello" | markie
```

## Example Content

### Table

| Feature | Status |
|---------|--------|
| GFM tables | Yes |
| Task lists | Yes |
| Code highlighting | Yes |
| Live reload | Yes |
| Dark mode | Yes |

### Task List

- [x] Basic rendering
- [x] Syntax highlighting
- [x] File watching
- [x] Stdin support
- [ ] World domination

### Code Block

```python
def hello(name: str) -> str:
    """Greet someone."""
    return f"Hello, {name}!"

print(hello("world"))
```

### Strikethrough

This is ~~not~~ a great markdown viewer.

## Build

```bash
swift build -c release
# Binary at .build/release/markie
```
