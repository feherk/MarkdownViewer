import SwiftUI
import Combine
import UniformTypeIdentifiers

struct ContentView: View {
    @Binding var document: MarkdownDocument
    @State private var showingEditor = false
    @State private var debouncedText: String = ""
    @State private var debounceTask: Task<Void, Never>?
    @AppStorage("appearanceMode") private var appearanceMode: Int = 0 // 0 = system, 1 = light, 2 = dark

    // Detect if currently in dark mode (either set explicitly or system default)
    private var isDarkMode: Bool {
        if appearanceMode == 1 { return false }
        if appearanceMode == 2 { return true }
        // System mode - detect actual appearance
        return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    var body: some View {
        HSplitView {
            // Editor panel (optional)
            if showingEditor {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Editor")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))

                    TextEditor(text: $document.text)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .background(Color(NSColor.textBackgroundColor))
                }
                .frame(minWidth: 300)
            }

            // Preview panel (always visible)
            ScrollView {
                MarkdownView(text: debouncedText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(NSColor.textBackgroundColor))
        }
        .onAppear {
            debouncedText = document.text
            applyAppearance()
        }
        .onChange(of: document.text) { newValue in
            // Cancel previous debounce task
            debounceTask?.cancel()
            // Start new debounce task - update preview after 150ms of no typing
            debounceTask = Task {
                try? await Task.sleep(nanoseconds: 150_000_000)
                if !Task.isCancelled {
                    await MainActor.run {
                        debouncedText = newValue
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    // Toggle based on current actual appearance
                    appearanceMode = isDarkMode ? 1 : 2
                    applyAppearance()
                } label: {
                    Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                }
                .help(isDarkMode ? "Switch to Light Mode" : "Switch to Dark Mode")
            }
            ToolbarItem {
                Button {
                    withAnimation {
                        showingEditor.toggle()
                        adjustWindowSize(forEditor: showingEditor)
                    }
                } label: {
                    Image(systemName: showingEditor ? "pencil.circle.fill" : "pencil.circle")
                }
                .help(showingEditor ? "Hide Editor" : "Show Editor")
            }
            ToolbarItem {
                Button {
                    exportPDF()
                } label: {
                    Image(systemName: "arrow.down.doc")
                }
                .help("Export as PDF (⌘E)")
            }
        }
        .frame(minWidth: 600, idealWidth: 900, minHeight: 400, idealHeight: 700)
        .focusedSceneValue(\.exportPDF, exportPDF)
    }

    private func applyAppearance() {
        switch appearanceMode {
        case 1:
            NSApp.appearance = NSAppearance(named: .aqua)
        case 2:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            NSApp.appearance = nil // Follow system
        }
    }

    @MainActor
    private func exportPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]

        // Try to derive filename from the window title
        let baseName = NSApp.keyWindow?.title ?? "document"
        let pdfName = baseName.hasSuffix(".md") || baseName.hasSuffix(".markdown")
            ? (baseName as NSString).deletingPathExtension + ".pdf"
            : baseName + ".pdf"
        panel.nameFieldStringValue = pdfName

        guard panel.runModal() == .OK, let url = panel.url else { return }

        // A4 dimensions in points (72 dpi)
        let pageWidth: CGFloat = 595
        let pageHeight: CGFloat = 842
        let margin: CGFloat = 40

        // Build the view for PDF rendering — always light mode, A4 width
        let pdfContent = MarkdownView(text: debouncedText)
            .padding(margin)
            .frame(width: pageWidth)
            .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: pdfContent)
        renderer.scale = 2.0

        renderer.render { size, draw in
            var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
            let usableHeight = pageHeight - margin * 2

            guard let consumer = CGDataConsumer(url: url as CFURL),
                  let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }

            let totalPages = max(1, Int(ceil(size.height / usableHeight)))

            for page in 0..<totalPages {
                let yOffset = CGFloat(page) * usableHeight

                pdfContext.beginPage(mediaBox: &mediaBox)
                pdfContext.saveGState()

                // Clip to page area
                pdfContext.clip(to: CGRect(x: 0, y: margin, width: pageWidth, height: usableHeight))

                // Flip to SwiftUI coordinate system (origin top-left)
                pdfContext.translateBy(x: 0, y: pageHeight)
                pdfContext.scaleBy(x: 1, y: -1)

                // Scroll to the current page slice
                pdfContext.translateBy(x: 0, y: -yOffset)

                draw(pdfContext)

                pdfContext.restoreGState()
                pdfContext.endPage()
            }

            pdfContext.closePDF()
        }
    }

    private func adjustWindowSize(forEditor showEditor: Bool) {
        guard let window = NSApp.keyWindow else { return }
        var frame = window.frame
        let widthChange: CGFloat = 350

        if showEditor {
            frame.size.width += widthChange
            frame.origin.x -= widthChange / 2
        } else {
            frame.size.width -= widthChange
            frame.origin.x += widthChange / 2
        }

        window.setFrame(frame, display: true, animate: true)
    }
}

#Preview {
    ContentView(document: .constant(MarkdownDocument()))
}
