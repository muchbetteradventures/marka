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
