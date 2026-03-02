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
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
