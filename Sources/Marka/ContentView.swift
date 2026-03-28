import SwiftUI

struct ContentView: View {
    let document: MarkdownDocument
    @State private var showingInfo = false

    var body: some View {
        // Accessing document.markdown registers this view as a SwiftUI @Observable
        // observer so updateNSView is called when the file changes on disk.
        let _ = document.markdown
        let fields = document.frontmatterFields
        return MarkdownNativeView(document: document)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #if MARKA_DEBUG
            .overlay(alignment: .bottomLeading) {
                Text("v\(markaVersion) #\(markaBuildNumber)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.55))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(10)
                    .allowsHitTesting(false)
            }
            #endif
            .toolbar {
                if !fields.isEmpty {
                    ToolbarItem(placement: .automatic) {
                        Button {
                            showingInfo.toggle()
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .popover(isPresented: $showingInfo) {
                            FrontmatterInfoView(fields: fields)
                        }
                        .help("Show document info")
                    }
                }
            }
    }
}
