# MarkdownViewer

A lightweight, native macOS Markdown viewer built with SwiftUI.

![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Live Preview** - Instantly rendered Markdown with styled formatting
- **Editor Mode** - Optional split-view editor with live preview
- **Inline Code** - Styled with gray background highlighting
- **Code Blocks** - With one-click copy button
- **Terminal Blocks** - Special styling for ` ```bash ` blocks with green monospace text
- **Native Experience** - Built with SwiftUI for optimal macOS integration
- **Document-Based** - Open, edit, and save `.md` files directly

## Screenshots

| Preview Mode | Editor Mode |
|--------------|-------------|
| Clean reading view | Split-view editing |

## Installation

### From Source

1. Clone the repository:
   ```bash
   git clone https://github.com/feherk/MarkdownViewer.git
   ```

2. Open in Xcode:
   ```bash
   cd MarkdownViewer
   open MarkdownViewer.xcodeproj
   ```

3. Build and run (⌘R)

### Release

Download the latest `.app` from [Releases](https://github.com/feherk/MarkdownViewer/releases).

## Usage

- **Open a file**: File → Open (⌘O) or drag & drop a `.md` file
- **Toggle editor**: Click the pencil icon in the toolbar
- **Copy code**: Click the copy icon on any code block

## Supported Markdown

- Headers (H1-H4)
- **Bold** and *italic* text
- Inline `code`
- Code blocks with syntax hints
- Blockquotes
- Bullet and numbered lists
- Horizontal rules

## Requirements

- macOS 13.0 or later
- Xcode 15+ (for building from source)

## License

MIT License - feel free to use and modify.

## Acknowledgments

Built with the assistance of Claude (Anthropic).
