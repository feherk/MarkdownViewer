import SwiftUI
import Combine

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
                    Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
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
        }
        .frame(minWidth: 600, idealWidth: 900, minHeight: 400, idealHeight: 700)
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
