import SwiftUI
import Textual

struct ContentView: View {
    let document: MarkdownDocument

    var body: some View {
        ScrollView {
            StructuredText(markdown: document.markdown)
                .textual.structuredTextStyle(.gitHub)
                .textual.textSelection(.enabled)
                .padding(32)
                .frame(maxWidth: 980, alignment: .leading)
        }
        .frame(minWidth: 400, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
    }
}
